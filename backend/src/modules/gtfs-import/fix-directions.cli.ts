#!/usr/bin/env node
import { resolve } from "path";
import {
    CsvRow,
    DirectionStop,
    detectOrientation,
    orientationMetrics,
    reverseShapeRows,
    reverseStopTimesRows,
    toDirectionStops,
} from "./gtfs-direction-fixer";
import { readFile } from "fs/promises";
import {
    LatLon,
    OneWayIndex,
    OneWaySegment,
    buildOneWayIndex,
    decideShapeSwap,
    shapeFollowsStopOrder,
} from "./gtfs-shape-side";
import { backupFile, parseCsv, readZipEntries, toCsv, writeZipEntries } from "./gtfs-zip.writer";

/**
 * CLI de reparación de direcciones: npm run fix:gtfs-directions
 *
 * Hace DOS reparaciones sobre el zip, en este orden:
 *
 * 1. **Vuelta duplicada**: detecta rutas cuya vuelta (`direction_id=1`) está
 *    copiada en el mismo orden que la ida y le invierte los `stop_times`.
 * 2. **Lado de calzada (contraflecha)**: comprueba que cada viaje tenga el
 *    `shape` de SU calzada. Varias rutas traen los shapes intercambiados entre
 *    ida y vuelta, así que el micro se dibuja circulando por el carril del
 *    sentido opuesto. Cuando la otra calzada queda a la DERECHA en los dos
 *    sentidos (circulación por la derecha) se intercambian los `shape_id` entre
 *    los dos viajes y se orienta cada shape al orden de paradas de su viaje.
 *
 * Invertir el orden de puntos de un shape (lo que hacía antes este CLI para la
 * vuelta) NO cambia de calzada: el trazado sigue sobre el carril equivocado.
 * Por eso el paso 2 asigna shapes en vez de limitarse a invertirlos.
 *
 * Sin `--apply` solo informa (dry-run). No toca la base de datos: después hay
 * que re-importar (`npm run import:gtfs`) y, si se usa OTP, reconstruir su
 * grafo.
 */

interface TripMeta {
    tripId: string;
    routeId: string;
    directionId: number;
    shapeId: string | null;
}

interface RouteReport {
    routeId: string;
    idaTrip: string;
    vueltaTrip: string;
    estado: string;
    mismoOrdenM: number;
    espejoM: number;
}

/** Fila del informe de lado de calzada. */
interface ShapeSideReport {
    routeId: string;
    estado: string;
    /** % a favor del sentido de la calle con la asignación actual. */
    idaActualPct: number;
    vueltaActualPct: number;
    /** % a favor si se intercambian los shapes. */
    idaSwapPct: number;
    vueltaSwapPct: number;
}

interface Args {
    in: string;
    out: string;
    apply: boolean;
    /** Si se indica, solo se reparan estas rutas (el diagnóstico sigue siendo global). */
    only: string[] | null;
    /** GeoJSON de `osmium export` con las calles del área urbana (para el paso 2). */
    osm: string | null;
}

function parseArgs(argv: string[]): Args {
    const args: Args = { in: "gtfs.zip", out: "", apply: false, only: null, osm: null };
    for (let i = 0; i < argv.length; i++) {
        const token = argv[i];
        if (token === "--apply") args.apply = true;
        else if (token === "--dry-run") args.apply = false;
        else if (token === "--in" && argv[i + 1]) args.in = argv[++i];
        else if (token === "--out" && argv[i + 1]) args.out = argv[++i];
        else if (token === "--osm" && argv[i + 1]) args.osm = resolve(argv[++i]);
        else if (token === "--routes" && argv[i + 1])
            args.only = argv[++i]
                .split(",")
                .map(s => s.trim())
                .filter(s => s !== "");
        else throw new Error(`Argumento no reconocido: ${token}`);
    }
    args.in = resolve(args.in);
    args.out = args.out ? resolve(args.out) : args.in;
    return args;
}

