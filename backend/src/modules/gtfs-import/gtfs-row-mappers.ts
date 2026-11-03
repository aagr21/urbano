import { GtfsRow, GtfsZipReader, gtfs } from './gtfs-zip.reader';
import { Agency } from './entities/agency.entity';
import { FeedInfo } from './entities/feed-info.entity';
import { Frequency } from './entities/frequency.entity';
import { Route } from './entities/route.entity';
import { Service } from './entities/service.entity';
import { Shape } from './entities/shape.entity';
import { StopTime } from './entities/stop-time.entity';
import { Stop } from './entities/stop.entity';
import { Trip } from './entities/trip.entity';

/** Un punto de shapes.txt (coordenadas planas, sin SRID). */
export interface ShapePoint {
  lat: number;
  lon: number;
}

/** Fila de frequencies.txt lista para insertar (el id lo pone Postgres). */
type FrequencyInsert = Omit<Frequency, 'id'>;

/**
 * Mapeo PURO de fila GTFS → entidad: sin base de datos y sin zip. Cada función
 * recibe una fila ya parseada y devuelve la entidad (o el literal de insert),
 * así el servicio de importación solo orquesta y este mapeo se puede probar
 * fila a fila.
 */
export const rowMappers = {
  agency(row: GtfsRow): Agency {
    return {
      id: gtfs.str(row, 'agency_id') || 'default',
      name: gtfs.str(row, 'agency_name'),
      url: gtfs.nullableStr(row, 'agency_url'),
      timezone: gtfs.nullableStr(row, 'agency_timezone'),
      lang: gtfs.nullableStr(row, 'agency_lang'),
    };
  },

  service(row: GtfsRow): Service {
    return {
      id: gtfs.str(row, 'service_id'),
      monday: gtfs.bool01(row, 'monday'),
      tuesday: gtfs.bool01(row, 'tuesday'),
      wednesday: gtfs.bool01(row, 'wednesday'),
      thursday: gtfs.bool01(row, 'thursday'),
      friday: gtfs.bool01(row, 'friday'),
      saturday: gtfs.bool01(row, 'saturday'),
      sunday: gtfs.bool01(row, 'sunday'),
      startDate: gtfs.str(row, 'start_date'),
      endDate: gtfs.str(row, 'end_date'),
    };
  },

  /** `index` (0-based) da el id secuencial de feed_info.txt. */
  feedInfo(row: GtfsRow, index: number): FeedInfo {
    return {
      id: index + 1,
      publisherName: gtfs.nullableStr(row, 'feed_publisher_name'),
      publisherUrl: gtfs.nullableStr(row, 'feed_publisher_url'),
      lang: gtfs.nullableStr(row, 'feed_lang'),
      startDate: gtfs.nullableStr(row, 'feed_start_date'),
      endDate: gtfs.nullableStr(row, 'feed_end_date'),
      version: gtfs.nullableStr(row, 'feed_version'),
    };
  },

  route(row: GtfsRow): Route {
    return {
      id: gtfs.str(row, 'route_id'),
      agencyId: gtfs.nullableStr(row, 'agency_id'),
      shortName: gtfs.str(row, 'route_short_name'),
      longName: gtfs.nullableStr(row, 'route_long_name'),
      description: gtfs.nullableStr(row, 'route_desc'),
      type: gtfs.int01(row, 'route_type'),
      color: gtfs.nullableStr(row, 'route_color'),
      textColor: gtfs.nullableStr(row, 'route_text_color'),
      imageUrl: null,
      stopCount: 0,
      directions: 0,
      tripCount: 0,
    };
  },

  stop(row: GtfsRow): Stop {
    return {
      id: gtfs.str(row, 'stop_id'),
      code: gtfs.nullableStr(row, 'stop_code'),
      name: gtfs.str(row, 'stop_name'),
      description: gtfs.nullableStr(row, 'stop_desc'),
      lat: gtfs.num(row, 'stop_lat'),
      lon: gtfs.num(row, 'stop_lon'),
      geom: null,
    };
  },

  trip(row: GtfsRow): Trip {
    return {
      id: gtfs.str(row, 'trip_id'),
      routeId: gtfs.str(row, 'route_id'),
      serviceId: gtfs.str(row, 'service_id'),
      headsign: gtfs.nullableStr(row, 'trip_headsign'),
      directionId: gtfs.int01(row, 'direction_id'),
      shapeId: gtfs.nullableStr(row, 'shape_id'),
      wheelchairBoarding: gtfs.int01(row, 'wheelchair_boarding'),
    };
  },

  stopTime(row: GtfsRow): StopTime {
    return {
      tripId: gtfs.str(row, 'trip_id'),
      stopSequence: gtfs.int01(row, 'stop_sequence'),
      stopId: gtfs.str(row, 'stop_id'),
      arrivalTime: gtfs.str(row, 'arrival_time'),
      departureTime: gtfs.str(row, 'departure_time'),
      pickupType: gtfs.int01(row, 'pickup_type'),
      dropOffType: gtfs.int01(row, 'drop_off_type'),
      shapeDistTraveled: gtfs.nullableNum(row, 'shape_dist_traveled'),
    };
  },

  frequency(row: GtfsRow): FrequencyInsert {
    return {
      tripId: gtfs.str(row, 'trip_id'),
      startTime: gtfs.str(row, 'start_time'),
      endTime: gtfs.str(row, 'end_time'),
      headwaySeconds: gtfs.int01(row, 'headway_secs'),
      exactTimes: gtfs.int01(row, 'exact_times'),
    };
  },
};

