/** Modelos de dominio de paradas. */

export interface StopSummary {
  id: string;
  code: string | null;
  name: string;
  lat: number;
  lon: number;
}

export interface RouteRef {
  id: string;
  shortName: string;
  color: string | null;
  /** `route_long_name` del feed: el trayecto escrito, para el listado de lugares. */
  longName: string | null;
  /** Foto real del micro (`micros.csv`), o null si la línea no tiene. */
  imageUrl: string | null;
  /**
   * Sentidos que sirven REALMENTE esta parada (GTFS: 0 = ida, 1 = vuelta).
   * Viene de `array_agg(DISTINCT trip.direction_id)`: sin él el listado no
   * puede distinguir «pasa en ida» de «pasa en ambos» (una vía de mano única
   * no tiene vuelta).
   */
  directionIds: number[];
}

export interface StopWithRoutes extends StopSummary {
  routes: RouteRef[];
}

export interface StopNearby extends StopWithRoutes {
  distanceMeters: number;
}

export interface StopDetail extends StopSummary {
  routes: RouteRef[];
  location: {
    type: 'Point';
    coordinates: [number, number];
  };
}

export interface NearbyQuery {
  lat: number;
  lon: number;
  radiusMeters: number;
  limit: number;
}

export interface StopNearbyPage {
  items: StopNearby[];
  total: number;
}

export interface StopSearchPage {
  items: StopWithRoutes[];
  total: number;
}

/** Puerto del repositorio de paradas. */
export abstract class StopRepositoryPort {
  abstract findNearby(query: NearbyQuery): Promise<StopNearbyPage>;
  abstract search(q: string, limit: number): Promise<StopSearchPage>;
  abstract findById(id: string): Promise<StopDetail | null>;
}
