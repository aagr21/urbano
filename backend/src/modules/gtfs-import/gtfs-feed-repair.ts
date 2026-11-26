import {
    CsvRow,
    DirectionStop,
    detectOrientation,
    orientationMetrics,
    reverseShapeRows,
    reverseStopTimesRows,
    toDirectionStops,
} from "./gtfs-direction-fixer";
import {
    LatLon,
    OneWayIndex,
    OneWaySegment,
    ShapeSideDecision,
    decideShapeSwap,
    shapeFollowsStopOrder,
} from "./gtfs-shape-side";

/**
 * Plan de reparación del feed (lo usa `fix-directions.cli.ts`): todo PURO,
 * sin zip, disco ni consola, para que cada paso se pruebe con tablas en
 * memoria (`gtfs-feed-repair.spec.ts`). Los detectores viven en
 * `gtfs-direction-fixer` (paso 1) y `gtfs-shape-side` (paso 2).
 */

export interface CsvTable {
    header: string[];
    rows: CsvRow[];
}

export interface TripMeta {
    tripId: string;
    routeId: string;
    directionId: number;
    shapeId: string | null;
}

/** El feed indexado para las preguntas que hacen los dos pasos. */
export interface FeedIndex {
    trips: CsvTable;
    stopTimes: CsvTable;
    shapes: CsvTable;
    coords: Map<string, LatLon>;
    /** stop_times por viaje, ordenados por `stop_sequence`. */
    rowsByTrip: Map<string, CsvRow[]>;
    /** shapes por id, ordenados por `shape_pt_sequence`. */
    shapeRowsById: Map<string, CsvRow[]>;
    tripsByRoute: Map<string, TripMeta[]>;
    /** Cuántos viajes usan cada shape (uno compartido no se toca). */
    shapeUsage: Map<string, number>;
}

function groupSorted(rows: CsvRow[], key: string, order: string): Map<string, CsvRow[]> {
    const map = new Map<string, CsvRow[]>();
    for (const row of rows) {
        const list = map.get(row[key]);
        if (list) list.push(row);
        else map.set(row[key], [row]);
    }
    for (const list of map.values()) {
        list.sort((a, b) => Number(a[order]) - Number(b[order]));
    }
    return map;
}

export function indexFeed(feed: {
    trips: CsvTable;
    stops: CsvTable;
    stopTimes: CsvTable;
    shapes: CsvTable;
}): FeedIndex {
    const coords = new Map<string, LatLon>();
    for (const row of feed.stops.rows) {
        coords.set(row["stop_id"], {
            lat: Number.parseFloat(row["stop_lat"]),
            lon: Number.parseFloat(row["stop_lon"]),
        });
    }

    const tripsByRoute = new Map<string, TripMeta[]>();
    const shapeUsage = new Map<string, number>();
    for (const row of feed.trips.rows) {
        const meta: TripMeta = {
            tripId: row["trip_id"],
            routeId: row["route_id"],
            directionId: Number.parseInt(row["direction_id"], 10),
            shapeId: row["shape_id"] ? row["shape_id"] : null,
        };
        const list = tripsByRoute.get(meta.routeId);
        if (list) list.push(meta);
        else tripsByRoute.set(meta.routeId, [meta]);
        if (meta.shapeId) shapeUsage.set(meta.shapeId, (shapeUsage.get(meta.shapeId) ?? 0) + 1);
    }

    return {
        trips: feed.trips,
        stopTimes: feed.stopTimes,
        shapes: feed.shapes,
        coords,
        rowsByTrip: groupSorted(feed.stopTimes.rows, "trip_id", "stop_sequence"),
        shapeRowsById: groupSorted(feed.shapes.rows, "shape_id", "shape_pt_sequence"),
        tripsByRoute,
        shapeUsage,
    };
}

/** Ida (`direction_id=0`) y vuelta (`1`) de una ruta, si tiene ambas. */
export function idaVuelta(trips: TripMeta[]): { ida: TripMeta; vuelta: TripMeta } | null {
    const ida = trips.find(t => t.directionId === 0);
    const vuelta = trips.find(t => t.directionId === 1);
    return ida && vuelta ? { ida, vuelta } : null;
}