/**
 * Itera un `.txt` del zip aplicando su mapeo, sin materializar el archivo
 * completo en memoria (stop_times.txt ronda el millón de filas).
 */
export async function* mappedRows<T>(
  reader: GtfsZipReader,
  fileName: string,
  map: (row: GtfsRow, index: number) => T,
): AsyncGenerator<T> {
  let index = 0;
  for await (const row of reader.rows(fileName)) {
    yield map(row, index++);
  }
}

/**
 * shapes.txt agrupado por shape_id en memoria (130k puntos es manejable): el
 * archivo trae un punto por fila y la tabla guarda una fila por shape.
 */
export async function readShapePoints(
  reader: GtfsZipReader,
): Promise<Map<string, ShapePoint[]>> {
  const points = new Map<string, ShapePoint[]>();
  for await (const row of reader.rows('shapes.txt')) {
    const shapeId = gtfs.str(row, 'shape_id');
    const point: ShapePoint = {
      lat: gtfs.num(row, 'shape_pt_lat'),
      lon: gtfs.num(row, 'shape_pt_lon'),
    };
    const list = points.get(shapeId);
    if (list) {
      list.push(point);
    } else {
      points.set(shapeId, [point]);
    }
  }
  return points;
}

/**
 * Filas de shape listas para insertar: coordinates jsonb `[[lon, lat], …]` +
 * bounding box derivado. El `geom` PostGIS se popula después, fuera de la
 * transacción de inserción.
 */
export function buildShapeRows(
  pointsByShape: Map<string, ShapePoint[]>,
): Shape[] {
  const rows: Shape[] = [];
  for (const [shapeId, points] of pointsByShape) {
    // shapes.txt ya viene ordenado por sequence; por las dudas se respeta el
    // orden de lectura y se calcula el bbox en la misma pasada.
    let minLon = Infinity;
    let minLat = Infinity;
    let maxLon = -Infinity;
    let maxLat = -Infinity;
    const coordinates: Array<[number, number]> = points.map((p) => {
      if (p.lon < minLon) minLon = p.lon;
      if (p.lat < minLat) minLat = p.lat;
      if (p.lon > maxLon) maxLon = p.lon;
      if (p.lat > maxLat) maxLat = p.lat;
      return [p.lon, p.lat] as [number, number];
    });
    rows.push({
      id: shapeId,
      pointCount: points.length,
      bboxMinLon: minLon,
      bboxMinLat: minLat,
      bboxMaxLon: maxLon,
      bboxMaxLat: maxLat,
      coordinates,
      geom: null,
    });
  }
  return rows;
}
