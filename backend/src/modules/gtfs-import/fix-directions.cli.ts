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
import { backupFile, parseCsv, readZipEntries, toCsv, writeZipEntries } from "./gtfs-zip.writer";

/**
 * CLI de reparación de direcciones: npm run fix:gtfs-directions
 *
 * Detecta rutas cuya vuelta (`direction_id=1`) está duplicada en el mismo
 * orden que la ida y las invierte (stop_times + shapes), reescribiendo el zip.
 * Sin `--apply` solo informa (dry-run), para poder revisar el diagnóstico
 * antes de tocar el dataset. No toca la base de datos: después hay que
 * re-importar (`npm run import:gtfs`) y reconstruir el grafo de OTP.
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

interface Args {
    in: string;
    out: string;
    apply: boolean;
    /** Si se indica, solo se reparan estas rutas (el diagnóstico sigue siendo global). */
    only: string[] | null;
}

function parseArgs(argv: string[]): Args {
    const args: Args = { in: "gtfs.zip", out: "", apply: false, only: null };
    for (let i = 0; i < argv.length; i++) {
        const token = argv[i];
        if (token === "--apply") args.apply = true;
        else if (token === "--dry-run") args.apply = false;
        else if (token === "--in" && argv[i + 1]) args.in = argv[++i];
        else if (token === "--out" && argv[i + 1]) args.out = argv[++i];
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

const STATUS_LABEL: Record<string, string> = {
    ok: "correcta",
    reversed: "INVERTIDA",
    ambiguous: "ambigua (se omite)",
    incomplete: "sin datos",
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

    if (candidates.length === 0) {
        // eslint-disable-next-line no-console
        console.log("Nada que reparar.\n");
        return;
    }

    if (!args.apply) {
        // eslint-disable-next-line no-console
        console.log("\nDry-run: no se escribió nada. Repite con --apply para generar el zip reparado.\n");
        return;
    }

    // --- Aplicar la inversión sobre las copias de las filas ---
    const fixedStopTimeRows = new Map<string, CsvRow[]>();
    const fixedShapeRows = new Map<string, CsvRow[]>();
    for (const vuelta of candidates) {
        const rows = rowsByTrip.get(vuelta.tripId);
        if (rows) fixedStopTimeRows.set(vuelta.tripId, reverseStopTimesRows(rows));
        if (vuelta.shapeId) {
            const shapeRows = shapeRowsById.get(vuelta.shapeId);
            if (shapeRows) fixedShapeRows.set(vuelta.shapeId, reverseShapeRows(shapeRows));
        }
    }

    // --- Verificación: tras invertir, el detector ya no debe ver el defecto ---
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
        const shapeCount = vuelta.shapeId ? (shapeRowsById.get(vuelta.shapeId) ?? []).length : 0;
        // eslint-disable-next-line no-console
        console.log(
            `ruta ${vuelta.routeId}: invertidos ${vuelta.tripId} (${after.length} paradas) y ` +
                `shape ${vuelta.shapeId ?? "—"} (${shapeCount} puntos)`,
        );
    }
    if (stillBad.length > 0) {
        throw new Error(`La verificación falló: siguen invertidas ${stillBad.join(", ")}. No se escribe el zip.`);
    }

    // --- Reconstruir los CSV: cada viaje reparado se sustituye en bloque ---
    // Se emite el bloque invertido en la posición de la primera fila original del
    // viaje y se descartan las demás, de modo que no se duplica ni pierde ninguna.
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

    const outEntries: { name: string; data: Buffer }[] = [];
    for (const [name, data] of entries) {
        if (name === "stop_times.txt") {
            outEntries.push({ name, data: toCsv(stopTimes.header, orderedStopTimes) });
        } else if (name === "shapes.txt") {
            outEntries.push({ name, data: toCsv(shapes.header, orderedShapes) });
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
    console.log(`Zip reparado escrito en ${args.out} (${candidates.length} rutas invertidas)\n`);
}

main().catch(error => {
    // eslint-disable-next-line no-console
    console.error("Error reparando direcciones GTFS:", error);
    process.exit(1);
});