/** Paradas con coordenadas de unas filas de stop_times (para el paso 1). */
export function directionStopsOf(feed: FeedIndex, rows: CsvRow[]): DirectionStop[] {
    return toDirectionStops(
        rows.map(row => {
            const pos = feed.coords.get(row["stop_id"]);
            return {
                ...row,
                stop_lat: pos ? String(pos.lat) : "",
                stop_lon: pos ? String(pos.lon) : "",
            };
        }),
    );
}

/** Coordenadas válidas de las paradas de unas filas (para el paso 2). */
export function stopLatLons(feed: FeedIndex, rows: CsvRow[]): LatLon[] {
    const out: LatLon[] = [];
    for (const row of rows) {
        const pos = feed.coords.get(row["stop_id"]);
        if (pos && Number.isFinite(pos.lat) && Number.isFinite(pos.lon)) out.push(pos);
    }
    return out;
}

/** Puntos de un shape (≥ 2 y todos finitos), o `null`. */
export function shapePoints(feed: FeedIndex, shapeId: string | null): LatLon[] | null {
    const rows = shapeId ? feed.shapeRowsById.get(shapeId) : null;
    if (!rows || rows.length < 2) return null;
    const points = rows.map(row => ({
        lat: Number.parseFloat(row["shape_pt_lat"]),
        lon: Number.parseFloat(row["shape_pt_lon"]),
    }));
    return points.every(p => Number.isFinite(p.lat) && Number.isFinite(p.lon)) ? points : null;
}

// ── Paso 1: vuelta duplicada ────────────────────────────────────────────────

export interface DirectionDiagnosis {
    routeId: string;
    idaTrip: string;
    vueltaTrip: string;
    status: string;
    sameOrderM: number;
    mirrorOrderM: number;
}

export interface DirectionPlan {
    diagnoses: DirectionDiagnosis[];
    /** Vueltas detectadas como copiadas en el orden de la ida. */
    reversed: TripMeta[];
    ambiguous: string[];
}

/** Diagnostica cada ruta con ida y vuelta (orden alfabético es). */
export function diagnoseDirections(feed: FeedIndex): DirectionPlan {
    const diagnoses: DirectionDiagnosis[] = [];
    const reversed: TripMeta[] = [];
    const ambiguous: string[] = [];
    for (const [routeId, trips] of feed.tripsByRoute) {
        const pair = idaVuelta(trips);
        if (!pair) continue;
        const idaStops = directionStopsOf(feed, feed.rowsByTrip.get(pair.ida.tripId) ?? []);
        const vueltaStops = directionStopsOf(feed, feed.rowsByTrip.get(pair.vuelta.tripId) ?? []);
        const verdict = detectOrientation(idaStops, vueltaStops);
        const metrics = verdict.metrics ?? orientationMetrics(idaStops, vueltaStops);
        diagnoses.push({
            routeId,
            idaTrip: pair.ida.tripId,
            vueltaTrip: pair.vuelta.tripId,
            status: verdict.status,
            sameOrderM: metrics ? Math.round(metrics.sameOrderM) : -1,
            mirrorOrderM: metrics ? Math.round(metrics.mirrorOrderM) : -1,
        });
        if (verdict.status === "reversed") reversed.push(pair.vuelta);
        else if (verdict.status === "ambiguous") ambiguous.push(routeId);
    }
    diagnoses.sort((a, b) => a.routeId.localeCompare(b.routeId, "es"));
    return { diagnoses, reversed, ambiguous };
}

/**
 * Lista blanca del operador (`--routes`): se respeta, y se informa qué rutas
 * pedidas NO marcó el detector (por si hay deriva del diagnóstico).
 */
export function restrictToRoutes(
    detected: TripMeta[],
    only: string[] | null,
): { selected: TripMeta[]; missing: string[] } {
    if (!only) return { selected: detected, missing: [] };
    const ids = new Set(detected.map(t => t.routeId));
    return {
        selected: detected.filter(t => only.includes(t.routeId)),
        missing: only.filter(r => !ids.has(r)),
    };
}

