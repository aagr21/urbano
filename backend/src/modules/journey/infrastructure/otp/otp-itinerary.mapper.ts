import {
  BusLeg,
  JourneyOption,
  LineGeometry,
  StopRef,
  WalkLeg,
} from '../../domain/journey.model';
import { walkDurationMinutes } from '../../domain/journey-planner';
import { decodePolylineToGeoJSON } from './decode-polyline';

/**
 * Traducción PURA de la respuesta de OTP2 al modelo de dominio (sin HTTP ni
 * Nest): tipos mínimos del GraphQL, horas en `America/La_Paz` y el mapeo de
 * itinerarios. El adaptador [OtpJourneyRouter] solo hace la llamada.
 */

/** Zona horaria del feed (toda la app opera en ella). */
const TZ = 'America/La_Paz';
/** Bolivia no aplica horario de verano: offset fijo UTC-4. */
const TZ_OFFSET = '-04:00';

/* ---- Tipos mínimos de la respuesta GraphQL de OTP2 (GTFS GraphQL API). ---- */

interface OtpStopRef {
  gtfsId?: string | null;
}

interface OtpPlace {
  name?: string | null;
  lat?: number | null;
  lon?: number | null;
  stop?: OtpStopRef | null;
}

export interface OtpRoute {
  gtfsId?: string | null;
  shortName?: string | null;
  longName?: string | null;
  color?: string | null;
}

export interface OtpLeg {
  mode?: string | null;
  /** Epoch millis (respuestas nuevas) o ISO string (respuestas viejas). */
  startTime?: number | string | null;
  endTime?: number | string | null;
  distance?: number | null;
  intermediateStops?: OtpPlace[] | null;
  route?: OtpRoute | null;
  trip?: OtpStopRef | null;
  from?: OtpPlace | null;
  to?: OtpPlace | null;
  legGeometry?: { points?: string | null } | null;
}

/** Itinerario crudo de OTP2 (forma importable para specs). */
export interface OtpItinerary {
  start?: string | null;
  end?: string | null;
  legs?: OtpLeg[] | null;
}

/** Quita el prefijo de feed de un gtfsId de OTP ("FEED:ID" → "ID"). */
export function stripFeedId(gtfsId: string | null | undefined): string {
  if (!gtfsId) return '';
  const idx = gtfsId.indexOf(':');
  return idx >= 0 ? gtfsId.slice(idx + 1) : gtfsId;
}

