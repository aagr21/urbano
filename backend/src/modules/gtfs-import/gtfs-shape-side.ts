/**
 * Corrección del LADO DE CALZADA de los `shape` de una ruta (contraflecha).
 *
 * Contexto: en este feed varias rutas traen el `shape` de la ida asignado a la
 * vuelta y viceversa. El trazado no está "al revés" en el orden de sus puntos
 * (una polilínea sin flechas se ve igual en ambos sentidos); lo que está mal es
 * la CALZADA. En avenidas de doble calzada el micro aparece dibujado circulando
 * por el carril del sentido opuesto, que es exactamente la queja de "va en
 * sentido contrario".
 *
 * Por qué no basta con comparar los dos `shape` entre sí: si la ida lleva el
 * shape de la vuelta y viceversa, el par de geometrías es el mismo y cualquier
 * métrica relativa (¿la calzada hermana queda a la izquierda?) da idéntico
 * resultado antes y después del intercambio. La única verdad de campo es el
 * sentido de circulación de la calle, que se lee de los `oneway` de OSM.
 *
 * El módulo es LÓGICA PURA (sin fs, sin zip, sin red): recibe los segmentos
 * `oneway` ya extraídos de OSM y decide, por ruta, si conviene intercambiar los
 * `shape` entre ida y vuelta. El CLI es quien lee el GeoJSON de `osmium export`.
 */

export interface LatLon {
  lat: number;
  lon: number;
}

/** Tramo de calle de un solo sentido, ya orientado en su sentido permitido. */
export interface OneWaySegment {
  a: LatLon;
  b: LatLon;
}

/** Índice espacial (rejilla) sobre los tramos `oneway`. */
export interface OneWayIndex {
  segments: OneWaySegment[];
  /** Clave `i:j` de celda → índices de segmentos que la tocan. */
  cells: Map<string, number[]>;
  cellDeg: number;
}

/**
 * Umbrales del detector. Medidos sobre el feed real contra los `oneway` de OSM
 * del área urbana: las rutas sanas dan 76-100 % de muestras a favor y las que
 * tienen los shapes intercambiados dan 0-22 %. El margen de 20 puntos separa
 * ambos grupos sin ambigüedad (la mejora mínima observada es +58).
 */
export const SHAPE_SIDE_THRESHOLDS = {
  /** Muestras por shape (a lo largo de su longitud). */
  samples: 60,
  /** Puntos a cada lado para medir el rumbo local. */
  bearingWindow: 5,
  /** Distancia máxima a la calle para que la muestra cuente (m). */
  maxStreetMeters: 15,
  /** Ángulo máximo entre el rumbo del shape y el de la calle (grados). */
  maxAngleDeg: 75,
  /** Muestras mínimas sobre calle de un solo sentido para concluir. */
  minSamples: 6,
  /** Mejora mínima (puntos porcentuales) para intercambiar los shapes. */
  minGainPoints: 20,
  /** Puntaje mínimo del sentido peor tras el intercambio para aceptarlo. */
  minSwappedScore: 60,
  /** Tamaño de celda del índice espacial (grados; ~60 m). */
  cellDeg: 0.0006,
} as const;

const METERS_PER_DEGREE_LAT = 110_540;
const METERS_PER_DEGREE_LON_AT_EQUATOR = 111_320;

const toRad = (deg: number): number => (deg * Math.PI) / 180;

