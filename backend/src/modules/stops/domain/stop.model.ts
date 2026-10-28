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
