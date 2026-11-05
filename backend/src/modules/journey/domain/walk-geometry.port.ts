import { LineGeometry } from './journey.model';

/** Punto geográfico (latitud / longitud decimal). */
export interface WalkPoint {
  lat: number;
  lon: number;
}

/**
 * Puerto del ruteador peatonal externo (ej. Valhalla). Devuelve la geometría
 * real de una caminata por la red viaria entre dos puntos, o `null` si no está
 * disponible (sin configuración, error o timeout). `JourneyService` lo usa solo
 * para los tramos a pie que el motor principal (OTP) no trazó, de modo que en
 * producción (Vercel, sin OTP) la app dibuje calles y no rectas.
 */
export interface WalkGeometryPort {
  route(from: WalkPoint, to: WalkPoint): Promise<LineGeometry | null>;
}
