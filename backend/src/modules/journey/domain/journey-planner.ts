import {
  BusLeg,
  CandidateStop,
  JourneyOption,
  PlannerInput,
  TripSchedule,
  WalkLeg,
} from './journey.model';
import { straightLineMeters } from './geo';
import { rankAndCut, totalWalkMeters } from './journey-ranking';
import {
  JOURNEY_LIMITS,
  MIN_BOARDING_PAIR_DISTANCE_M,
  MIN_FIRST_RIDE_TRANSFER_M,
  WALK_SPEED_M_PER_MIN,
  TRANSFER_PENALTY_MINUTES,
} from './journey-limits';

/**
 * Re-export: los invariantes viven en [journey-limits] (contrato expuesto
 * por `GET /meta`); quedan visibles aquí por la herencia de imports.
 */
export {
  JOURNEY_LIMITS,
  MIN_BOARDING_PAIR_DISTANCE_M,
  MIN_FIRST_RIDE_TRANSFER_M,
  WALK_SPEED_M_PER_MIN,
  TRANSFER_PENALTY_MINUTES,
};

/**
 * Re-export: geodesia, geometría y ranking viven en sus propios módulos; se
 * siguen ofreciendo desde aquí para no romper a quien los importaba.
 */
export { isLonLat, straightLineMeters } from './geo';
export {
  STOP_SNAP_MAX_METERS,
  connectWalkAndBusGeometry,
  orientBusLegGeometry,
} from './journey-geometry';
export {
  busLegRideMeters,
  compareJourneyOptions,
  dropShortFirstRideTransfers,
  journeyCost,
  rankAndCut,
  totalWalkMeters,
} from './journey-ranking';

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
 * - `departAt`/`durationMinutes` son PUERTA A PUERTA (como OTP): la salida es
 *   el momento de dejar el origen para llegar justo al micro, de modo que la
 *   caminata de acceso cuenta en la duración. Si no contara, bajarse a pie
 *   hasta una parada más adelantada de la MISMA línea "acortaba" el viaje y
 *   el usuario caminaba un tramo que el micro ya cubría.
 * - Una opción por trip (directo) o par de trips (transbordo): de todas las
 *   combinaciones de paradas se queda la de menor duración y, a igualdad, la
 *   que menos hace caminar.
 * - Con transbordo, el primer micro debe recorrer al menos
 *   [MIN_FIRST_RIDE_TRANSFER_M] (medido por las paradas del trip).
 *
 * La búsqueda usa índices parada→trips para que el costo sea lineal en
 * viajes candidatos, no en el producto de ambos conjuntos.
 */

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
  notBeforeSec: number
): DepartureInstance | null {
  if (headwaySec <= 0) {
    return baseDepSec >= notBeforeSec
      ? { k: 0, departureSec: baseDepSec }
      : null;
  }
  const k = Math.max(0, Math.ceil((notBeforeSec - baseDepSec) / headwaySec));
  if (k > kMax) return null;
  return { k, departureSec: baseDepSec + k * headwaySec };
}

function kMaxOf(trip: TripSchedule): number {
  if (trip.headwaySeconds <= 0) return 0;
  return Math.floor(
    (trip.endTimeSec - trip.startTimeSec) / trip.headwaySeconds
  );
}

interface IndexedStop {
  seq: number;
  arr: number;
  dep: number;
  /** Metros recorridos por el trip desde su primera parada (null sin coordenadas). */
  along: number | null;
}

interface IndexedTrip {
  trip: TripSchedule;
  kMax: number;
  /** stopId → datos de la parada en el trip */
  index: Map<string, IndexedStop>;
}

function indexTrip(trip: TripSchedule): IndexedTrip {
  const index = new Map<string, IndexedStop>();
  // Distancia acumulada parada a parada: aproxima lo que recorre el micro
  // sin necesitar el shape (el planeador es puro). Si falta una coordenada,
  // la distancia queda desconocida desde ahí y no se filtra por ella.
  let along: number | null = 0;
  let prev: { lat: number; lon: number } | null = null;
  for (const stop of trip.stops) {
    const here =
      stop.lat != null && stop.lon != null
        ? { lat: stop.lat, lon: stop.lon }
        : null;
    if (along !== null) {
      if (!here) along = null;
      else if (prev) along += straightLineMeters(prev, here);
    }
    prev = here;
    index.set(stop.stopId, {
      seq: stop.sequence,
      arr: stop.arrivalSec,
      dep: stop.departureSec,
      along,
    });
  }
  return { trip, kMax: kMaxOf(trip), index };
}

/**
 * Metros que recorre el micro entre dos paradas del mismo trip, o `null` si
 * no se conocen las coordenadas.
 */
