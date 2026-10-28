/** Tokens de inyección de dependencias (puertos hexagonales). */
export const ROUTE_REPOSITORY = Symbol('ROUTE_REPOSITORY');
export const STOP_REPOSITORY = Symbol('STOP_REPOSITORY');
export const TRIP_REPOSITORY = Symbol('TRIP_REPOSITORY');
export const JOURNEY_DATA_PORT = Symbol('JOURNEY_DATA_PORT');
export const JOURNEY_ROUTER_PORT = Symbol('JOURNEY_ROUTER_PORT');
export const STATS_REPOSITORY = Symbol('STATS_REPOSITORY');
export const SERVICE_REPOSITORY = Symbol('SERVICE_REPOSITORY');

/** TTL (ms) por defecto de la caché en memoria de endpoints de lectura. */
export const CACHE_TTL_MS = 60_000;
