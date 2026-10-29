import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { timeToSeconds, nowSecondsInTimeZone } from '../../../core/common/utils/gtfs-time';
import { JOURNEY_DATA_PORT, JOURNEY_ROUTER_PORT } from '../../../core/common/tokens';
import { JourneyDataPort, LegDetailQuery } from '../domain/journey-data.port';
import { JourneyRouterPort } from '../domain/journey-router.port';
import {
  BusLeg,
  CandidateStop,
  JourneyOption,
  LineGeometry,
  StopRef,
} from '../domain/journey.model';
import {
  planJourneys,
  rankAndCut,
  straightLineMeters,
} from '../domain/journey-planner';
import {
  JOURNEY_LIMITS,
  MAX_CANDIDATE_STOPS,
  MIN_TRANSIT_DISTANCE_M,
  WALK_RADIUS_M,
} from '../domain/journey-limits';
import { JourneyQueryDto } from './journey.dto';

// Re-export por compatibilidad de quién ya los consumía de este archivo.
export {
  JOURNEY_LIMITS,
  MAX_CANDIDATE_STOPS,
  MIN_TRANSIT_DISTANCE_M,
  WALK_RADIUS_M,
};

@Injectable()
export class JourneyService {
  private readonly logger = new Logger(JourneyService.name);

  constructor(
    @Inject(JOURNEY_DATA_PORT) private readonly data: JourneyDataPort,
    /**
     * Motor externo (OTP2). Opcional: si no hay `OTP_URL` el proveedor es
     * null y se usa siempre el planner interno sobre PostGIS.
     */
    @Optional()
    @Inject(JOURNEY_ROUTER_PORT)
    private readonly router?: JourneyRouterPort | null,
  ) {}

  async plan(query: JourneyQueryDto): Promise<{ options: JourneyOption[] }> {
    // Origen y destino en (prácticamente) el mismo lugar: no hay viaje que
    // planificar — responder "sin opciones" sin siquiera tocar la base.
    const straightLine = straightLineMeters(
      { lat: query.originLat, lon: query.originLon },
      { lat: query.destLat, lon: query.destLon },
    );
    if (straightLine < MIN_TRANSIT_DISTANCE_M) {
      return { options: [] };
    }

    const timeSec = query.time
      ? timeToSeconds(query.time)
      : nowSecondsInTimeZone('America/La_Paz');

    // Motor externo (OTP2: GTFS + OSM). Si responde, sus itinerarios ya
    // vienen con caminatas trazadas por la red viaria.
    if (this.router) {
      try {
        const routed = await this.router.plan({
          originLat: query.originLat,
          originLon: query.originLon,
          destLat: query.destLat,
          destLon: query.destLon,
          timeSec,
          maxResults: query.maxResults,
        });
        if (routed !== null) {
          // La POLÍTICA de orden/recorte vive en domain (rankAndCut): se
          // aplica igual al resultado del motor externo que al del planner
          // interno; el adapter OTP solo mapea.
          return { options: rankAndCut(routed, query.maxResults) };
        }
        this.logger.warn('OTP no disponible; degrado al planner interno');
      } catch (err) {
        this.logger.warn(`Error consultando OTP (${(err as Error).message}); degrado al planner interno`);
      }
    }

    const [originStops, destStops] = await Promise.all([
      this.data.findStopsNear(query.originLat, query.originLon, WALK_RADIUS_M, MAX_CANDIDATE_STOPS),
      this.data.findStopsNear(query.destLat, query.destLon, WALK_RADIUS_M, MAX_CANDIDATE_STOPS),
    ]);

    if (originStops.length === 0 || destStops.length === 0) {
      return { options: [] };
    }

    const stopIds = [
      ...new Set([...originStops, ...destStops].map((s) => s.stopId)),
    ];
    const tripIds = await this.data.findTripIdsServingStops(stopIds);
    if (tripIds.length === 0) {
      return { options: [] };
    }
    const trips = await this.data.loadTripSchedules(tripIds);

    const options = planJourneys({
      originStops,
      destStops,
      trips,
      timeSec,
      maxResults: query.maxResults,
    });

    await this.enrichOptions(options, [...originStops, ...destStops]);
    return { options };
  }