/** GeoJSON mínimo de `osmium export` (solo lo que usa el detector). */
interface OsmFeature {
    geometry: { type: string; coordinates: unknown } | null;
    properties: Record<string, unknown> | null;
}

/**
 * Extrae de un GeoJSON de OSM los tramos de calle de un solo sentido, ya
 * orientados en su sentido permitido (`oneway=-1` se invierte aquí).
 *
 * Se genera una sola vez con:
 *   osmium extract -b <oeste>,<sur>,<este>,<norte> bolivia-latest.osm.pbf -o city.pbf
 *   osmium export -f geojson city.pbf -o city.geojson
 */
async function loadOneWayIndex(path: string): Promise<OneWayIndex> {
    const raw = await readFile(path, "utf8");
    const parsed = JSON.parse(raw) as { features?: OsmFeature[] };
    const features = parsed.features ?? [];
    const segments: OneWaySegment[] = [];

    const pushLine = (coords: number[][], oneway: string): void => {
        for (let i = 1; i < coords.length; i++) {
            const [lonA, latA] = coords[i - 1];
            const [lonB, latB] = coords[i];
            if (!Number.isFinite(latA) || !Number.isFinite(latB)) continue;
            if (latA === latB && lonA === lonB) continue;
            const a = oneway === "-1" ? { lat: latB, lon: lonB } : { lat: latA, lon: lonA };
            const b = oneway === "-1" ? { lat: latA, lon: lonA } : { lat: latB, lon: lonB };
            segments.push({ a, b });
        }
    };

    for (const feature of features) {
        const props = feature.properties;
        const geometry = feature.geometry;
        if (!props || !geometry) continue;
        if (typeof props["highway"] !== "string") continue;
        let oneway = typeof props["oneway"] === "string" ? props["oneway"] : "no";
        if (props["junction"] === "roundabout") oneway = "yes";
        if (oneway !== "yes" && oneway !== "-1") continue;

        if (geometry.type === "LineString") {
            pushLine(geometry.coordinates as number[][], oneway);
        } else if (geometry.type === "MultiLineString") {
            for (const line of geometry.coordinates as number[][][]) pushLine(line, oneway);
        }
    }

    return buildOneWayIndex(segments);
}

const STATUS_LABEL: Record<string, string> = {
    ok: "correcta",
    reversed: "INVERTIDA",
    ambiguous: "ambigua (se omite)",
    incomplete: "sin datos",
};

const SHAPE_STATUS_LABEL: Record<string, string> = {
    keep: "calzada correcta",
    swapped: "SHAPES INTERCAMBIADOS",
    inconclusive: "no concluyente",
};

