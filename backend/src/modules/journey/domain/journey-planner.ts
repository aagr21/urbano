import {
  BusLeg,
  CandidateStop,
  JourneyOption,
  PlannerInput,
  TripSchedule,
  WalkLeg,
} from './journey.model';
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

/** Distancia en línea recta entre dos puntos (haversine), en metros. */
export function straightLineMeters(
  a: { lat: number; lon: number },
  b: { lat: number; lon: number }
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

/**
 * Margen (m) para no invertir geometrías simétricas (rutas circulares o
 * paradas de subida/bajada muy próximas).
 */
const GEOMETRY_ORIENTATION_MARGIN_M = 1;

/**
 * Garantiza que la geometría de cada tramo de micro siga el sentido REAL del
 * viaje: de `fromStop` (subida) a `toStop` (bajada).
 *
 * La comprobación es LOCAL al tramo (nunca contra el origen/destino del
 * usuario): un recorrido puede girar 90° o ir en contra del rumbo general y
 * seguir siendo correcto. Solo se invierte la lista de coordenadas si el
 * primer punto está claramente más cerca de la bajada que de la subida; las
 * paradas, los horarios y los ids NO se tocan.
 */
export function orientBusLegGeometry(
  options: JourneyOption[]
): JourneyOption[] {
  for (const option of options) {
    for (const leg of option.legs) {
      if (leg.kind !== 'bus') continue;
      const coordinates = leg.geometry?.coordinates;
      if (!coordinates || coordinates.length < 2) continue;
      const from = leg.fromStop;
      const to = leg.toStop;
      if (!from || !to) continue;

      const first = coordinates[0];
      const last = coordinates[coordinates.length - 1];
      if (!isLonLat(first) || !isLonLat(last)) continue;

      const forward =
        straightLineMeters({ lat: first[1], lon: first[0] }, from) +
        straightLineMeters({ lat: last[1], lon: last[0] }, to);
      const backward =
        straightLineMeters({ lat: first[1], lon: first[0] }, to) +
        straightLineMeters({ lat: last[1], lon: last[0] }, from);

      if (backward + GEOMETRY_ORIENTATION_MARGIN_M < forward) {
        leg.geometry = {
          type: 'LineString',
          coordinates: [...coordinates].reverse(),
        };
      }
    }
  }
  return options;
}

function isLonLat(value: number[] | undefined): value is [number, number] {
  return (
    !!value &&
    value.length >= 2 &&
    Number.isFinite(value[0]) &&
    Number.isFinite(value[1])
  );
}

/**
 * Distancia máxima (m) entre una parada y el trazado del micro para coserlos.
 * En una avenida de doble calzada el `shape` corre por el eje del carril y la
 * parada está en la acera, así que el desfase real ronda 10-25 m.
 */
export const STOP_SNAP_MAX_METERS = 60;

/**
 * Cierra el hueco entre la caminata y el micro en el mapa.
 *
 * El `shape` de GTFS circula por el eje de la calzada y la parada está en la
 * acera: en avenidas de doble calzada el `shape` pasa 10-20 m al otro lado de
 * la parada, así que la caminata terminaba en la acera y el micro se dibujaba
 * en la calzada de enfrente. En pantalla se lee como "me hace cruzar para
 * tomar el micro" o "la caminata no llega hasta donde pasa el micro".
 *
 * El `shape` es la verdad de por dónde pasa el micro (ya viene reparado por
 * calzada en el feed), así que **no se mueve**: lo que se estira es la
 * caminata, que termina (o empieza) exactamente en el primer/último punto del
 * trazado del micro vecino. Las paradas, horarios e ids no se tocan.
 *
 * Solo se cose cuando el extremo de la caminata está a menos de
 * [STOP_SNAP_MAX_METERS] del trazado: si el micro pasa lejos, el hueco es real
 * y no se inventa un salto.
 */
export function connectWalkAndBusGeometry(
  options: JourneyOption[]
): JourneyOption[] {
  for (const option of options) {
    for (let i = 0; i < option.legs.length; i++) {
      const leg = option.legs[i];
      if (leg.kind !== 'walk') continue;
      const coordinates = leg.geometry?.coordinates;
      if (!coordinates || coordinates.length === 0) continue;

      const after = option.legs[i + 1];
      const before = option.legs[i - 1];
      const afterStart =
        after?.kind === 'bus' ? after.geometry?.coordinates[0] : undefined;
      const beforeCoords =
        before?.kind === 'bus' ? before.geometry?.coordinates : undefined;
      const beforeEnd =
        beforeCoords && beforeCoords.length > 0
          ? beforeCoords[beforeCoords.length - 1]
          : undefined;
      if (!isLonLat(afterStart) && !isLonLat(beforeEnd)) continue;

      const next = coordinates.map((point) => [point[0], point[1]]);
      const lastIndex = next.length - 1;
      const end = next[lastIndex];
      const start = next[0];

      if (
        isLonLat(afterStart) &&
        isLonLat(end) &&
        straightLineMeters(
          { lat: end[1], lon: end[0] },
          {
            lat: afterStart[1],
            lon: afterStart[0],
          }
        ) <= STOP_SNAP_MAX_METERS
      ) {
        next[lastIndex] = [afterStart[0], afterStart[1]];
      }
      if (
        isLonLat(beforeEnd) &&
        isLonLat(start) &&
        straightLineMeters(
          { lat: start[1], lon: start[0] },
          {
            lat: beforeEnd[1],
            lon: beforeEnd[0],
          }
        ) <= STOP_SNAP_MAX_METERS
      ) {
        next[0] = [beforeEnd[0], beforeEnd[1]];
      }
      leg.geometry = { type: 'LineString', coordinates: next };
    }
  }
  return options;
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

/**
 * Penalización por transbordo (en minutos de costo generalizado).
 * El VALOR vive en journey-limits (contrato de `GET /meta`); el razonamiento
 * de negocio: en Santa Cruz el transbordo duplica el costo del pasaje
 * (Bs 2.00-2.50 extra) y añade tiempo de espera incierto en la calle, por
 * tanto los directos se prefieren salvo que el transbordo ahorre sustancial.
 */

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
  b: JourneyOption
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
  maxResults: number
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

/** Metros totales a pie de una opción (acceso + transbordos + egreso). */
export function totalWalkMeters(option: JourneyOption): number {
  return option.legs.reduce(
    (acc, leg) => acc + (leg.kind === 'walk' ? leg.distanceMeters : 0),
    0
  );
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

/**
 * Metros que recorre un tramo de micro YA enriquecido: largo de su
 * `geometry` (shape recortado / polyline de OTP) o, sin ella, la recta entre
 * sus paradas. `null` si no hay con qué medir.
 */
export function busLegRideMeters(leg: BusLeg): number | null {
  const coords = leg.geometry?.coordinates;
  if (coords && coords.length >= 2) {
    let total = 0;
    for (let i = 1; i < coords.length; i++) {
      const p = coords[i - 1];
      const q = coords[i];
      if (!isLonLat(p) || !isLonLat(q)) continue;
      total += straightLineMeters(
        { lat: p[1], lon: p[0] },
        { lat: q[1], lon: q[0] }
      );
    }
    return total;
  }
  if (leg.fromStop && leg.toStop) {
    return straightLineMeters(leg.fromStop, leg.toStop);
  }
  return null;
}

/**
 * Descarta las opciones con transbordo cuyo PRIMER micro recorre menos de
 * [MIN_FIRST_RIDE_TRANSFER_M]. Es la regla para cualquier motor (OTP y el
 * planner interno, que además ya la aplica durante la búsqueda para no gastar
 * cupos de resultado en ellas). Si el tramo no se puede medir, se conserva.
 */
export function dropShortFirstRideTransfers(
  options: JourneyOption[]
): JourneyOption[] {
  return options.filter((option) => {
    if (option.type !== 'transfer') return true;
    const firstBus = option.legs.find(
      (leg): leg is BusLeg => leg.kind === 'bus'
    );
    if (!firstBus) return true;
    const ride = busLegRideMeters(firstBus);
    return ride === null || ride >= MIN_FIRST_RIDE_TRANSFER_M;
  });
}
