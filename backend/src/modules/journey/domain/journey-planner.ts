import {
  BusLeg,
  CandidateStop,
  JourneyOption,
  PlannerInput,
  TripSchedule,
  WalkLeg,
} from './journey.model';

/**
 * Planeador de viaje — lógica PURA (sin I/O, testeable con Jest).
 *
 * Reglas:
 * - Opción directa: un mismo trip sirve una parada cercana al origen ANTES que
 *   una parada cercana al destino (mismo sentido).
 * - Opción con transbordo: trip A lleva del origen a una parada intermedia
 *   común; trip B (distinto) continúa desde ahí hacia el destino.
 * - Horarios calculados desde frequencies: el viaje k repite con offset
 *   k*headway dentro de la ventana [startTime, endTime].
 *
 * La búsqueda usa índices parada→trips para que el costo sea lineal en
 * viajes candidatos, no en el producto de ambos conjuntos.
 */

/** Velocidad de caminata: 80 m/min ≈ 4.8 km/h. */
export const WALK_SPEED_M_PER_MIN = 80;

/**
 * Distancia mínima (línea recta) entre la parada de subir y la de bajar:
 * por debajo de esto el tramo de bus es un absurdo ("bajarse donde se
 * subió") y la opción se descarta. Replica el caso del reporte de usuario:
 * al arrastrar los puntos juntos, el planificador devolvía viajes de una
 * parada a la contigua (~100 m).
 */
export const MIN_BOARDING_PAIR_DISTANCE_M = 150;