/** Normaliza el color de OTP a hex sin `#` (convención GTFS del contrato). */
export function normalizeColor(
  color: string | null | undefined
): string | null {
  if (!color) return null;
  return color.replace(/^#/, '') || null;
}

/** Epoch millis o ISO string → "HH:mm:ss" en America/La_Paz. */
export function formatHmsInTz(
  time: number | string | null | undefined
): string {
  if (time == null || time === '') return '00:00:00';
  const date = typeof time === 'number' ? new Date(time) : new Date(time);
  if (Number.isNaN(date.getTime())) return '00:00:00';
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const get = (type: string): string =>
    parts.find((p) => p.type === type)?.value ?? '00';
  return `${get('hour')}:${get('minute')}:${get('second')}`;
}

/**
 * Fecha de hoy en America/La_Paz (YYYY-MM-DD) combinada con una hora en
 * segundos desde medianoche → ISO 8601 con offset (Bolivia: UTC-4 fijo).
 */
export function laPazIsoFromTimeSec(
  timeSec: number,
  today = new Date()
): string {
  const ymd = new Intl.DateTimeFormat('en-CA', {
    timeZone: TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(today);
  const s = Math.max(0, Math.round(timeSec));
  const hh = String(Math.floor(s / 3600) % 24).padStart(2, '0');
  const mm = String(Math.floor((s % 3600) / 60)).padStart(2, '0');
  const ss = String(s % 60).padStart(2, '0');
  return `${ymd}T${hh}:${mm}:${ss}${TZ_OFFSET}`;
}

/** Mapea un itinerario OTP al modelo de dominio (null si no sirve). */
export function mapItinerary(node: OtpItinerary): JourneyOption | null {
  const rawLegs = node.legs ?? [];
  const busCount = rawLegs.filter((l) => isTransit(l)).length;
  // Sin tramo de transporte no hay "opción de viaje" que ofrecer (y el
  // contrato modela direct = 1 micro, transfer = 2+).
  if (busCount === 0) return null;

  const legs = rawLegs
    .map((leg) => (isTransit(leg) ? mapBusLeg(leg) : mapWalkLeg(leg)))
    .filter((leg): leg is BusLeg | WalkLeg => leg !== null);
  if (legs.length === 0) return null;

  const busLegs = legs.filter((l): l is BusLeg => l.kind === 'bus');
  const firstBus = busLegs[0];
  const lastBus = busLegs[busLegs.length - 1];
  if (!firstBus?.fromStop || !lastBus?.toStop) return null;

  // Caminata de acceso = suma de las caminatas previas al primer micro.
  const walkToMeters = sumWalkBefore(rawLegs);
  const walkFromMeters = sumWalkAfter(rawLegs);

  return {
    type: busCount === 1 ? 'direct' : 'transfer',
    departAt: formatHmsInTz(node.start),
    arriveAt: formatHmsInTz(node.end),
    durationMinutes: minutesBetweenIso(node.start, node.end),
    walkToStop: {
      id: firstBus.fromStop.id,
      name: firstBus.fromStop.name,
      distanceMeters: walkToMeters,
      lat: firstBus.fromStop.lat,
      lon: firstBus.fromStop.lon,
    },
    walkFromStop: {
      id: lastBus.toStop.id,
      name: lastBus.toStop.name,
      distanceMeters: walkFromMeters,
      lat: lastBus.toStop.lat,
      lon: lastBus.toStop.lon,
    },
    legs,
  };
}

function isTransit(leg: OtpLeg): boolean {
  return !!leg.mode && leg.mode !== 'WALK';
}

/** Caminata: geometría por la red viaria + métricas con la fórmula legacy. */
function mapWalkLeg(leg: OtpLeg): WalkLeg | null {
  const distance = Math.max(0, Math.round(leg.distance ?? 0));
  return {
    kind: 'walk',
    durationMinutes: walkDurationMinutes(distance),
    distanceMeters: distance,
    geometry: mapGeometry(leg.legGeometry?.points),
    // Paradas extremas cuando las comunica OTP (caminatas de transbordo):
    // sirven para degradar a línea recta por tramos en el cliente.
    fromStop: mapStopRef(leg.from),
    toStop: mapStopRef(leg.to),
  };
}

/** Micro: metadatos de ruta/trip + geometría del tramo + paradas extremas. */
function mapBusLeg(leg: OtpLeg): BusLeg | null {
  const fromStop = mapStopRef(leg.from);
  const toStop = mapStopRef(leg.to);
  if (!fromStop || !toStop) return null;

  return {
    kind: 'bus',
    routeId: stripFeedId(leg.route?.gtfsId),
    routeShortName: leg.route?.shortName || leg.route?.longName || '',
    routeColor: normalizeColor(leg.route?.color),
    tripId: stripFeedId(leg.trip?.gtfsId),
    fromStopId: fromStop.id,
    toStopId: toStop.id,
    departAt: formatHmsInTz(leg.startTime),
    arriveAt: formatHmsInTz(leg.endTime),
    stops: (leg.intermediateStops?.length ?? 0) + 2,
    geometry: mapGeometry(leg.legGeometry?.points),
    fromStop,
    toStop,
  };
}

function mapStopRef(place: OtpPlace | null | undefined): StopRef | null {
  const id = stripFeedId(place?.stop?.gtfsId);
  if (!id || place?.lat == null || place?.lon == null) return null;
  return { id, name: place.name ?? '', lat: place.lat, lon: place.lon };
}

function mapGeometry(points: string | null | undefined): LineGeometry | null {
  if (!points) return null;
  try {
    const coordinates = decodePolylineToGeoJSON(points);
    return coordinates.length >= 2 ? { type: 'LineString', coordinates } : null;
  } catch {
    return null;
  }
}

function sumWalkBefore(rawLegs: OtpLeg[]): number {
  let total = 0;
  for (const leg of rawLegs) {
    if (isTransit(leg)) break;
    total += leg.distance ?? 0;
  }
  return Math.round(total);
}

function sumWalkAfter(rawLegs: OtpLeg[]): number {
  // Caminatas posteriores al ÚLTIMO tramo de transporte.
  let lastTransitIdx = -1;
  rawLegs.forEach((leg, i) => {
    if (isTransit(leg)) lastTransitIdx = i;
  });
  const total = rawLegs
    .slice(lastTransitIdx + 1)
    .reduce((acc, leg) => acc + (leg.distance ?? 0), 0);
  return Math.round(total);
}

function minutesBetweenIso(
  startIso: string | null | undefined,
  endIso: string | null | undefined
): number {
  if (!startIso || !endIso) return 0;
  const start = Date.parse(startIso);
  const end = Date.parse(endIso);
  if (Number.isNaN(start) || Number.isNaN(end)) return 0;
  return Math.round((end - start) / 60_000);
}
