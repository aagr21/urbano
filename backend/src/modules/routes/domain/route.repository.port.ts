import {
  DepartureSourceRecord,
  RouteDetailRecord,
  RoutePage,
  RouteQuery,
  RouteStopRecord,
} from './route.model';

/**
 * Puerto (interfaz) del repositorio de rutas.
 * La capa de aplicación depende solo de esta interfaz; la implementación
 * TypeORM vive en infrastructure/.
 */
export abstract class RouteRepositoryPort {
  abstract findAll(query: RouteQuery): Promise<RoutePage>;
  abstract findById(id: string): Promise<RouteDetailRecord | null>;
  abstract findStops(id: string, directionId: number): Promise<RouteStopRecord[]>;
  /**
   * Fuentes de salidas de la ruta. Con `stopId` = null usa la primera
   * parada de cada viaje (salidas desde el inicio del recorrido).
   */
  abstract findDepartureSources(
    id: string,
    stopId: string | null,
    directionId?: number,
  ): Promise<DepartureSourceRecord[]>;
}