/** stop_times invertidos de cada vuelta elegida, por trip_id. */
export function reverseVueltas(feed: FeedIndex, vueltas: TripMeta[]): Map<string, CsvRow[]> {
    const fixed = new Map<string, CsvRow[]>();
    for (const vuelta of vueltas) {
        const rows = feed.rowsByTrip.get(vuelta.tripId);
        if (rows) fixed.set(vuelta.tripId, reverseStopTimesRows(rows));
    }
    return fixed;
}

/** Rutas cuya vuelta SIGUE viéndose duplicada tras la reparación. */
export function stillReversedAfter(
    feed: FeedIndex,
    vueltas: TripMeta[],
    fixedStopTimes: Map<string, CsvRow[]>,
): string[] {
    const bad: string[] = [];
    for (const vuelta of vueltas) {
        const ida = idaVuelta(feed.tripsByRoute.get(vuelta.routeId) ?? [])?.ida;
        if (!ida) continue;
        const after = directionStopsOf(feed, fixedStopTimes.get(vuelta.tripId) ?? []);
        const before = directionStopsOf(feed, feed.rowsByTrip.get(ida.tripId) ?? []);
        if (detectOrientation(before, after).status === "reversed") bad.push(vuelta.routeId);
    }
    return bad;
}

// ── Paso 2: lado de calzada (contraflecha) ──────────────────────────────────

export interface ShapeSideDiagnosis {
    routeId: string;
    decision: ShapeSideDecision;
}

export interface ShapeSidePlan {
    diagnoses: ShapeSideDiagnosis[];
    /** Nuevo shape de cada viaje cuyos shapes se intercambian. */
    shapeIdByTrip: Map<string, string>;
    swappedRoutes: string[];
}

/** Paradas FINALES de un viaje (con la reparación del paso 1 aplicada). */
export type StopRowsOf = (tripId: string) => CsvRow[];

function decideFor(
    feed: FeedIndex,
    ida: TripMeta,
    vuelta: TripMeta,
    idaShapeId: string | null,
    vueltaShapeId: string | null,
    stopRows: StopRowsOf,
    index: OneWayIndex,
): ShapeSideDecision | null {
    const idaShape = shapePoints(feed, idaShapeId);
    const vueltaShape = shapePoints(feed, vueltaShapeId);
    if (!idaShape || !vueltaShape) return null;
    return decideShapeSwap(
        { shape: idaShape, stops: stopLatLons(feed, stopRows(ida.tripId)) },
        { shape: vueltaShape, stops: stopLatLons(feed, stopRows(vuelta.tripId)) },
        index,
    );
}

/**
 * Cada viaje debe llevar el shape de SU calzada: se puntúa cada asignación
 * contra los `oneway` de OSM y, si intercambiar los shapes es la reparación,
 * se planea el intercambio (respetando la lista blanca [only]).
 */
export function planShapeSwaps(
    feed: FeedIndex,
    stopRows: StopRowsOf,
    index: OneWayIndex,
    only: string[] | null,
): ShapeSidePlan {
    const diagnoses: ShapeSideDiagnosis[] = [];
    const shapeIdByTrip = new Map<string, string>();
    const swappedRoutes: string[] = [];
    for (const [routeId, trips] of feed.tripsByRoute) {
        const pair = idaVuelta(trips);
        if (!pair || !pair.ida.shapeId || !pair.vuelta.shapeId) continue;
        const { ida, vuelta } = pair;
        const decision = decideFor(feed, ida, vuelta, ida.shapeId, vuelta.shapeId, stopRows, index);
        if (!decision) continue;
        diagnoses.push({ routeId, decision });
        if (decision.status !== "swapped" || ida.shapeId === vuelta.shapeId) continue;
        if (only && !only.includes(routeId)) continue;
        shapeIdByTrip.set(ida.tripId, vuelta.shapeId!);
        shapeIdByTrip.set(vuelta.tripId, ida.shapeId!);
        swappedRoutes.push(routeId);
    }
    return { diagnoses, shapeIdByTrip, swappedRoutes };
}

