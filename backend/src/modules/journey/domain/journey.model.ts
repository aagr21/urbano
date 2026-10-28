/** Modelos de dominio del planeador de viaje. */

/** Parada candidata (cercana al origen o al destino). */
export interface CandidateStop {
  stopId: string;
  name: string;
  lat: number;
  lon: number;
  /** Distancia de caminata en metros hasta el punto del usuario. */
  distanceMeters: number;
}

/** Parada de un trip con horarios base (segundos desde medianoche, pueden exceder 24h). */
export interface TripStop {
  stopId: string;
  sequence: number;
  arrivalSec: number;
  departureSec: number;
}

/** Horario base de un trip + ventana de frequencies. */
export interface TripSchedule {
  tripId: string;
  routeId: string;
  routeShortName: string;
  routeColor: string | null;
  directionId: number;
  headsign: string | null;
  startTimeSec: number;
  endTimeSec: number;
  headwaySeconds: number;
  /** Ordenado por sequence. */
  stops: TripStop[];
}

/**
 * Geometría de mapa: sublínea EXACTA del shape recortada entre dos paradas
 * (PostGIS `ST_LineSubstring`), en pares `[lon, lat]`.
 */
export interface LineGeometry {
  type: 'LineString';
  /** Pares `[lon, lat]` (GeoJSON). */
  coordinates: number[][];
}

/** Parada con coordenadas — sirve para marcadores del mapa. */
export interface StopRef {
  id: string;
  name: string;
  lat: number;
  lon: number;
}

export interface WalkLeg {
  kind: 'walk';
  durationMinutes: number;
  distanceMeters: number;
  /**
   * Recorrido real a pie por la red viaria (`[lon, lat]`).
   * `null`/ausente si el motor de ruteo no está disponible (fallback:
   * el cliente dibuja la línea recta entre extremos).
   */
  geometry?: LineGeometry | null;
  /** Parada inicial del tramo a pie con `lat/lon` (si OTP la provee). */
  fromStop?: StopRef | null;
  /** Parada final del tramo a pie con `lat/lon` (si OTP la provee). */
  toStop?: StopRef | null;
}

export interface BusLeg {
  kind: 'bus';
  routeId: string;
  routeShortName: string;
  routeColor: string | null;
  tripId: string;
  fromStopId: string;
  toStopId: string;
  departAt: string;
  arriveAt: string;
  stops: number;
  /**
   * Tramo del shape recortado entre `fromStop` y `toStop` (`[lon, lat]`).
   * `null` si la ruta no tiene shape (o el tramo resulta degenerado).
   * El planeador puro no lo conoce: lo adjunta `JourneyService`.
   */
  geometry?: LineGeometry | null;
  /** Parada de inicio del tramo con `lat`/`lon`. La adjunta `JourneyService`. */
  fromStop?: StopRef;
  /** Parada de fin del tramo con `lat`/`lon`. La adjunta `JourneyService`. */
  toStop?: StopRef;
}

export type JourneyLeg = WalkLeg | BusLeg;

export interface JourneyOption {
  type: 'direct' | 'transfer';
  departAt: string;
  arriveAt: string;
  durationMinutes: number;
  /**
   * Parada de subida/bajada a la que se camina. `lat`/`lon` los adjunta
   * `JourneyService` (el planeador puro no resuelve coordenadas).
   */
  walkToStop: { id: string; name: string; distanceMeters: number; lat?: number; lon?: number };
  walkFromStop: { id: string; name: string; distanceMeters: number; lat?: number; lon?: number };
  legs: JourneyLeg[];
}

/** Entrada completa del planeador puro. */
export interface PlannerInput {
  originStops: CandidateStop[];
  destStops: CandidateStop[];
  trips: TripSchedule[];
  /** Hora de referencia en segundos desde medianoche. */
  timeSec: number;
  maxResults: number;
}