async function main(): Promise<void> {
    const args = parseArgs(process.argv.slice(2));
    const entries = await readZipEntries(args.in);
    const need = (name: string): Buffer => {
        const data = entries.get(name);
        if (!data) throw new Error(`${name} no está en ${args.in}`);
        return data;
    };

    const trips = parseCsv(need("trips.txt"));
    const stops = parseCsv(need("stops.txt"));
    const stopTimes = parseCsv(need("stop_times.txt"));
    const shapes = parseCsv(need("shapes.txt"));

    const coords = new Map<string, { lat: number; lon: number }>();
    for (const row of stops.rows) {
        coords.set(row["stop_id"], {
            lat: Number.parseFloat(row["stop_lat"]),
            lon: Number.parseFloat(row["stop_lon"]),
        });
    }

    // Filas de stop_times agrupadas por viaje, ordenadas por stop_sequence.
    const rowsByTrip = new Map<string, CsvRow[]>();
    for (const row of stopTimes.rows) {
        const list = rowsByTrip.get(row["trip_id"]);
        if (list) list.push(row);
        else rowsByTrip.set(row["trip_id"], [row]);
    }
    for (const list of rowsByTrip.values()) {
        list.sort((a, b) => Number(a["stop_sequence"]) - Number(b["stop_sequence"]));
    }

    const shapeRowsById = new Map<string, CsvRow[]>();
    for (const row of shapes.rows) {
        const list = shapeRowsById.get(row["shape_id"]);
        if (list) list.push(row);
        else shapeRowsById.set(row["shape_id"], [row]);
    }
    for (const list of shapeRowsById.values()) {
        list.sort((a, b) => Number(a["shape_pt_sequence"]) - Number(b["shape_pt_sequence"]));
    }

    const metaByTrip = new Map<string, TripMeta>();
    const tripsByRoute = new Map<string, TripMeta[]>();
    for (const row of trips.rows) {
        const meta: TripMeta = {
            tripId: row["trip_id"],
            routeId: row["route_id"],
            directionId: Number.parseInt(row["direction_id"], 10),
            shapeId: row["shape_id"] ? row["shape_id"] : null,
        };
        metaByTrip.set(meta.tripId, meta);
        const list = tripsByRoute.get(meta.routeId);
        if (list) list.push(meta);
        else tripsByRoute.set(meta.routeId, [meta]);
    }

    /** Direcciones (paradas con coordenadas) de un viaje. */
    const stopsOf = (tripId: string): DirectionStop[] => {
        const rows = (rowsByTrip.get(tripId) ?? []).map(row => {
            const pos = coords.get(row["stop_id"]);
            return {
                ...row,
                stop_lat: pos ? String(pos.lat) : "",
                stop_lon: pos ? String(pos.lon) : "",
            };
        });
        return toDirectionStops(rows);
    };

    const reports: RouteReport[] = [];
    const toFix: TripMeta[] = [];
    const ambiguous: string[] = [];

    for (const [routeId, routeTrips] of tripsByRoute) {
        const ida = routeTrips.find(t => t.directionId === 0);
        const vuelta = routeTrips.find(t => t.directionId === 1);
        if (!ida || !vuelta) continue;
        const idaStops = stopsOf(ida.tripId);
        const vueltaStops = stopsOf(vuelta.tripId);
        const verdict = detectOrientation(idaStops, vueltaStops);
        const metrics = verdict.metrics ?? orientationMetrics(idaStops, vueltaStops);
        reports.push({
            routeId,
            idaTrip: ida.tripId,
            vueltaTrip: vuelta.tripId,
            estado: STATUS_LABEL[verdict.status] ?? verdict.status,
            mismoOrdenM: metrics ? Math.round(metrics.sameOrderM) : -1,
            espejoM: metrics ? Math.round(metrics.mirrorOrderM) : -1,
        });
        if (verdict.status === "reversed") toFix.push(vuelta);
        else if (verdict.status === "ambiguous") ambiguous.push(routeId);
    }

    // Lista blanca explícita: si el operador la dio, se respeta (y se avisa si el
    // detector no marcó alguna de esas rutas, por si hay deriva del diagnóstico).
    let candidates = toFix;
    if (args.only) {
        const detected = new Set(toFix.map(t => t.routeId));
        const missing = args.only.filter(r => !detected.has(r));
        if (missing.length > 0) {
            // eslint-disable-next-line no-console
            console.warn(`AVISO: el detector no marcó estas rutas pedidas: ${missing.join(", ")}`);
        }
        candidates = candidates.filter(t => args.only?.includes(t.routeId));
    }

    reports.sort((a, b) => a.routeId.localeCompare(b.routeId, "es"));

    // eslint-disable-next-line no-console
    console.log(`\n=== Diagnóstico de direcciones (${reports.length} rutas con ida+vuelta) ===`);
    // eslint-disable-next-line no-console
    console.table(reports.filter(r => r.estado !== STATUS_LABEL.ok));

    const correctCount = reports.filter(r => r.estado === STATUS_LABEL.ok).length;
    // eslint-disable-next-line no-console
    console.log(
        `correctas: ${correctCount} · detectadas como invertidas: ${toFix.length}` +
            ` · a reparar: ${candidates.length} · ambiguas: ${ambiguous.length}` +
            `${ambiguous.length ? ` (${ambiguous.join(", ")})` : ""}`,
    );

    // --- Copias reparadas de stop_times (paso 1) ---
    // (Los shapes NO se invierten aquí: su asignación y su orientación se
    // resuelven con el detector de lado de calzada, para no invertir el carril
    // equivocado.)
    const fixedStopTimeRows = new Map<string, CsvRow[]>();
    for (const vuelta of candidates) {
        const rows = rowsByTrip.get(vuelta.tripId);
        if (rows) fixedStopTimeRows.set(vuelta.tripId, reverseStopTimesRows(rows));
    }

    // --- Verificación del paso 1: la vuelta ya no debe verse duplicada ---
    const stillBad: string[] = [];
    for (const vuelta of candidates) {
        const ida = (tripsByRoute.get(vuelta.routeId) ?? []).find(t => t.directionId === 0);
        if (!ida) continue;
        const after = toDirectionStops(
            (fixedStopTimeRows.get(vuelta.tripId) ?? []).map(row => {
                const pos = coords.get(row["stop_id"]);
                return {
                    ...row,
                    stop_lat: pos ? String(pos.lat) : "",
                    stop_lon: pos ? String(pos.lon) : "",
                };
            }),
        );
        const verdict = detectOrientation(stopsOf(ida.tripId), after);
        if (verdict.status === "reversed") stillBad.push(vuelta.routeId);
        // eslint-disable-next-line no-console
        console.log(`ruta ${vuelta.routeId}: invertido ${vuelta.tripId} (${after.length} paradas)`);
    }
    if (stillBad.length > 0) {
        throw new Error(`La verificación falló: siguen invertidas ${stillBad.join(", ")}. No se escribe el zip.`);
    }

    // --- Paso 2: lado de calzada (contraflecha) ---
    // Cada viaje debe llevar el shape de SU calzada. La única verdad de campo es
    // el sentido de circulación de la calle, así que el detector puntúa cada
    // asignación contra los `oneway` de OSM: si intercambiar los shapes sube el
    // sentido peor de la ruta en ≥20 puntos, el intercambio es la reparación.
    const finalStopRows = (tripId: string): CsvRow[] =>
        fixedStopTimeRows.get(tripId) ?? rowsByTrip.get(tripId) ?? [];

    const latLonsOf = (rows: CsvRow[]): LatLon[] => {
        const out: LatLon[] = [];
        for (const row of rows) {
            const pos = coords.get(row["stop_id"]);
            if (pos && Number.isFinite(pos.lat) && Number.isFinite(pos.lon)) {
                out.push({ lat: pos.lat, lon: pos.lon });
            }
        }
        return out;
    };

    const shapePoints = (shapeId: string | null): LatLon[] | null => {
        const rows = shapeId ? shapeRowsById.get(shapeId) : null;
        if (!rows || rows.length < 2) return null;
        const points = rows.map(row => ({
            lat: Number.parseFloat(row["shape_pt_lat"]),
            lon: Number.parseFloat(row["shape_pt_lon"]),
        }));
        return points.every(p => Number.isFinite(p.lat) && Number.isFinite(p.lon)) ? points : null;
    };

    // Un shape compartido por varios viajes no se toca: invertirlo por uno
    // rompería al otro. En este feed cada shape pertenece a un único viaje.
    const shapeUsage = new Map<string, number>();
    for (const row of trips.rows) {
        const id = row["shape_id"];
        if (id) shapeUsage.set(id, (shapeUsage.get(id) ?? 0) + 1);
    }

    const shapeIdByTrip = new Map<string, string>();
    const swappedRoutes: string[] = [];
    const shapeReports: ShapeSideReport[] = [];

    if (!args.osm) {
        // eslint-disable-next-line no-console
        console.warn(
            "\nAVISO: sin --osm no se puede decidir el lado de calzada (los oneway de OSM son la " +
                "única referencia). Paso 2 omitido; usa --osm city.geojson para repararlo.\n",
        );
    } else {
        const index = await loadOneWayIndex(args.osm);
        // eslint-disable-next-line no-console
        console.log(`\nOSM: ${index.segments.length} tramos de un solo sentido indexados`);

        for (const [routeId, routeTrips] of tripsByRoute) {
            const ida = routeTrips.find(t => t.directionId === 0);
            const vuelta = routeTrips.find(t => t.directionId === 1);
            if (!ida || !vuelta || !ida.shapeId || !vuelta.shapeId) continue;
            const idaShape = shapePoints(ida.shapeId);
            const vueltaShape = shapePoints(vuelta.shapeId);
            if (!idaShape || !vueltaShape) continue;

            const decision = decideShapeSwap(
                { shape: idaShape, stops: latLonsOf(finalStopRows(ida.tripId)) },
                { shape: vueltaShape, stops: latLonsOf(finalStopRows(vuelta.tripId)) },
                index,
            );

            const rounded = (v: number | null): number => (v === null ? -1 : Math.round(v));
            shapeReports.push({
                routeId,
                estado: SHAPE_STATUS_LABEL[decision.status] ?? decision.status,
                idaActualPct: rounded(decision.current.ida),
                vueltaActualPct: rounded(decision.current.vuelta),
                idaSwapPct: rounded(decision.swapped.ida),
                vueltaSwapPct: rounded(decision.swapped.vuelta),
            });

            if (decision.status === "swapped" && ida.shapeId !== vuelta.shapeId) {
                if (args.only && !args.only.includes(routeId)) continue;
                shapeIdByTrip.set(ida.tripId, vuelta.shapeId);
                shapeIdByTrip.set(vuelta.tripId, ida.shapeId);
                swappedRoutes.push(routeId);
            }
        }

        // --- Verificación: tras intercambiar, el detector debe dar "keep" ---
        const stillSwapped: string[] = [];
        for (const routeId of swappedRoutes) {
            const routeTrips = tripsByRoute.get(routeId) ?? [];
            const ida = routeTrips.find(t => t.directionId === 0);
            const vuelta = routeTrips.find(t => t.directionId === 1);
            if (!ida || !vuelta) continue;
            const idaShape = shapePoints(shapeIdByTrip.get(ida.tripId) ?? ida.shapeId);
            const vueltaShape = shapePoints(shapeIdByTrip.get(vuelta.tripId) ?? vuelta.shapeId);
            if (!idaShape || !vueltaShape) continue;
            const after = decideShapeSwap(
                { shape: idaShape, stops: latLonsOf(finalStopRows(ida.tripId)) },
                { shape: vueltaShape, stops: latLonsOf(finalStopRows(vuelta.tripId)) },
                index,
            );
            if (after.status === "swapped") stillSwapped.push(routeId);
        }

        // eslint-disable-next-line no-console
        console.log("\n=== Lado de calzada (contraflecha) ===");
        // eslint-disable-next-line no-console
        console.table(shapeReports.filter(r => r.estado !== SHAPE_STATUS_LABEL.keep));
        // eslint-disable-next-line no-console
        console.log(
            `rutas revisadas: ${shapeReports.length}` +
                ` · calzada correcta: ${shapeReports.filter(r => r.estado === SHAPE_STATUS_LABEL.keep).length}` +
                ` · shapes intercambiados: ${swappedRoutes.length}` +
                `${swappedRoutes.length ? ` (${swappedRoutes.join(", ")})` : ""}` +
                ` · no concluyentes: ${shapeReports.filter(r => r.estado === SHAPE_STATUS_LABEL.inconclusive).length}`,
        );

        if (stillSwapped.length > 0) {
            throw new Error(
                `La verificación de calzada falló: siguen intercambiadas ${stillSwapped.join(", ")}. No se escribe el zip.`,
            );
        }
    }

    /**
     * Normaliza cada shape al orden de paradas del viaje que lo lleva. No
     * depende de OSM: invertir el orden de puntos no cambia de calzada, solo
     * deja el trazado empezando en la subida y acabando en la bajada.
     */
    const fixedShapeRows = new Map<string, CsvRow[]>();
    for (const routeTrips of tripsByRoute.values()) {
        for (const trip of routeTrips) {
            const shapeId = shapeIdByTrip.get(trip.tripId) ?? trip.shapeId;
            if (!shapeId || (shapeUsage.get(shapeId) ?? 0) > 1) continue;
            const rows = shapeRowsById.get(shapeId);
            const points = shapePoints(shapeId);
            if (!rows || !points) continue;
            const stops = latLonsOf(finalStopRows(trip.tripId));
            if (stops.length < 2) continue;
            if (!shapeFollowsStopOrder(points, stops)) fixedShapeRows.set(shapeId, reverseShapeRows(rows));
        }
    }

    const nothingToDo =
        swappedRoutes.length === 0 && fixedShapeRows.size === 0 && fixedStopTimeRows.size === 0;
    if (nothingToDo) {
        // eslint-disable-next-line no-console
        console.log("Nada que reparar.\n");
        return;
    }

    if (!args.apply) {
        // eslint-disable-next-line no-console
        console.log("\nDry-run: no se escribió nada. Repite con --apply para generar el zip reparado.\n");
        return;
    }

    // --- Reconstruir los CSV ---
    // stop_times: cada viaje reparado se sustituye en bloque en la posición de su
    // primera fila original, de modo que no se duplica ni se pierde ninguna.
    const orderedStopTimes: CsvRow[] = [];
    const emitted = new Set<string>();
    for (const row of stopTimes.rows) {
        const list = fixedStopTimeRows.get(row["trip_id"]);
        if (!list) {
            orderedStopTimes.push(row);
            continue;
        }
        if (emitted.has(row["trip_id"])) continue;
        emitted.add(row["trip_id"]);
        orderedStopTimes.push(...list);
    }

    // shapes: idem, por shape_id.
    const orderedShapes: CsvRow[] = [];
    const emittedShapes = new Set<string>();
    for (const row of shapes.rows) {
        const list = fixedShapeRows.get(row["shape_id"]);
        if (!list) {
            orderedShapes.push(row);
            continue;
        }
        if (emittedShapes.has(row["shape_id"])) continue;
        emittedShapes.add(row["shape_id"]);
        orderedShapes.push(...list);
    }

    // trips: reasignar el shape_id de los viajes cuyo shape cambió de calzada.
    const orderedTrips: CsvRow[] = trips.rows.map(row => {
        const next = shapeIdByTrip.get(row["trip_id"]);
        return next && next !== row["shape_id"] ? { ...row, shape_id: next } : row;
    });

    const outEntries: { name: string; data: Buffer }[] = [];
    for (const [name, data] of entries) {
        if (name === "stop_times.txt") {
            outEntries.push({ name, data: toCsv(stopTimes.header, orderedStopTimes) });
        } else if (name === "shapes.txt") {
            outEntries.push({ name, data: toCsv(shapes.header, orderedShapes) });
        } else if (name === "trips.txt") {
            outEntries.push({ name, data: toCsv(trips.header, orderedTrips) });
        } else {
            outEntries.push({ name, data });
        }
    }

    if (args.out === args.in) {
        const backup = resolve(`${resolve(".", "gtfs.orig.zip")}`);
        const created = await backupFile(args.in, backup);
        // eslint-disable-next-line no-console
        console.log(created ? `Respaldo original en ${backup}` : `Respaldo ya existía: ${backup}`);
    }
    await writeZipEntries(args.out, outEntries);
    // eslint-disable-next-line no-console
    console.log(
        `Zip reparado escrito en ${args.out} (${candidates.length} rutas con la vuelta invertida, ` +
            `${swappedRoutes.length} con los shapes intercambiados de calzada)\n`,
    );
}

main().catch(error => {
    // eslint-disable-next-line no-console
    console.error("Error reparando direcciones GTFS:", error);
    process.exit(1);
});
