import { BusLeg, JourneyOption } from './journey.model';
import {
  MIN_FIRST_RIDE_TRANSFER_M,
  TRANSFER_PENALTY_MINUTES,
} from './journey-limits';
import { isLonLat, straightLineMeters } from './geo';

/**
 * Política de resultados, común a los dos motores (OTP y planner interno):
 * costo generalizado, orden, recorte y filtros posteriores.
 */

/**
 * Penalización por transbordo (en minutos de costo generalizado).
 * El VALOR vive en journey-limits (contrato de `GET /meta`); el razonamiento
 * de negocio: en Santa Cruz el transbordo duplica el costo del pasaje
 * (Bs 2.00-2.50 extra) y añade tiempo de espera incierto en la calle, por
 * tanto los directos se prefieren salvo que el transbordo ahorre sustancial.
 */

/**
 * Costo generalizado de una opción, en minutos: duración + penalización de
 * transbordo. La POLÍTICA de orden de resultados vive aquí, en domain — la
 * usan el planner interno y el servicio que recibe opciones de OTP, de modo
 * que ambos motores rankean con la MISMA regla (antes la copiaba el adapter
 * OTP y cualquier cambio de scoring tocaba dos lugares).
 */
export function journeyCost(option: JourneyOption): number {
  return (
    option.durationMinutes +
    (option.type === 'transfer' ? TRANSFER_PENALTY_MINUTES : 0)
  );
}

/** Ordena por costo generalizado; empates y desempates determinísticos. */
export function compareJourneyOptions(
  a: JourneyOption,
  b: JourneyOption
): number {
  const costA = journeyCost(a);
  const costB = journeyCost(b);
  if (costA !== costB) return costA - costB;
  if (a.durationMinutes !== b.durationMinutes) {
    return a.durationMinutes - b.durationMinutes;
  }
  if (a.departAt !== b.departAt) return a.departAt < b.departAt ? -1 : 1;
  // Preferir directo en empate
  if (a.type !== b.type) return a.type === 'direct' ? -1 : 1;
  return 0;
}

/**
 * Ordena por la política común ([compareJourneyOptions]) y recorta a
 * [maxResults]: la llamada de top de resultados también es política, no un
 * detalle del adapter.
 */
export function rankAndCut(
  options: JourneyOption[],
  maxResults: number
): JourneyOption[] {
  return [...options].sort(compareJourneyOptions).slice(0, maxResults);
}

/** Metros totales a pie de una opción (acceso + transbordos + egreso). */
export function totalWalkMeters(option: JourneyOption): number {
  return option.legs.reduce(
    (acc, leg) => acc + (leg.kind === 'walk' ? leg.distanceMeters : 0),
    0
  );
}

/**
 * Metros que recorre un tramo de micro YA enriquecido: largo de su
 * `geometry` (shape recortado / polyline de OTP) o, sin ella, la recta entre
 * sus paradas. `null` si no hay con qué medir.
 */
export function busLegRideMeters(leg: BusLeg): number | null {
  const coords = leg.geometry?.coordinates;
  if (coords && coords.length >= 2) {
    let total = 0;
    for (let i = 1; i < coords.length; i++) {
      const p = coords[i - 1];
      const q = coords[i];
      if (!isLonLat(p) || !isLonLat(q)) continue;
      total += straightLineMeters(
        { lat: p[1], lon: p[0] },
        { lat: q[1], lon: q[0] }
      );
    }
    return total;
  }
  if (leg.fromStop && leg.toStop) {
    return straightLineMeters(leg.fromStop, leg.toStop);
  }
  return null;
}

/**
 * Descarta las opciones con transbordo cuyo PRIMER micro recorre menos de
 * [MIN_FIRST_RIDE_TRANSFER_M]. Es la regla para cualquier motor (OTP y el
 * planner interno, que además ya la aplica durante la búsqueda para no gastar
 * cupos de resultado en ellas). Si el tramo no se puede medir, se conserva.
 */
export function dropShortFirstRideTransfers(
  options: JourneyOption[]
): JourneyOption[] {
  return options.filter((option) => {
    if (option.type !== 'transfer') return true;
    const firstBus = option.legs.find(
      (leg): leg is BusLeg => leg.kind === 'bus'
    );
    if (!firstBus) return true;
    const ride = busLegRideMeters(firstBus);
    return ride === null || ride >= MIN_FIRST_RIDE_TRANSFER_M;
  });
}
