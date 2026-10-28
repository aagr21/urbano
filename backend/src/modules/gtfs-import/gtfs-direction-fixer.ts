/**
 * Reparación de direcciones invertidas en el feed GTFS de Urbano.
 *
 * Contexto: algunas rutas del dataset vienen con la vuelta (`direction_id=1`)
 * generada como una copia EN EL MISMO ORDEN que la ida (`direction_id=0`), en
 * vez de como su espejo. El resultado es que ningún motor de itinerarios
 * (OTP2 ni el planner interno sobre PostGIS) puede ofrecer esa línea en el
 * sentido origen→destino, aunque en la calle exista y sea la opción más corta.
 *
 * Este módulo es LÓGICA PURA (sin fs, sin zip, sin BD) para poder testearlo sin
 * dependencias: detecta el defecto comparando ida/vuelta por posición relativa
 * del recorrido y produce las filas invertidas de `stop_times` y `shapes`.
 * La E/S vive en `fix-directions.cli.ts` + `gtfs-zip.writer.ts`.
 */

export type CsvRow = Record<string, string>;

/** Parada mínima necesaria para medir geometría (coordenadas + distancia). */
export interface DirectionStop {
    stopSequence: number;
    lat: number;
    lon: number;
    /** `shape_dist_traveled` en metros; `null` si el feed no lo provee. */
    distM: number | null;
    arrivalSec: number;
    departureSec: number;
}

/** Medición de alineación entre ida y vuelta, en metros de desalineación. */
export interface OrientationMetrics {
    /** Distancia media al emparejar ida[f] con vuelta[f] (orden idéntico). */
    sameOrderM: number;
    /** Distancia media al emparejar ida[f] con vuelta[1-f] (orden espejo). */
    mirrorOrderM: number;
    /** Número de muestras por dirección usadas en la comparación. */
    samples: number;
}

/** Diagnóstico de una pareja ida/vuelta. */
export type OrientationVerdict =
    | { status: "ok"; metrics: OrientationMetrics }
    | { status: "reversed"; metrics: OrientationMetrics }
    | { status: "ambiguous"; metrics: OrientationMetrics | null }
    | { status: "incomplete"; metrics: null };

/**
 * Umbrales del detector. Un feed bien orientado da `mirrorOrderM` cercano a
 * cero (ida y vuelta son carriles paralelos del mismo corredor) y `sameOrderM`
 * del orden de la longitud de la línea. Medidas reales sobre este feed: la 74
 * correcta da espejo 179 m vs mismo orden 3256 m; la 75 defectuosa da 345 m vs
 * 3645 m (invertidos).
 *
 * `maxSameOrderM` se fijó en el hueco observado entre el peor caso claro
 * (123: 612 m) y el primer caso dudoso (19: 1742 m); 800 m son ~dos manzanas.
 * Los tres criterios deben cumplirse a la vez para tocar el dataset.
 */
export const DIRECTION_THRESHOLDS = {
    /** Máxima desalineación para considerar que los órdenes coinciden. */
    maxSameOrderM: 800,
    /** Mínima separación para considerar que el orden espejo es real. */
    minMirrorOrderM: 2000,
    /** `sameOrderM` debe ser al menos este número de veces menor que el espejo. */
    dominanceRatio: 3,
};

/** Convierte `HH:mm:ss` de GTFS a segundos (las horas pueden superar 24). */
export function timeToSec(value: string): number {
    const parts = value.trim().split(":");
    if (parts.length < 2) return 0;
    const h = Number.parseInt(parts[0], 10) || 0;
    const m = Number.parseInt(parts[1], 10) || 0;
    const s = parts.length > 2 ? Number.parseInt(parts[2], 10) || 0 : 0;
    return h * 3600 + m * 60 + s;
}

