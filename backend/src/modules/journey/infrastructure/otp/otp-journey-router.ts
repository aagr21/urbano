import { Injectable, Logger } from '@nestjs/common';
import { AppConfigService } from '../../../../core/config/app-config.service';
import {
  BusLeg,
  JourneyOption,
  LineGeometry,
  StopRef,
  WalkLeg,
} from '../../domain/journey.model';
import {
  JourneyRouterPort,
  JourneyRouterQuery,
} from '../../domain/journey-router.port';
import {
  TRANSFER_PENALTY_MINUTES,
  walkDurationMinutes,
} from '../../domain/journey-planner';
import { decodePolylineToGeoJSON } from './decode-polyline';

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

interface OtpGraphQlResponse {
  data?: {
    planConnection?: {
      edges?: { node?: OtpItinerary | null }[] | null;
    } | null;
  } | null;
  errors?: { message?: string }[] | null;
}

const PLAN_QUERY = `
query Plan($from: PlanLabeledLocationInput!, $to: PlanLabeledLocationInput!, $dateTime: PlanDateTimeInput, $first: Int!) {
  planConnection(
    origin: $from
    destination: $to
    dateTime: $dateTime
    first: $first
    modes: { direct: [WALK], transit: { transit: [{ mode: BUS }] } }
  ) {
    edges {
      node {
        start
        end
        legs {
          mode
          startTime
          endTime
          distance
          intermediateStops { gtfsId }
          legGeometry { points }
          from { name lat lon stop { gtfsId } }
          to { name lat lon stop { gtfsId } }
          route { gtfsId shortName longName color }
          trip { gtfsId }
        }
      }
    }
  }
}`;

/** Quita el prefijo de feed de un gtfsId de OTP ("FEED:ID" → "ID"). */
export function stripFeedId(gtfsId: string | null | undefined): string {
  if (!gtfsId) return '';
  const idx = gtfsId.indexOf(':');
  return idx >= 0 ? gtfsId.slice(idx + 1) : gtfsId;
}

/** Normaliza el color de OTP a hex sin `#` (convención GTFS del contrato). */
export function normalizeColor(color: string | null | undefined): string | null {
  if (!color) return null;
  return color.replace(/^#/, '') || null;
}

/** Epoch millis o ISO string → "HH:mm:ss" en America/La_Paz. */
export function formatHmsInTz(time: number | string | null | undefined): string {
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
export function laPazIsoFromTimeSec(timeSec: number, today = new Date()): string {
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

/**
 * Adaptador del motor OpenTripPlanner 2 (GTFS + OSM): resuelve itinerarios
 * puerta a puerta con las caminatas trazadas por la red viaria y los mapea
 * al modelo de dominio. Cualquier fallo (red, timeout, respuesta inválida)
 * devuelve `null` para que el servicio degrade al planner interno.
 */
@Injectable()
export class OtpJourneyRouter implements JourneyRouterPort {
  private readonly logger = new Logger(OtpJourneyRouter.name);

  constructor(private readonly config: AppConfigService) {}

  async plan(query: JourneyRouterQuery): Promise<JourneyOption[] | null> {
    const base = this.config.otpUrl;
    if (!base) return null;

    const body = {
      query: PLAN_QUERY,
      variables: {
        from: {
          location: { coordinate: { latitude: query.originLat, longitude: query.originLon } },
        },
        to: {
          location: { coordinate: { latitude: query.destLat, longitude: query.destLon } },
        },
        dateTime: { earliestDeparture: laPazIsoFromTimeSec(query.timeSec) },
        first: query.maxResults,
      },
    };

    let json: OtpGraphQlResponse;
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), this.config.otpTimeoutMs);
      try {
        const res = await fetch(`${base.replace(/\/$/, '')}/index/graphql`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
          signal: controller.signal,
        });
        if (!res.ok) {
          this.logger.warn(`OTP respondió HTTP ${res.status}; uso el planner interno`);
          return null;
        }
        json = (await res.json()) as OtpGraphQlResponse;
      } finally {
        clearTimeout(timer);
      }
    } catch (err) {
      this.logger.warn(`OTP no disponible (${(err as Error).message}); uso el planner interno`);
      return null;
    }

    if (json.errors?.length) {
      this.logger.warn(`OTP devolvió errores GraphQL: ${json.errors.map((e) => e.message).join('; ')}`);
      return null;
    }

    const nodes = json.data?.planConnection?.edges ?? [];
    const options = nodes
      .map((edge) => edge?.node)
      .filter((node): node is OtpItinerary => !!node)
      .map((node) => mapItinerary(node))
      .filter((option): option is JourneyOption => option !== null);

    const sortedOptions = [...options].sort((a, b) => {
      const costA =
        a.durationMinutes +
        (a.type === 'transfer' ? TRANSFER_PENALTY_MINUTES : 0);
      const costB =
        b.durationMinutes +
        (b.type === 'transfer' ? TRANSFER_PENALTY_MINUTES : 0);
      if (costA !== costB) {
        return costA - costB;
      }
      return a.durationMinutes - b.durationMinutes;
    });

    // OTP puede devolver más de `first` resultados paginados: recorto.
    return sortedOptions.slice(0, query.maxResults);
  }
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

function minutesBetweenIso(startIso: string | null | undefined, endIso: string | null | undefined): number {
  if (!startIso || !endIso) return 0;
  const start = Date.parse(startIso);
  const end = Date.parse(endIso);
  if (Number.isNaN(start) || Number.isNaN(end)) return 0;
  return Math.round((end - start) / 60_000);
}