function rideMeters(from: IndexedStop, to: IndexedStop): number | null {
  if (from.along === null || to.along === null) return null;
  return Math.max(0, to.along - from.along);
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
  toSeq: number
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
      const depA = nextRunDeparture(
        o.dep,
        a.trip.headwaySeconds,
        a.kMax,
        timeSec + walkToMin * 60
      );
      if (!depA) continue;

      for (const [destStopId, destStop] of destById) {
        const d = a.index.get(destStopId);
        if (!d || d.seq <= o.seq) continue;
        if (
          straightLineMeters(originStop, destStop) <
          MIN_BOARDING_PAIR_DISTANCE_M
        ) {
          continue;
        }
        const walkFromMin = walkDurationMinutes(destStop.distanceMeters);
        const arriveBusSec = d.arr + depA.k * a.trip.headwaySeconds;
        const arriveAtSec = arriveBusSec + walkFromMin * 60;
        if (arriveAtSec <= depA.departureSec) continue;

        // Puerta a puerta: se sale del origen justo para llegar al micro.
        const leaveSec = depA.departureSec - walkToMin * 60;
        const option: JourneyOption = {
          type: 'direct',
          departAt: formatHms(leaveSec),
          arriveAt: formatHms(arriveAtSec),
          durationMinutes: minutesBetween(leaveSec, arriveAtSec),
          walkToStop: stopRef(originStop),
          walkFromStop: stopRef(destStop),
          legs: [
            walkLeg(originStop.distanceMeters),
            busLeg(
              a.trip,
              stopId,
              destStopId,
              depA.departureSec,
              arriveBusSec,
              o.seq,
              d.seq
            ),
            walkLeg(destStop.distanceMeters),
          ],
        };
        // Clave por trip (no por par de paradas): de todas las paradas de
        // subida/bajada del mismo micro gana la de menor duración puerta a
        // puerta y, a igualdad, la que menos camina. Antes cada par era una
        // opción distinta y la que hacía caminar de más competía (y ganaba
        // en el cliente, que se quedaba con la de salida más temprana).
        keepBest(bestByKey, `direct:${a.trip.tripId}`, option);
      }
    }
  }

  // ---- TRANSBORDOS (1) ----
  for (const [stopId, originStop] of originById) {
    for (const a of originTripsByStop.get(stopId) ?? []) {
      const o = a.index.get(stopId);
      if (!o) continue;
      const walkToMin = walkDurationMinutes(originStop.distanceMeters);
      const depA = nextRunDeparture(
        o.dep,
        a.trip.headwaySeconds,
        a.kMax,
        timeSec + walkToMin * 60
      );
      if (!depA) continue;

      // Para cada parada intermedia alcanzable por A, qué viajes B siguen desde ahí
      for (const transfer of a.trip.stops) {
        const x = a.index.get(transfer.stopId);
        if (!x || x.seq <= o.seq) continue;
        // Primer micro demasiado corto: subir para bajarse a ~200 m y tomar
        // otro no es un viaje razonable (se camina y se ahorra un pasaje).
        const firstRide = rideMeters(o, x);
        if (firstRide !== null && firstRide < MIN_FIRST_RIDE_TRANSFER_M) {
          continue;
        }
        const arrXSec = x.arr + depA.k * a.trip.headwaySeconds;

        for (const b of destServingByStop.get(transfer.stopId) ?? []) {
          if (b.trip.tripId === a.trip.tripId) continue;
          const xb = b.index.get(transfer.stopId);
          if (!xb) continue;
          const depB = nextRunDeparture(
            xb.dep,
            b.trip.headwaySeconds,
            b.kMax,
            arrXSec
          );
          if (!depB) continue;

          for (const [destStopId, destStop] of destById) {
            const d = b.index.get(destStopId);
            if (!d || d.seq <= xb.seq) continue;
            if (
              straightLineMeters(originStop, destStop) <
              MIN_BOARDING_PAIR_DISTANCE_M
            ) {
              continue;
            }
            const walkFromMin = walkDurationMinutes(destStop.distanceMeters);
            const arriveBusSec = d.arr + depB.k * b.trip.headwaySeconds;
            const arriveAtSec = arriveBusSec + walkFromMin * 60;
            if (arriveAtSec <= depA.departureSec) continue;

            const leaveSec = depA.departureSec - walkToMin * 60;
            const option: JourneyOption = {
              type: 'transfer',
              departAt: formatHms(leaveSec),
              arriveAt: formatHms(arriveAtSec),
              durationMinutes: minutesBetween(leaveSec, arriveAtSec),
              walkToStop: stopRef(originStop),
              walkFromStop: stopRef(destStop),
              legs: [
                walkLeg(originStop.distanceMeters),
                busLeg(
                  a.trip,
                  stopId,
                  transfer.stopId,
                  depA.departureSec,
                  arrXSec,
                  o.seq,
                  x.seq
                ),
                busLeg(
                  b.trip,
                  transfer.stopId,
                  destStopId,
                  depB.departureSec,
                  arriveBusSec,
                  xb.seq,
                  d.seq
                ),
                walkLeg(destStop.distanceMeters),
              ],
            };
            keepBest(
              bestByKey,
              `transfer:${a.trip.tripId}:${b.trip.tripId}`,
              option
            );
          }
        }
      }
    }
  }

  return rankAndCut([...bestByKey.values()], maxResults);
}

function push(
  map: Map<string, IndexedTrip[]>,
  key: string,
  value: IndexedTrip
): void {
  const list = map.get(key);
  if (list) {
    list.push(value);
  } else {
    map.set(key, [value]);
  }
}

function keepBest(
  map: Map<string, JourneyOption>,
  key: string,
  option: JourneyOption
): void {
  const existing = map.get(key);
  if (!existing || isBetterVariant(option, existing)) {
    map.set(key, option);
  }
}

/**
 * Entre dos variantes del MISMO micro (o par de micros): menor duración
 * puerta a puerta; a igualdad, menos caminata; después, la que llega antes.
 */
function isBetterVariant(a: JourneyOption, b: JourneyOption): boolean {
  if (a.durationMinutes !== b.durationMinutes) {
    return a.durationMinutes < b.durationMinutes;
  }
  const walkA = totalWalkMeters(a);
  const walkB = totalWalkMeters(b);
  if (walkA !== walkB) return walkA < walkB;
  return a.arriveAt < b.arriveAt;
}
