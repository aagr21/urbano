import { JourneyOption } from './journey.model';

/** Query de planificación para el motor de ruteo externo (ej. OTP2). */
export interface JourneyRouterQuery {
  originLat: number;
  originLon: number;
  destLat: number;
  destLon: number;
  /** Hora de referencia en segundos desde medianoche (America/La_Paz). */
  timeSec: number;
  maxResults: number;
}

/**
 * Puerto del motor de planificación externo (ej. OpenTripPlanner).
 * Devuelve opciones ya mapeadas al modelo de dominio, con las caminatas
 * trazadas por la red viaria. `null` si el motor no está disponible
 * (el caller degrada al planner interno sobre PostGIS).
 */
export interface JourneyRouterPort {
  plan(query: JourneyRouterQuery): Promise<JourneyOption[] | null>;
}
