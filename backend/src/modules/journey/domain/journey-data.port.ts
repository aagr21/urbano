import { CandidateStop, StopRef, TripSchedule } from './journey.model';

/** Tramo de bus a enriquecer con geometría y paradas (clave de deduplicación). */
export interface LegDetailQuery {
  tripId: string;
  fromStopId: string;
  toStopId: string;
}

/** Detalle de un tramo de bus: paradas con coordenadas + tramo recortado del shape. */
export interface LegDetail extends LegDetailQuery {
  fromStop: StopRef;
  toStop: StopRef;
  /** Pares `[lon, lat]` del tramo exacto; `null` si la ruta no tiene shape. */
  coordinates: number[][] | null;
}

/** Puerto de datos del planeador (implementado en infrastructure/). */
export abstract class JourneyDataPort {
  /** Paradas dentro de radio en metros, ordenadas por distancia. */
  abstract findStopsNear(
    lat: number,
    lon: number,
    radiusMeters: number,
    limit: number,
  ): Promise<CandidateStop[]>;

  /** Ids de viajes que sirven al menos una de las paradas indicadas. */
  abstract findTripIdsServingStops(stopIds: string[]): Promise<string[]>;

  /** Horarios base + frequencies completos de los viajes indicados. */
  abstract loadTripSchedules(tripIds: string[]): Promise<TripSchedule[]>;

  /**
   * Detalles de TODOS los tramos recibidos en UNA sola query: coordenadas de
   * las paradas from/to + geometría recortada del shape (PostGIS
   * `ST_LineSubstring`). El servicio deduplica antes de llamar.
   */
  abstract loadLegDetails(legs: LegDetailQuery[]): Promise<LegDetail[]>;

  /** Referencias (id/nombre/lat/lon) de paradas por id — resuelve `walkToStop`/`walkFromStop`. */
  abstract findStopRefs(ids: string[]): Promise<StopRef[]>;
}