/** Rutas que el detector SIGUE viendo intercambiadas tras el plan. */
export function stillSwappedAfter(
    feed: FeedIndex,
    plan: ShapeSidePlan,
    stopRows: StopRowsOf,
    index: OneWayIndex,
): string[] {
    const bad: string[] = [];
    for (const routeId of plan.swappedRoutes) {
        const pair = idaVuelta(feed.tripsByRoute.get(routeId) ?? []);
        if (!pair) continue;
        const { ida, vuelta } = pair;
        const after = decideFor(
            feed,
            ida,
            vuelta,
            plan.shapeIdByTrip.get(ida.tripId) ?? ida.shapeId,
            plan.shapeIdByTrip.get(vuelta.tripId) ?? vuelta.shapeId,
            stopRows,
            index,
        );
        if (after?.status === "swapped") bad.push(routeId);
    }
    return bad;
}

/**
 * Normaliza cada shape al orden de paradas del viaje que lo lleva (sin OSM:
 * invertir el orden de puntos no cambia de calzada, solo deja el trazado
 * empezando en la subida). Un shape compartido no se toca.
 */
export function planShapeNormalization(
    feed: FeedIndex,
    shapeIdByTrip: Map<string, string>,
    stopRows: StopRowsOf,
): Map<string, CsvRow[]> {
    const fixed = new Map<string, CsvRow[]>();
    for (const trips of feed.tripsByRoute.values()) {
        for (const trip of trips) {
            const shapeId = shapeIdByTrip.get(trip.tripId) ?? trip.shapeId;
            if (!shapeId || (feed.shapeUsage.get(shapeId) ?? 0) > 1) continue;
            const rows = feed.shapeRowsById.get(shapeId);
            const points = shapePoints(feed, shapeId);
            if (!rows || !points) continue;
            const stops = stopLatLons(feed, stopRows(trip.tripId));
            if (stops.length < 2) continue;
            if (!shapeFollowsStopOrder(points, stops)) fixed.set(shapeId, reverseShapeRows(rows));
        }
    }
    return fixed;
}

// ── Reconstrucción de los CSV ───────────────────────────────────────────────

/**
 * Sustituye en bloque las filas de cada clave reparada, en la posición de su
 * primera fila original: no se duplica ni se pierde ninguna.
 */
export function replaceRowBlocks(
    rows: CsvRow[],
    keyColumn: string,
    replacements: Map<string, CsvRow[]>,
): CsvRow[] {
    const out: CsvRow[] = [];
    const emitted = new Set<string>();
    for (const row of rows) {
        const key = row[keyColumn];
        const block = replacements.get(key);
        if (!block) {
            out.push(row);
            continue;
        }
        if (emitted.has(key)) continue;
        emitted.add(key);
        out.push(...block);
    }
    return out;
}

/** trips.txt con el shape_id reasignado de los viajes que cambian de calzada. */
export function reassignShapes(rows: CsvRow[], shapeIdByTrip: Map<string, string>): CsvRow[] {
    return rows.map(row => {
        const next = shapeIdByTrip.get(row["trip_id"]);
        return next && next !== row["shape_id"] ? { ...row, shape_id: next } : row;
    });
}

// ── OSM ─────────────────────────────────────────────────────────────────────

/** GeoJSON mínimo de `osmium export` (solo lo que usa el detector). */
export interface OsmFeature {
    geometry: { type: string; coordinates: unknown } | null;
    properties: Record<string, unknown> | null;
}

/**
 * Tramos de calle de un solo sentido, ya orientados en su sentido permitido
 * (`oneway=-1` se invierte; una rotonda cuenta como `oneway=yes`).
 */
export function oneWaySegmentsFromOsm(features: OsmFeature[]): OneWaySegment[] {
    const segments: OneWaySegment[] = [];
    const pushLine = (coords: number[][], oneway: string): void => {
        for (let i = 1; i < coords.length; i++) {
            const [lonA, latA] = coords[i - 1];
            const [lonB, latB] = coords[i];
            if (!Number.isFinite(latA) || !Number.isFinite(latB)) continue;
            if (latA === latB && lonA === lonB) continue;
            const a = { lat: latA, lon: lonA };
            const b = { lat: latB, lon: lonB };
            segments.push(oneway === "-1" ? { a: b, b: a } : { a, b });
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
    return segments;
}