/** Formatea segundos como `HH:mm:ss` (horas sin normalizar, como admite GTFS). */
export function secToTime(totalSec: number): string {
    const clamped = Math.max(0, Math.round(totalSec));
    const pad = (n: number) => String(n).padStart(2, "0");
    const h = Math.floor(clamped / 3600);
    const m = Math.floor((clamped % 3600) / 60);
    const s = clamped % 60;
    return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

/** Extrae geometría y horarios de un viaje a partir de sus filas de stop_times. */
export function toDirectionStops(rows: CsvRow[]): DirectionStop[] {
    return rows.map(row => {
        const dist = (row["shape_dist_traveled"] ?? "").trim();
        return {
            stopSequence: Number.parseInt(row["stop_sequence"] ?? "0", 10),
            lat: Number.parseFloat(row["stop_lat"] ?? ""),
            lon: Number.parseFloat(row["stop_lon"] ?? ""),
            distM: dist === "" ? null : Number.parseFloat(dist),
            arrivalSec: timeToSec(row["arrival_time"] ?? "00:00:00"),
            departureSec: timeToSec(row["departure_time"] ?? "00:00:00"),
        };
    });
}

/** Muestra equiespaciada de como mucho `count` índices sobre una lista de `n`. */
function spreadIndices(n: number, count: number): number[] {
    if (n <= 1) return [0];
    const k = Math.min(count, n);
    const out: number[] = [];
    for (let i = 0; i < k; i++) {
        out.push(Math.round((i * (n - 1)) / (k - 1)));
    }
    return out;
}

/**
 * Compara dos direcciones emparejándolas por POSICIÓN RELATIVA del recorrido.
 * Si `ida[f]` cae junto a `vuelta[1-f]`, son espejo (correcto); si cae junto a
 * `vuelta[f]`, están en el mismo orden (defecto de vuelta duplicada).
 *
 * El emparejamiento es posicional y no por vecino más cercano porque ida y
 * vuelta recorren el mismo corredor: con distancias al vecino más cercano
 * ambas métricas darían siempre unos pocos metros y el test no decidiría nada.
 * Ida y vuelta usan paradas distintas y pueden tener longitudes distintas, de
 * ahí mapear la fracción al índice equivalente de la otra dirección.
 */
export function orientationMetrics(
    ida: DirectionStop[],
    vuelta: DirectionStop[],
    sampleCount = 25,
): OrientationMetrics | null {
    if (ida.length < 2 || vuelta.length < 2) return null;
    if (ida.some(s => !Number.isFinite(s.lat) || !Number.isFinite(s.lon))) return null;
    if (vuelta.some(s => !Number.isFinite(s.lat) || !Number.isFinite(s.lon))) return null;

    const pairDistance = (i: number, targetFraction: number): number => {
        const j = Math.round(targetFraction * (vuelta.length - 1));
        return haversineMeters(ida[i].lat, ida[i].lon, vuelta[j].lat, vuelta[j].lon);
    };

    let sameSum = 0;
    let mirrorSum = 0;
    for (const i of spreadIndices(ida.length, sampleCount)) {
        const f = i / (ida.length - 1);
        sameSum += pairDistance(i, f);
        mirrorSum += pairDistance(i, 1 - f);
    }
    const samples = spreadIndices(ida.length, sampleCount).length;
    return {
        sameOrderM: sameSum / samples,
        mirrorOrderM: mirrorSum / samples,
        samples,
    };
}

/** Clasifica una pareja de direcciones usando los umbrales de arriba. */
export function detectOrientation(
    ida: DirectionStop[],
    vuelta: DirectionStop[],
    thresholds: typeof DIRECTION_THRESHOLDS = DIRECTION_THRESHOLDS,
): OrientationVerdict {
    const metrics = orientationMetrics(ida, vuelta);
    if (!metrics) return { status: "incomplete", metrics: null };
    const { sameOrderM, mirrorOrderM } = metrics;
    const dominated =
        sameOrderM <= thresholds.maxSameOrderM &&
        mirrorOrderM >= thresholds.minMirrorOrderM &&
        sameOrderM * thresholds.dominanceRatio < mirrorOrderM;
    if (dominated) return { status: "reversed", metrics };
    // Ningún orden cuadra: la comparación no es concluyente y no se toca la ruta.
    if (sameOrderM > thresholds.maxSameOrderM && mirrorOrderM > thresholds.minMirrorOrderM) {
        return { status: "ambiguous", metrics };
    }
    return { status: "ok", metrics };
}

/** Formatea metros con un decimal, recortando ceros sobrantes (`11.9`, `27500`). */
function formatMeters(value: number): string {
    const rounded = Math.round(value * 10) / 10;
    return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1);
}