  /**
   * Adjunta a cada opción la geometría de mapa:
   * - `busLeg.geometry`: tramo EXACTO del shape recortado entre sus paradas.
   * - `busLeg.fromStop`/`toStop` y `walkToStop`/`walkFromStop`: `lat`/`lon`
   *   para marcadores.
   *
   * Una sola pasada: deduplica los tramos de bus por `tripId:from:to`, pide
   * todos los detalles de golpe (`loadLegDetails`) y las paradas de las
   * caminatas de golpe (`findStopRefs`). El planeador sigue siendo puro.
   */
  private async enrichOptions(
    options: JourneyOption[],
    candidateStops: CandidateStop[],
  ): Promise<void> {
    if (options.length === 0) return;

    const uniqueLegs = new Map<string, LegDetailQuery>();
    const stopIds = new Set<string>();
    for (const option of options) {
      stopIds.add(option.walkToStop.id);
      stopIds.add(option.walkFromStop.id);
      for (const leg of option.legs) {
        if (leg.kind !== 'bus') continue;
        const key = legKey(leg);
        if (!uniqueLegs.has(key)) {
          uniqueLegs.set(key, {
            tripId: leg.tripId,
            fromStopId: leg.fromStopId,
            toStopId: leg.toStopId,
          });
        }
        stopIds.add(leg.fromStopId);
        stopIds.add(leg.toStopId);
      }
    }

    const [details, stopRefs] = await Promise.all([
      this.data.loadLegDetails([...uniqueLegs.values()]),
      this.data.findStopRefs([...stopIds]),
    ]);

    const detailByKey = new Map(
      details.map((d) => [legKey(d), d] as const),
    );
    const stopById = new Map<string, StopRef>(stopRefs.map((s) => [s.id, s]));
    // Fallback: paradas candidatas ya cargadas por findStopsNear.
    for (const stop of candidateStops) {
      if (!stopById.has(stop.stopId)) {
        stopById.set(stop.stopId, {
          id: stop.stopId,
          name: stop.name,
          lat: stop.lat,
          lon: stop.lon,
        });
      }
    }

    for (const option of options) {
      option.walkToStop = withCoords(option.walkToStop, stopById);
      option.walkFromStop = withCoords(option.walkFromStop, stopById);

      for (const leg of option.legs) {
        if (leg.kind !== 'bus') continue;
        const detail = detailByKey.get(legKey(leg));
        const geometry: LineGeometry | null =
          detail?.coordinates && detail.coordinates.length >= 2
            ? { type: 'LineString', coordinates: detail.coordinates }
            : null;
        enrichBusLeg(leg, geometry, detail?.fromStop, detail?.toStop, stopById);
      }
    }
  }
}

function legKey(leg: {
  tripId: string;
  fromStopId: string;
  toStopId: string;
}): string {
  return `${leg.tripId}:${leg.fromStopId}:${leg.toStopId}`;
}

function enrichBusLeg(
  leg: BusLeg,
  geometry: LineGeometry | null,
  fromStop: StopRef | undefined,
  toStop: StopRef | undefined,
  stopById: Map<string, StopRef>,
): void {
  leg.geometry = geometry;
  const resolvedFrom = fromStop ?? stopById.get(leg.fromStopId);
  if (resolvedFrom) leg.fromStop = resolvedFrom;
  const resolvedTo = toStop ?? stopById.get(leg.toStopId);
  if (resolvedTo) leg.toStop = resolvedTo;
}

function withCoords<T extends { id: string; name: string; distanceMeters: number; lat?: number; lon?: number }>(
  walk: T,
  stopById: Map<string, StopRef>,
): T {
  const ref = stopById.get(walk.id);
  if (!ref) return walk;
  return { ...walk, lat: ref.lat, lon: ref.lon };
}