export function haversineMeters(a: LatLon, b: LatLon): number {
  const R = 6_371_000;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Rumbo de `a` a `b` en grados (0 = norte, 90 = este). */
export function bearing(a: LatLon, b: LatLon): number {
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const dLon = toRad(b.lon - a.lon);
  const y = Math.sin(dLon) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

/** Diferencia angular absoluta entre dos rumbos, en [0, 180]. */
export function angleDifference(a: number, b: number): number {
  const d = Math.abs(a - b) % 360;
  return d > 180 ? 360 - d : d;
}

const cellKey = (lat: number, lon: number, cellDeg: number): string =>
  `${Math.floor(lat / cellDeg)}:${Math.floor(lon / cellDeg)}`;

/** Construye el índice espacial de los tramos `oneway`. */
export function buildOneWayIndex(
  segments: OneWaySegment[],
  cellDeg: number = SHAPE_SIDE_THRESHOLDS.cellDeg
): OneWayIndex {
  const cells = new Map<string, number[]>();
  segments.forEach((seg, i) => {
    for (const p of [seg.a, seg.b]) {
      const key = cellKey(p.lat, p.lon, cellDeg);
      const list = cells.get(key);
      if (list) list.push(i);
      else cells.set(key, [i]);
    }
  });
  return { segments, cells, cellDeg };
}

/** Distancia (m) de `p` al segmento `a`-`b`, en un plano local. */
function pointToSegmentMeters(p: LatLon, a: LatLon, b: LatLon): number {
  const kx = Math.cos(toRad(p.lat)) * METERS_PER_DEGREE_LON_AT_EQUATOR;
  const ky = METERS_PER_DEGREE_LAT;
  const px = p.lon * kx;
  const py = p.lat * ky;
  const ax = a.lon * kx;
  const ay = a.lat * ky;
  const bx = b.lon * kx;
  const by = b.lat * ky;
  const dx = bx - ax;
  const dy = by - ay;
  if (dx === 0 && dy === 0) return Math.hypot(px - ax, py - ay);
  const t = Math.max(
    0,
    Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
  );
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

/** Tramo `oneway` más cercano a `p` (o `null` si no hay ninguno cerca). */
function nearestOneWay(
  index: OneWayIndex,
  p: LatLon,
  maxMeters: number
): { segment: OneWaySegment; meters: number } | null {
  const { cellDeg } = index;
  const ci = Math.floor(p.lat / cellDeg);
  const cj = Math.floor(p.lon / cellDeg);
  let bestMeters = Number.POSITIVE_INFINITY;
  let bestSegment: OneWaySegment | null = null;
  // Radio creciente: la rejilla indexa por extremos, así que hay que ampliar
  // hasta que la mejor distancia quede dentro del radio ya explorado.
  for (let r = 0; r <= 3; r++) {
    for (let i = ci - r; i <= ci + r; i++) {
      for (let j = cj - r; j <= cj + r; j++) {
        const list = index.cells.get(`${i}:${j}`);
        if (!list) continue;
        for (const k of list) {
          const seg = index.segments[k];
          const d = pointToSegmentMeters(p, seg.a, seg.b);
          if (d < bestMeters) {
            bestMeters = d;
            bestSegment = seg;
          }
        }
      }
    }
    if (bestMeters <= r * cellDeg * METERS_PER_DEGREE_LAT) break;
  }
  return bestSegment && bestMeters <= maxMeters
    ? { segment: bestSegment, meters: bestMeters }
    : null;
}

/** Longitud acumulada (m) de una polilínea. */
export function cumulativeMeters(points: LatLon[]): number[] {
  const acc = [0];
  for (let i = 1; i < points.length; i++)
    acc.push(acc[i - 1] + haversineMeters(points[i - 1], points[i]));
  return acc;
}

/** Punto a una fracción (0..1) de la longitud total de la polilínea. */
function pointAtFraction(
  points: LatLon[],
  acc: number[],
  fraction: number
): LatLon {
  const total = acc[acc.length - 1];
  if (total <= 0) return points[0];
  const target = Math.min(Math.max(fraction, 0), 1) * total;
  let lo = 0;
  let hi = acc.length - 1;
  while (lo < hi) {
    const mid = Math.floor((lo + hi) / 2);
    if (acc[mid] < target) lo = mid + 1;
    else hi = mid;
  }
  const i = Math.max(lo, 1);
  const span = acc[i] - acc[i - 1];
  const t = span <= 0 ? 0 : (target - acc[i - 1]) / span;
  return {
    lat: points[i - 1].lat + (points[i].lat - points[i - 1].lat) * t,
    lon: points[i - 1].lon + (points[i].lon - points[i - 1].lon) * t,
  };
}

/** Puntaje de un trazado recorrido en un sentido: % de muestras a favor de la calle. */
export interface DirectionScore {
  /** Muestras sobre calle de un solo sentido. */
  samples: number;
  /** Muestras alineadas con el sentido permitido. */
  inFavor: number;
  /** Porcentaje a favor (0-100), o `null` si no hay muestras suficientes. */
  percent: number | null;
}

/**
 * Puntúa un `shape` recorrido en el orden dado contra los `oneway` de OSM.
 * Se muestrea por longitud (no por índice) para que la densidad de puntos del
 * shape no sesgue el resultado.
 */
export function scoreDirection(
  index: OneWayIndex,
  points: LatLon[],
  options: { samples?: number; bearingWindow?: number } = {}
): DirectionScore {
  const samples = options.samples ?? SHAPE_SIDE_THRESHOLDS.samples;
  const window = options.bearingWindow ?? SHAPE_SIDE_THRESHOLDS.bearingWindow;
  if (points.length < 2 * window + 1)
    return { samples: 0, inFavor: 0, percent: null };

  const acc = cumulativeMeters(points);
  let total = 0;
  let inFavor = 0;
  for (let i = 0; i < samples; i++) {
    const a = pointAtFraction(points, acc, i / samples);
    const b = pointAtFraction(points, acc, Math.min(1, (i + 1) / samples));
    if (a.lat === b.lat && a.lon === b.lon) continue;
    const near = nearestOneWay(index, a, SHAPE_SIDE_THRESHOLDS.maxStreetMeters);
    if (!near) continue;
    const streetBearing = bearing(near.segment.a, near.segment.b);
    total++;
    if (
      angleDifference(streetBearing, bearing(a, b)) <
      SHAPE_SIDE_THRESHOLDS.maxAngleDeg
    )
      inFavor++;
  }
  return {
    samples: total,
    inFavor,
    percent:
      total >= SHAPE_SIDE_THRESHOLDS.minSamples
        ? (100 * inFavor) / total
        : null,
  };
}

/** Puntaje del shape en su orden almacenado y en el invertido (cacheable). */
export interface ShapeScores {
  forward: DirectionScore;
  backward: DirectionScore;
}

export function shapeScores(index: OneWayIndex, shape: LatLon[]): ShapeScores {
  return {
    forward: scoreDirection(index, shape),
    backward: scoreDirection(index, [...shape].reverse()),
  };
}

/**
 * Distancia acumulada del punto de `points` más cercano a `p`. Es la
 * proyección que permite saber si un shape avanza o retrocede respecto de la
 * secuencia de paradas; funciona también en rutas circulares, donde comparar
 * los extremos no dice nada.
 */
function projectedMeters(points: LatLon[], acc: number[], p: LatLon): number {
  let bestMeters = Number.POSITIVE_INFINITY;
  let bestAlong = 0;
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1];
    const b = points[i];
    const kx = Math.cos(toRad(p.lat)) * METERS_PER_DEGREE_LON_AT_EQUATOR;
    const ky = METERS_PER_DEGREE_LAT;
    const px = p.lon * kx;
    const py = p.lat * ky;
    const ax = a.lon * kx;
    const ay = a.lat * ky;
    const bx = b.lon * kx;
    const by = b.lat * ky;
    const dx = bx - ax;
    const dy = by - ay;
    const t =
      dx === 0 && dy === 0
        ? 0
        : Math.max(
            0,
            Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
          );
    const d = Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
    if (d < bestMeters) {
      bestMeters = d;
      bestAlong = acc[i - 1] + t * (acc[i] - acc[i - 1]);
    }
  }
  return bestAlong;
}

/**
 * `true` si el shape, en su orden almacenado, avanza con la secuencia de
 * paradas. Se decide por la monotonía de la proyección de cada parada sobre el
 * trazado (válido para rutas circulares, donde el primer y el último punto
 * coinciden y comparar extremos no distingue nada).
 */
export function shapeFollowsStopOrder(
  shape: LatLon[],
  stops: LatLon[]
): boolean {
  if (shape.length < 2 || stops.length < 2) return true;
  const acc = cumulativeMeters(shape);
  const along = stops.map((p) => projectedMeters(shape, acc, p));
  let increasing = 0;
  for (let i = 1; i < along.length; i++)
    if (along[i] >= along[i - 1]) increasing++;
  const pairs = along.length - 1;
  return increasing >= pairs - increasing;
}

/** Puntaje de un viaje: el de su shape en el sentido que marcan sus paradas. */
export function tripScore(
  scores: ShapeScores,
  shape: LatLon[],
  stops: LatLon[]
): DirectionScore {
  return shapeFollowsStopOrder(shape, stops) ? scores.forward : scores.backward;
}

/** Veredicto del intercambio de shapes entre ida y vuelta. */
export interface ShapeSideDecision {
  status: 'swapped' | 'keep' | 'inconclusive';
  /** Motivo cuando no se puede concluir. */
  reason?: 'incomplete' | 'no-street-samples';
  /** Puntaje de la ida y de la vuelta con la asignación actual. */
  current: { ida: number | null; vuelta: number | null };
  /** Puntaje de la ida y de la vuelta si se intercambian los shapes. */
  swapped: { ida: number | null; vuelta: number | null };
  /** `true` si el shape de la ida debe recorrerse invertido para seguir sus paradas. */
  idaReversed: boolean;
  /** `true` si el shape de la vuelta debe recorrerse invertido para seguir sus paradas. */
  vueltaReversed: boolean;
}

export interface RouteDirection {
  shape: LatLon[];
  stops: LatLon[];
}

const worst = (a: number | null, b: number | null): number =>
  a === null || b === null ? -1 : Math.min(a, b);

/**
 * Decide si conviene intercambiar los `shape` de ida y vuelta.
 *
 * Se puntúan las dos asignaciones contra los `oneway` de OSM y se acepta el
 * intercambio solo si mejora el sentido peor de la ruta en al menos
 * `minGainPoints` y deja ese sentido en `minSwappedScore` o más. Es idempotente:
 * sobre un feed ya reparado la asignación actual gana y no se toca nada.
 */
export function decideShapeSwap(
  ida: RouteDirection,
  vuelta: RouteDirection,
  index: OneWayIndex,
  options: {
    minGainPoints?: number;
    minSwappedScore?: number;
  } = {}
): ShapeSideDecision {
  const minGain = options.minGainPoints ?? SHAPE_SIDE_THRESHOLDS.minGainPoints;
  const minSwapped =
    options.minSwappedScore ?? SHAPE_SIDE_THRESHOLDS.minSwappedScore;

  const idaReversed = !shapeFollowsStopOrder(ida.shape, ida.stops);
  const vueltaReversed = !shapeFollowsStopOrder(vuelta.shape, vuelta.stops);
  const base = { idaReversed, vueltaReversed };

  if (
    ida.shape.length < 2 ||
    vuelta.shape.length < 2 ||
    ida.stops.length < 2 ||
    vuelta.stops.length < 2
  ) {
    return {
      status: 'inconclusive',
      reason: 'incomplete',
      current: { ida: null, vuelta: null },
      swapped: { ida: null, vuelta: null },
      ...base,
    };
  }

  const idaScores = shapeScores(index, ida.shape);
  const vueltaScores = shapeScores(index, vuelta.shape);

  const current = {
    ida: tripScore(idaScores, ida.shape, ida.stops).percent,
    vuelta: tripScore(vueltaScores, vuelta.shape, vuelta.stops).percent,
  };
  const swapped = {
    ida: tripScore(vueltaScores, vuelta.shape, ida.stops).percent,
    vuelta: tripScore(idaScores, ida.shape, vuelta.stops).percent,
  };

  if (
    worst(current.ida, current.vuelta) < 0 ||
    worst(swapped.ida, swapped.vuelta) < 0
  ) {
    return {
      status: 'inconclusive',
      reason: 'no-street-samples',
      current,
      swapped,
      ...base,
    };
  }

  const gain =
    worst(swapped.ida, swapped.vuelta) - worst(current.ida, current.vuelta);
  const accept =
    gain >= minGain && worst(swapped.ida, swapped.vuelta) >= minSwapped;
  return { status: accept ? 'swapped' : 'keep', current, swapped, ...base };
}
