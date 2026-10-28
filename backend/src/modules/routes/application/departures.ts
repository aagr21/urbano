import { timeToSeconds } from '../../../core/common/utils/gtfs-time';
import { DepartureSourceRecord, RouteDeparture } from '../domain/route.model';

/**
 * Cálculo puro de próximas salidas en una parada a partir de frequencies.
 *
 * GTFS frequencies: el trip base parte del origen en `startTime` y se repite
 * cada `headwaySeconds` hasta `endTime` (k = 0..floor((end-start)/headway)).
 * Los horarios de cada parada se desplazan el mismo offset k*headway.
 * La ventana limita el INICIO del trip, no la salida en la parada (una parada
 * tardía puede tener salidas posteriores a endTime).
 *
 * Devuelve las salidas con hora >= `fromSeconds`, ordenadas, máximo `maxResults`
 * (20 según contrato).
 */
export function computeUpcomingDepartures(
  sources: DepartureSourceRecord[],
  fromSeconds: number,
  maxResults = 20,
): RouteDeparture[] {
  const departures: RouteDeparture[] = [];

  for (const source of sources) {
    const startSec = timeToSeconds(source.startTime);
    const endSec = timeToSeconds(source.endTime);
    const stopDepSec = timeToSeconds(source.stopDepartureTime);
    const headway = source.headwaySeconds > 0 ? source.headwaySeconds : 300;

    // Cantidad de viajes generados por la ventana de frequencies
    const tripCount = Math.floor((endSec - startSec) / headway) + 1;

    // Primer k tal que stopDepSec + k*headway >= fromSeconds
    const offset = fromSeconds - stopDepSec;
    const firstK = offset <= 0 ? 0 : Math.ceil(offset / headway);

    for (let k = firstK; k < tripCount; k++) {
      const departureSec = stopDepSec + k * headway;
      departures.push({
        tripId: source.tripId,
        directionId: source.directionId,
        headsign: source.headsign,
        time: formatSeconds(departureSec),
        realTime: false,
        headwaySeconds: source.headwaySeconds,
      });
    }
  }

  departures.sort((a, b) => timeToSeconds(a.time) - timeToSeconds(b.time));
  return departures.slice(0, maxResults);
}

function formatSeconds(total: number): string {
  const s = Math.max(0, Math.round(total));
  const hh = Math.floor(s / 3600);
  const mm = Math.floor((s % 3600) / 60);
  const ss = s % 60;
  return [hh, mm, ss].map((v) => String(v).padStart(2, '0')).join(':');
}