/** Distancia en línea recta entre dos puntos (haversine), en metros. */
export function straightLineMeters(
  a: { lat: number; lon: number },
  b: { lat: number; lon: number },
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function walkDurationMinutes(distanceMeters: number): number {
  if (distanceMeters <= 0) return 0;
  return Math.max(1, Math.ceil(distanceMeters / WALK_SPEED_M_PER_MIN));
}

export interface DepartureInstance {
  /** Índice de repetición (k) del viaje dentro de la ventana. */
  k: number;
  /** Hora de salida en segundos desde medianoche. */
  departureSec: number;
}

/**
 * Primera salida de un trip en una parada con hora >= notBeforeSec.
 * El viaje k repite con offset k*headway; debe iniciar dentro de la ventana
 * [startSec, endSec] (k <= floor((end-start)/headway)).
 */
export function nextRunDeparture(
  baseDepSec: number,
  headwaySec: number,
  kMax: number,
  notBeforeSec: number,
): DepartureInstance | null {
  if (headwaySec <= 0) {
    return baseDepSec >= notBeforeSec ? { k: 0, departureSec: baseDepSec } : null;
  }
  const k = Math.max(0, Math.ceil((notBeforeSec - baseDepSec) / headwaySec));
  if (k > kMax) return null;
  return { k, departureSec: baseDepSec + k * headwaySec };
}

function kMaxOf(trip: TripSchedule): number {
  if (trip.headwaySeconds <= 0) return 0;
  return Math.floor((trip.endTimeSec - trip.startTimeSec) / trip.headwaySeconds);
}

interface IndexedStop {
  seq: number;
  arr: number;
  dep: number;
}

interface IndexedTrip {
  trip: TripSchedule;
  kMax: number;
  /** stopId → datos de la parada en el trip */
  index: Map<string, IndexedStop>;
}

function indexTrip(trip: TripSchedule): IndexedTrip {
  const index = new Map<string, IndexedStop>();
  for (const stop of trip.stops) {
    index.set(stop.stopId, {
      seq: stop.sequence,
      arr: stop.arrivalSec,
      dep: stop.departureSec,
    });
  }
  return { trip, kMax: kMaxOf(trip), index };
}

function formatHms(totalSec: number): string {
  const s = Math.max(0, Math.round(totalSec));
  const hh = Math.floor(s / 3600);
  const mm = Math.floor((s % 3600) / 60);
  const ss = s % 60;
  return [hh, mm, ss].map((v) => String(v).padStart(2, '0')).join(':');
}

function minutesBetween(fromSec: number, toSec: number): number {
  return Math.round((toSec - fromSec) / 60);
}

function walkLeg(distanceMeters: number): WalkLeg {
  return {
    kind: 'walk',
    durationMinutes: walkDurationMinutes(distanceMeters),
    distanceMeters: Math.round(distanceMeters),
  };
}

function busLeg(
  trip: TripSchedule,
  fromStopId: string,
  toStopId: string,
  departSec: number,
  arriveSec: number,
  fromSeq: number,
  toSeq: number,
): BusLeg {
  return {
    kind: 'bus',
    routeId: trip.routeId,
    routeShortName: trip.routeShortName,
    routeColor: trip.routeColor,
    tripId: trip.tripId,
    fromStopId,
    toStopId,
    departAt: formatHms(departSec),
    arriveAt: formatHms(arriveSec),
    stops: Math.abs(toSeq - fromSeq) + 1,
  };
}

function stopRef(stop: CandidateStop): JourneyOption['walkToStop'] {
  return {
    id: stop.stopId,
    name: stop.name,
    distanceMeters: Math.round(stop.distanceMeters),
  };
}

/**
 * Penalización por transbordo (en minutos de costo generalizado).
 * En Santa Cruz de la Sierra, un transbordo duplica el costo del pasaje
 * (Bs 2.00-2.50 extra) y añade tiempo de espera incierto en la calle.
 * Por tanto, los viajes directos se prefieren fuertemente salvo que el
 * transbordo suponga un ahorro sustancial de tiempo (>10 min).
 */
export const TRANSFER_PENALTY_MINUTES = 10;

/**
 * Costo generalizado de una opción, en minutos: duración + penalización de
 * transbordo. La POLÍTICA de orden de resultados vive aquí, en domain — la
 * usan el planner interno y el servicio que recibe opciones de OTP, de modo
 * que ambos motores rankean con la MISMA regla (antes la copiaba el adapter
 * OTP y cualquier cambio de scoring tocaba dos lugares).
 */
export function journeyCost(option: JourneyOption): number {
  return (
    option.durationMinutes +
    (option.type === 'transfer' ? TRANSFER_PENALTY_MINUTES : 0)
  );
}

/** Ordena por costo generalizado; empates y desempates determinísticos. */
export function compareJourneyOptions(
  a: JourneyOption,
  b: JourneyOption,
): number {
  const costA = journeyCost(a);
  const costB = journeyCost(b);
  if (costA !== costB) return costA - costB;
  if (a.durationMinutes !== b.durationMinutes) {
    return a.durationMinutes - b.durationMinutes;
  }
  if (a.departAt !== b.departAt) return a.departAt < b.departAt ? -1 : 1;
  // Preferir directo en empate
  if (a.type !== b.type) return a.type === 'direct' ? -1 : 1;
  return 0;
}

/**
 * Ordena por la política común ([compareJourneyOptions]) y recorta a
 * [maxResults]: la llamada de top de resultados también es política, no un
 * detalle del adapter.
 */
export function rankAndCut(
  options: JourneyOption[],
  maxResults: number,
): JourneyOption[] {
  return [...options].sort(compareJourneyOptions).slice(0, maxResults);
}

/** Planea viajes directos y con 1 transbordo, ordenados por duración y costo generalizado. */
export function planJourneys(input: PlannerInput): JourneyOption[] {
  const { originStops, destStops, trips, timeSec, maxResults } = input;
  if (originStops.length === 0 || destStops.length === 0) return [];

  const originById = new Map(originStops.map((s) => [s.stopId, s]));
  const destById = new Map(destStops.map((s) => [s.stopId, s]));

  const indexedTrips = trips.map(indexTrip);

  // Índices parada → viajes que la sirven
  // - origin: solo sobre paradas candidatas del origen
  // - destServingByStop: sobre TODAS las paradas, pero solo de viajes que
  //   sirven al menos una parada candidata del destino (candidatos a 2do tramo)
  const originTripsByStop = new Map<string, IndexedTrip[]>();
  const destServingByStop = new Map<string, IndexedTrip[]>();
  const destServingTrips = new Set<string>();
  for (const it of indexedTrips) {
    for (const stopId of it.index.keys()) {
      if (originById.has(stopId)) {
        push(originTripsByStop, stopId, it);
      }
      for (const destStopId of destById.keys()) {
        if (it.index.has(destStopId)) {
          destServingTrips.add(it.trip.tripId);
          break;
        }
      }
    }
  }
  for (const it of indexedTrips) {
    if (!destServingTrips.has(it.trip.tripId)) continue;
    for (const stopId of it.index.keys()) {
      push(destServingByStop, stopId, it);
    }
  }

  // Mejor opción por clave (evita duplicados casi idénticos y da variedad)
  const bestByKey = new Map<string, JourneyOption>();

  // ---- DIRECTOS ----
  for (const [stopId, originStop] of originById) {
    for (const a of originTripsByStop.get(stopId) ?? []) {
      const o = a.index.get(stopId);
      if (!o) continue;
      const walkToMin = walkDurationMinutes(originStop.distanceMeters);
      const depA = nextRunDeparture(o.dep, a.trip.headwaySeconds, a.kMax, timeSec + walkToMin * 60);
      if (!depA) continue;

      for (const [destStopId, destStop] of destById) {
        const d = a.index.get(destStopId);
        if (!d || d.seq <= o.seq) continue;
        if (straightLineMeters(originStop, destStop) < MIN_BOARDING_PAIR_DISTANCE_M) {
          continue;
        }
        const walkFromMin = walkDurationMinutes(destStop.distanceMeters);
        const arriveBusSec = d.arr + depA.k * a.trip.headwaySeconds;
        const arriveAtSec = arriveBusSec + walkFromMin * 60;
        if (arriveAtSec <= depA.departureSec) continue;

        const option: JourneyOption = {
          type: 'direct',
          departAt: formatHms(depA.departureSec),
          arriveAt: formatHms(arriveAtSec),
          durationMinutes: minutesBetween(depA.departureSec, arriveAtSec),
          walkToStop: stopRef(originStop),
          walkFromStop: stopRef(destStop),
          legs: [
            walkLeg(originStop.distanceMeters),
            busLeg(a.trip, stopId, destStopId, depA.departureSec, arriveBusSec, o.seq, d.seq),
            walkLeg(destStop.distanceMeters),
          ],
        };
        keepBest(bestByKey, `direct:${a.trip.tripId}:${stopId}:${destStopId}`, option);
      }
    }
  }

  // ---- TRANSBORDOS (1) ----
  for (const [stopId, originStop] of originById) {
    for (const a of originTripsByStop.get(stopId) ?? []) {
      const o = a.index.get(stopId);
      if (!o) continue;
      const walkToMin = walkDurationMinutes(originStop.distanceMeters);
      const depA = nextRunDeparture(o.dep, a.trip.headwaySeconds, a.kMax, timeSec + walkToMin * 60);
      if (!depA) continue;

      // Para cada parada intermedia alcanzable por A, qué viajes B siguen desde ahí
      for (const transfer of a.trip.stops) {
        const x = a.index.get(transfer.stopId);
        if (!x || x.seq <= o.seq) continue;
        const arrXSec = x.arr + depA.k * a.trip.headwaySeconds;

        for (const b of destServingByStop.get(transfer.stopId) ?? []) {
          if (b.trip.tripId === a.trip.tripId) continue;
          const xb = b.index.get(transfer.stopId);
          if (!xb) continue;
          const depB = nextRunDeparture(xb.dep, b.trip.headwaySeconds, b.kMax, arrXSec);
          if (!depB) continue;

          for (const [destStopId, destStop] of destById) {
            const d = b.index.get(destStopId);
            if (!d || d.seq <= xb.seq) continue;
            if (straightLineMeters(originStop, destStop) < MIN_BOARDING_PAIR_DISTANCE_M) {
              continue;
            }
            const walkFromMin = walkDurationMinutes(destStop.distanceMeters);
            const arriveBusSec = d.arr + depB.k * b.trip.headwaySeconds;
            const arriveAtSec = arriveBusSec + walkFromMin * 60;
            if (arriveAtSec <= depA.departureSec) continue;

            const option: JourneyOption = {
              type: 'transfer',
              departAt: formatHms(depA.departureSec),
              arriveAt: formatHms(arriveAtSec),
              durationMinutes: minutesBetween(depA.departureSec, arriveAtSec),
              walkToStop: stopRef(originStop),
              walkFromStop: stopRef(destStop),
              legs: [
                walkLeg(originStop.distanceMeters),
                busLeg(a.trip, stopId, transfer.stopId, depA.departureSec, arrXSec, o.seq, x.seq),
                busLeg(
                  b.trip,
                  transfer.stopId,
                  destStopId,
                  depB.departureSec,
                  arriveBusSec,
                  xb.seq,
                  d.seq,
                ),
                walkLeg(destStop.distanceMeters),
              ],
            };
            keepBest(
              bestByKey,
              `transfer:${a.trip.tripId}:${b.trip.tripId}:${stopId}:${destStopId}`,
              option,
            );
          }
        }
      }
    }
  }

  return rankAndCut([...bestByKey.values()], maxResults);
}

function push(map: Map<string, IndexedTrip[]>, key: string, value: IndexedTrip): void {
  const list = map.get(key);
  if (list) {
    list.push(value);
  } else {
    map.set(key, [value]);
  }
}

function keepBest(map: Map<string, JourneyOption>, key: string, option: JourneyOption): void {
  const existing = map.get(key);
  if (!existing || option.durationMinutes < existing.durationMinutes) {
    map.set(key, option);
  }
}