/**
 * Invierte el orden de recorrido de un viaje preservando la duración y la
 * ventana horaria: el viaje invertido arranca a la hora de partida original y
 * termina a la hora de llegada original.
 *
 * Espejo temporal: con `base = departure(primera)` y `end = arrival(última)`,
 * cada tiempo se refleja alrededor del punto medio del recorrido, así que la
 * fila origen `j = n-1-i` recibe `arrival'_i = base + end - departure_j` y
 * `departure'_i = base + end - arrival_j`. Se conserva el dwell de cada parada
 * y el total de minutos del viaje. `shape_dist_traveled` se refleja de forma
 * análoga, anclada en la distancia del extremo (el feed real no arranca
 * exactamente en 0).
 */
export function reverseStopTimesRows(rows: CsvRow[]): CsvRow[] {
    if (rows.length < 2) return rows.map(row => ({ ...row }));
    const original = rows.map(row => ({ ...row }));
    const n = original.length;
    const base = timeToSec(original[0]["departure_time"] ?? "00:00:00");
    const end = timeToSec(original[n - 1]["arrival_time"] ?? "00:00:00");
    const mirror = base + Math.max(base, end);

    const dists = original.map(row => {
        const raw = (row["shape_dist_traveled"] ?? "").trim();
        return raw === "" ? null : Number.parseFloat(raw);
    });
    const known = dists.filter((d): d is number => d !== null && !Number.isNaN(d));
    const reflectsDist = known.length === n;
    const distTotal = reflectsDist ? Math.max(...known) : 0;
    const distAnchor = reflectsDist ? (dists[0] as number) : 0;

    const out: CsvRow[] = [];
    for (let i = 0; i < n; i++) {
        const src = original[n - 1 - i];
        const newRow: CsvRow = { ...src };
        newRow["stop_sequence"] = String(i + 1);

        const dep = timeToSec(src["departure_time"] ?? "00:00:00");
        const arr = timeToSec(src["arrival_time"] ?? "00:00:00");
        newRow["arrival_time"] = secToTime(mirror - dep);
        newRow["departure_time"] = secToTime(mirror - arr);

        if (reflectsDist) {
            const old = dists[n - 1 - i] as number;
            newRow["shape_dist_traveled"] = formatMeters(distAnchor + distTotal - old);
        }
        out.push(newRow);
    }
    return out;
}

/**
 * Invierte los puntos de un shape reflejando `shape_pt_sequence`. El feed de
 * Urbano no trae `shape_dist_traveled` en shapes.txt, pero se refleja por si
 * alguna versión futura del dataset lo incluye.
 */
export function reverseShapeRows(rows: CsvRow[]): CsvRow[] {
    if (rows.length < 2) return rows.map(row => ({ ...row }));
    const original = rows.map(row => ({ ...row }));
    const n = original.length;
    const dists = original.map(row => {
        const raw = (row["shape_dist_traveled"] ?? "").trim();
        return raw === "" ? null : Number.parseFloat(raw);
    });
    const known = dists.filter((d): d is number => d !== null && !Number.isNaN(d));
    const reflectsDist = known.length === n;
    const distTotal = reflectsDist ? Math.max(...known) : 0;

    const out: CsvRow[] = [];
    for (let i = 0; i < n; i++) {
        const src = original[n - 1 - i];
        const newRow: CsvRow = { ...src };
        newRow["shape_pt_sequence"] = String(i + 1);
        if (reflectsDist) {
            newRow["shape_dist_traveled"] = formatMeters(distTotal - Number(newRow["shape_dist_traveled"]));
        }
        out.push(newRow);
    }
    return out;
}

/**
 * Verificación de que la reparación volteó efectivamente la dirección: la
 * vuelta invertida comparada contra la ida debe dejar de verse defectuosa.
 */

import { haversineMeters } from '../../core/common/utils/geo';

// La fórmula antes duplicada aquí vive en la util compartida; re-exportar
// para quien llegue buscando por este módulo.
export { haversineMeters };
export function isRepairEffective(
    ida: DirectionStop[],
    vueltaBefore: DirectionStop[],
    vueltaAfter: DirectionStop[],
    thresholds: typeof DIRECTION_THRESHOLDS = DIRECTION_THRESHOLDS,
): boolean {
    const before = detectOrientation(ida, vueltaBefore, thresholds);
    const after = detectOrientation(ida, vueltaAfter, thresholds);
    return before.status === "reversed" && (after.status === "ok" || after.status === "ambiguous");
}
