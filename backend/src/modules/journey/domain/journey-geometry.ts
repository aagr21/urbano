import { JourneyOption } from './journey.model';
import { isLonLat, straightLineMeters } from './geo';

/**
 * Geometría de las opciones para el mapa (sentido de cada tramo y costura
 * caminata↔micro). Regla común a los dos motores (OTP y el planner interno):
 * se aplica una sola vez, en el servicio, sobre las opciones ya armadas.
 */

/**
 * Margen (m) para no invertir geometrías simétricas (rutas circulares o
 * paradas de subida/bajada muy próximas).
 */
const GEOMETRY_ORIENTATION_MARGIN_M = 1;

/**
 * Garantiza que la geometría de cada tramo de micro siga el sentido REAL del
 * viaje: de `fromStop` (subida) a `toStop` (bajada).
 *
 * La comprobación es LOCAL al tramo (nunca contra el origen/destino del
 * usuario): un recorrido puede girar 90° o ir en contra del rumbo general y
 * seguir siendo correcto. Solo se invierte la lista de coordenadas si el
 * primer punto está claramente más cerca de la bajada que de la subida; las
 * paradas, los horarios y los ids NO se tocan.
 */
export function orientBusLegGeometry(
  options: JourneyOption[]
): JourneyOption[] {
  for (const option of options) {
    for (const leg of option.legs) {
      if (leg.kind !== 'bus') continue;
      const coordinates = leg.geometry?.coordinates;
      if (!coordinates || coordinates.length < 2) continue;
      const from = leg.fromStop;
      const to = leg.toStop;
      if (!from || !to) continue;

      const first = coordinates[0];
      const last = coordinates[coordinates.length - 1];
      if (!isLonLat(first) || !isLonLat(last)) continue;

      const forward =
        straightLineMeters({ lat: first[1], lon: first[0] }, from) +
        straightLineMeters({ lat: last[1], lon: last[0] }, to);
      const backward =
        straightLineMeters({ lat: first[1], lon: first[0] }, to) +
        straightLineMeters({ lat: last[1], lon: last[0] }, from);

      if (backward + GEOMETRY_ORIENTATION_MARGIN_M < forward) {
        leg.geometry = {
          type: 'LineString',
          coordinates: [...coordinates].reverse(),
        };
      }
    }
  }
  return options;
}

/**
 * Distancia máxima (m) entre una parada y el trazado del micro para coserlos.
 * En una avenida de doble calzada el `shape` corre por el eje del carril y la
 * parada está en la acera, así que el desfase real ronda 10-25 m.
 */
export const STOP_SNAP_MAX_METERS = 60;

/**
 * Cierra el hueco entre la caminata y el micro en el mapa.
 *
 * El `shape` de GTFS circula por el eje de la calzada y la parada está en la
 * acera: en avenidas de doble calzada el `shape` pasa 10-20 m al otro lado de
 * la parada, así que la caminata terminaba en la acera y el micro se dibujaba
 * en la calzada de enfrente. En pantalla se lee como "me hace cruzar para
 * tomar el micro" o "la caminata no llega hasta donde pasa el micro".
 *
 * El `shape` es la verdad de por dónde pasa el micro (ya viene reparado por
 * calzada en el feed), así que **no se mueve**: lo que se estira es la
 * caminata, que termina (o empieza) exactamente en el primer/último punto del
 * trazado del micro vecino. Las paradas, horarios e ids no se tocan.
 *
 * Solo se cose cuando el extremo de la caminata está a menos de
 * [STOP_SNAP_MAX_METERS] del trazado: si el micro pasa lejos, el hueco es real
 * y no se inventa un salto.
 */
export function connectWalkAndBusGeometry(
  options: JourneyOption[]
): JourneyOption[] {
  for (const option of options) {
    for (let i = 0; i < option.legs.length; i++) {
      const leg = option.legs[i];
      if (leg.kind !== 'walk') continue;
      const coordinates = leg.geometry?.coordinates;
      if (!coordinates || coordinates.length === 0) continue;

      const after = option.legs[i + 1];
      const before = option.legs[i - 1];
      const afterStart =
        after?.kind === 'bus' ? after.geometry?.coordinates[0] : undefined;
      const beforeCoords =
        before?.kind === 'bus' ? before.geometry?.coordinates : undefined;
      const beforeEnd =
        beforeCoords && beforeCoords.length > 0
          ? beforeCoords[beforeCoords.length - 1]
          : undefined;
      if (!isLonLat(afterStart) && !isLonLat(beforeEnd)) continue;

      const next = coordinates.map((point) => [point[0], point[1]]);
      const lastIndex = next.length - 1;
      const end = next[lastIndex];
      const start = next[0];

      if (
        isLonLat(afterStart) &&
        isLonLat(end) &&
        straightLineMeters(
          { lat: end[1], lon: end[0] },
          {
            lat: afterStart[1],
            lon: afterStart[0],
          }
        ) <= STOP_SNAP_MAX_METERS
      ) {
        next[lastIndex] = [afterStart[0], afterStart[1]];
      }
      if (
        isLonLat(beforeEnd) &&
        isLonLat(start) &&
        straightLineMeters(
          { lat: start[1], lon: start[0] },
          {
            lat: beforeEnd[1],
            lon: beforeEnd[0],
          }
        ) <= STOP_SNAP_MAX_METERS
      ) {
        next[0] = [beforeEnd[0], beforeEnd[1]];
      }
      leg.geometry = { type: 'LineString', coordinates: next };
    }
  }
  return options;
}
