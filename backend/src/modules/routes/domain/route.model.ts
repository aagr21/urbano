/** Modelos de dominio de rutas. Independientes de TypeORM y del HTTP. */

export interface RouteSummary {
  id: string;
  shortName: string;
  longName: string | null;
  color: string | null;
  textColor: string | null;
  description: string | null;
  type: number;
  /** Cantidad de direcciones (0/1). */
  directions: number;
  stopCount: number;
  tripCount: number;
  /** Imagen del itinerario (micros.csv) o null si no hay. */
  imageUrl: string | null;
}

export interface RouteDirectionInfo {
  directionId: number;
  headsign: string | null;
  tripId: string;
  firstDeparture: string;
  lastDeparture: string;
  headwaySeconds: number | null;
  stopCount: number;
}

export interface RouteShapeGeoJson {
  type: 'Feature';
  properties: { id: string };
  geometry: {
    type: 'LineString';
    coordinates: Array<[number, number]>;
  };
}

/**
 * Detalle de ruta: el contrato redefine `directions` como arreglo de objetos
 * (en RouteSummary es un conteo), por eso se omite y se vuelve a declarar.
 */
export type RouteDetail = Omit<RouteSummary, 'directions'> & {
  bbox: [number, number, number, number] | null;
  directions: RouteDirectionInfo[];
  shape: RouteShapeGeoJson | null;
};

export interface RouteStop {
  id: string;
  code: string | null;
  name: string;
  lat: number;
  lon: number;
  sequence: number;
  arrivalTime: string;
  departureTime: string;
  distanceMeters: number;
}

export interface RouteDeparture {
  tripId: string;
  directionId: number;
  headsign: string | null;
  time: string;
  realTime: boolean;
  headwaySeconds: number | null;
}

export interface RouteQuery {
  q?: string;
  page: number;
  limit: number;
  sort: 'name' | 'shortName' | 'longName' | 'stopCount';
}

export interface RoutePage {
  items: RouteSummary[];
  total: number;
}

/** Registro crudo del detalle (lo arma la capa de aplicación). */
export interface RouteDetailRecord
  extends Omit<RouteSummary, 'directions'> {
  directions: Array<
    Omit<RouteDirectionInfo, 'stopCount'> & {
      stopCount: number;
      shapeId: string | null;
    }
  >;
  /** shape_id → coordenadas + bbox */
  shapes: Record<
    string,
    { coordinates: Array<[number, number]>; bbox: [number, number, number, number] }
  >;
}

export interface RouteStopRecord {
  id: string;
  code: string | null;
  name: string;
  lat: number;
  lon: number;
  sequence: number;
  arrivalTime: string;
  departureTime: string;
  distanceMeters: number;
}

export interface DepartureSourceRecord {
  tripId: string;
  directionId: number;
  headsign: string | null;
  /** HH:mm:ss en la parada (salida base del trip). */
  stopDepartureTime: string;
  /** HH:mm:ss inicio de ventana de frequencies. */
  startTime: string;
  /** HH:mm:ss fin de ventana de frequencies. */
  endTime: string;
  headwaySeconds: number;
}
