/**
 * Invariantes del CONTRATO de planificación, en **un solo lugar**.
 *
 * Estas reglas le interesan al CLIENTE tanto como al servidor: la app
 * guarda en su estado (o decía en su guard) los mismos números — 150 m
 * mínimos, máximo de resultados, radio de caminata — sin forma de
 * enterarse si el backend los cambiaba. `GET /meta` los expone.
 *
 * NO son constantes de tuning: cambiar uno de estos valores ES un cambio
 * de contrato (severidad: antes de tocar, actualizar `docs/api-contract.md`
 * y la app).
 */

/** Máximo de opciones de viaje que el planner devuelve (`maxResults`). */
export const MAX_RESULTS = 10;

/** Radio de caminata máximo hasta una parada (metros). */
export const WALK_RADIUS_M = 500;

/** Máximo de paradas candidatas por lado (acota la búsqueda). */
export const MAX_CANDIDATE_STOPS = 15;

/**
 * Distancia mínima (línea recta) entre origen y destino para planificar en
 * transporte: por debajo de esto caminar es más rápido y cualquier "plan"
 * de bus sería subirse donde se baja. Debe coincidir con el guard del
 * cliente (`JourneyPlannerController`).
 */
export const MIN_TRANSIT_DISTANCE_M = 150;

/**
 * Distancia mínima (línea recta) entre la parada de subir y la de bajar:
 * por debajo de esto el tramo de bus es un absurdo ("bajarse donde se
 * subió") y la opción se descarta. Replica el caso del reporte.
 */
export const MIN_BOARDING_PAIR_DISTANCE_M = 150;

/** Velocidad de caminata: 80 m/min ≈ 4.8 km/h. */
export const WALK_SPEED_M_PER_MIN = 80;

/** Penalización de costo (minutos) por transbordo. */
export const TRANSFER_PENALTY_MINUTES = 10;

/** Snapshot INMUTABLE para exponer por la API (`GET /meta`). */
export const JOURNEY_LIMITS = Object.freeze({
  maxResults: MAX_RESULTS,
  walkRadiusM: WALK_RADIUS_M,
  maxCandidateStops: MAX_CANDIDATE_STOPS,
  minTransitDistanceM: MIN_TRANSIT_DISTANCE_M,
  minBoardingPairDistanceM: MIN_BOARDING_PAIR_DISTANCE_M,
  walkSpeedMPerMin: WALK_SPEED_M_PER_MIN,
  transferPenaltyMinutes: TRANSFER_PENALTY_MINUTES,
});
