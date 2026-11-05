import { Injectable, Logger } from '@nestjs/common';
import { AppConfigService } from '../../../../core/config/app-config.service';
import { LineGeometry } from '../../domain/journey.model';
import { WalkGeometryPort, WalkPoint } from '../../domain/walk-geometry.port';
import { decodePolylineToGeoJSON } from '../otp/decode-polyline';

/**
 * Respuesta parcial de Valhalla `/route`. El demo público ignora
 * `shape_format` y siempre devuelve el `shape` como polilínea codificada
 * (polyline6, precisión 1e6); algunas instancias autoalojadas sí devuelven el
 * objeto GeoJSON. Se aceptan ambas formas.
 */
interface ValhallaRouteResponse {
  trip?: { legs?: { shape?: unknown }[] } | null;
  error?: string;
}

/**
 * Ruteador peatonal sobre una instancia de Valhalla (URL pública de demo u
 * autoalojada). Gratis y sin servidor propio: solo se necesita
 * `WALK_ROUTER_URL`. Si no está configurado, o si la llamada falla/trunca,
 * devuelve `null` y `JourneyService` degrada a la línea recta (comportamiento
 * histórico). La URL de demo es de cortesía (límites bajos); para producción
 * con tráfico conviene un Valhalla propio o un alta de OpenRouteService.
 */
@Injectable()
export class ValhallaWalkGeometry implements WalkGeometryPort {
  private readonly logger = new Logger(ValhallaWalkGeometry.name);

  constructor(private readonly config: AppConfigService) {}

  async route(from: WalkPoint, to: WalkPoint): Promise<LineGeometry | null> {
    const url = this.config.walkRouterUrl;
    if (!url) return null;

    const body = {
      costing: 'pedestrian',
      units: 'meters',
      locations: [
        { lat: from.lat, lon: from.lon },
        { lat: to.lat, lon: to.lon },
      ],
    };

    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      this.config.walkRouterTimeoutMs
    );
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      if (!res.ok) {
        this.logger.warn(
          `Valhalla respondió HTTP ${res.status}; dejo la caminata en recta`
        );
        return null;
      }
      const json = (await res.json()) as ValhallaRouteResponse;
      return parseValhallaShape(json.trip?.legs?.[0]?.shape);
    } catch (err) {
      this.logger.warn(
        `Error ruteando caminata con Valhalla (${(err as Error).message})`
      );
      return null;
    } finally {
      clearTimeout(timer);
    }
  }
}

/**
 * Convierte el `shape` de Valhalla (string polyline6 u objeto GeoJSON
 * LineString) en la LineString `[lon, lat]` del contrato. `null` si no hay al
 * menos dos coordenadas.
 */
export function parseValhallaShape(shape: unknown): LineGeometry | null {
  if (typeof shape === 'string') {
    try {
      const coordinates = decodePolylineToGeoJSON(shape, 1e6);
      return coordinates.length >= 2
        ? { type: 'LineString', coordinates }
        : null;
    } catch {
      return null;
    }
  }
  if (shape && typeof shape === 'object') {
    const geo = shape as { type?: unknown; coordinates?: unknown };
    if (
      geo.type === 'LineString' &&
      Array.isArray(geo.coordinates) &&
      geo.coordinates.length >= 2
    ) {
      return { type: 'LineString', coordinates: geo.coordinates as number[][] };
    }
  }
  return null;
}
