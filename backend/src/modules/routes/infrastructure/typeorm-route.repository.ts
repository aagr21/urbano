import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { Route } from '../../gtfs-import/entities/route.entity';
import { ROUTE_NATURAL_ORDER_COLUMNS } from '../../../core/common/utils/route-order';
import { RouteRepositoryPort } from '../domain/route.repository.port';
import {
  DepartureSourceRecord,
  RouteDetailRecord,
  RoutePage,
  RouteQuery,
  RouteStopRecord,
  RouteSummary,
} from '../domain/route.model';

const SORT_COLUMNS: Record<RouteQuery['sort'], string> = {
  name: 'r.route_short_name',
  shortName: 'r.route_short_name',
  longName: 'r.route_long_name',
  stopCount: 'r.stop_count',
};

/** Sorts por línea (no por longitud ni paradas): usan orden natural. */
const NATURAL_SHORT_NAME_SORTS: ReadonlySet<RouteQuery['sort']> = new Set([
  'name',
  'shortName',
]);

/** Implementación TypeORM del puerto de rutas. */
@Injectable()
export class TypeOrmRouteRepository implements RouteRepositoryPort {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async findAll(query: RouteQuery): Promise<RoutePage> {
    // Consulta SQL directa para incluir paradas clave (keyStops) sin
    // modificar la entidad Route ni la importación GTFS.
    const sortColumn = NATURAL_SHORT_NAME_SORTS.has(query.sort)
      ? ROUTE_NATURAL_ORDER_COLUMNS.map((col) => `${col} ASC`).join(', ')
      : `${SORT_COLUMNS[query.sort] ?? 'r.route_short_name'} ASC`;

    const offset = (query.page - 1) * query.limit;

    const likePattern = query.q && query.q.trim() !== ''
      ? `AND (LOWER(r.route_short_name) LIKE '%${query.q.trim().toLowerCase()}%' OR LOWER(r.route_long_name) LIKE '%${query.q.trim().toLowerCase()}%')`
      : '';

    // Total sin paginación
    const totalResult = await this.dataSource.query(`
      SELECT COUNT(*)::int AS total FROM route r
      WHERE 1=1 ${likePattern}
    `);
    const total = Number(totalResult[0]?.total ?? 0);

    // Items con paradas clave — las primeras 3 paradas distintas por
    // orden de secuencia de la dirección 0 (ida).
    // jsonb_agg con LIMIT en la consulta externa no funciona en PG,
    // así que usamos un array slice en Node.
    const rows = await this.dataSource.query(`
      SELECT r.route_id AS "id",
             r.route_short_name AS "shortName",
             r.route_long_name AS "longName",
             r.route_color AS "color",
             r.route_text_color AS "textColor",
             r.route_desc AS "description",
             r.route_type AS "type",
             r.directions AS "directions",
             r.stop_count AS "stopCount",
             r.trip_count AS "tripCount",
             r.image_url AS "imageUrl",
             (SELECT jsonb_agg(sub.stop_name ORDER BY sub.first_seq)
              FROM (
                SELECT s.stop_name,
                       MIN(st.stop_sequence) AS first_seq
                FROM trip t
                JOIN stop_time st ON st.trip_id = t.trip_id
                JOIN stop s ON s.stop_id = st.stop_id
                WHERE t.route_id = r.route_id
                  AND t.direction_id = 0
                GROUP BY s.stop_name
              ) sub
             ) AS "keyStops"
      FROM route r
      WHERE 1=1 ${likePattern}
      ORDER BY ${sortColumn}, r.route_id ASC
      LIMIT $1 OFFSET $2
    `, [query.limit, offset]);

    return {
      items: rows.map((row: any) => ({
        id: row.id,
        shortName: row.shortName,
        longName: row.longName,
        color: row.color,
        textColor: row.textColor,
        description: row.description,
        type: row.type,
        directions: row.directions,
        stopCount: row.stopCount,
        tripCount: row.tripCount,
        imageUrl: row.imageUrl,
        // jsonb_agg devuelve todas las paradas; cortamos a 3 en Node.
        keyStops: (row.keyStops ?? []).slice(0, 3),
      })),
      total,
    };
  }

  async findById(id: string): Promise<RouteDetailRecord | null> {
    const route = await this.dataSource.getRepository(Route).findOne({ where: { id } });
    if (!route) return null;

    const directions = await this.dataSource.query(
      `SELECT t.direction_id AS "directionId",
              t.trip_headsign AS "headsign",
              t.trip_id AS "tripId",
              t.shape_id AS "shapeId",
              COALESCE(f.start_time, '06:00:00') AS "firstDeparture",
              COALESCE(f.end_time, '22:00:00') AS "lastDeparture",
              f.headway_secs AS "headwaySeconds",
              (SELECT COUNT(*)::int FROM stop_time st WHERE st.trip_id = t.trip_id) AS "stopCount"
       FROM trip t
       LEFT JOIN frequency f ON f.trip_id = t.trip_id
       WHERE t.route_id = $1
       ORDER BY t.direction_id ASC`,
      [id],
    );

    const shapeIds = directions
      .map((d: { shapeId: string | null }) => d.shapeId)
      .filter((v: string | null): v is string => Boolean(v));

    const shapes: RouteDetailRecord['shapes'] = {};
    if (shapeIds.length > 0) {
      const shapeRows: Array<{
        shapeId: string;
        coordinates: Array<[number, number]>;
        bboxMinLon: number;
        bboxMinLat: number;
        bboxMaxLon: number;
        bboxMaxLat: number;
      }> = await this.dataSource.query(
        `SELECT shape_id AS "shapeId",
                coordinates,
                bbox_min_lon AS "bboxMinLon",
                bbox_min_lat AS "bboxMinLat",
                bbox_max_lon AS "bboxMaxLon",
                bbox_max_lat AS "bboxMaxLat"
         FROM shape
         WHERE shape_id = ANY($1)`,
        [shapeIds],
      );
      for (const row of shapeRows) {
        shapes[row.shapeId] = {
          coordinates: row.coordinates,
          bbox: [row.bboxMinLon, row.bboxMinLat, row.bboxMaxLon, row.bboxMaxLat],
        };
      }
    }

    return {
      ...toSummary(route),
      directions: directions.map(
        (d: {
          directionId: number;
          headsign: string | null;
          tripId: string;
          shapeId: string | null;
          firstDeparture: string;
          lastDeparture: string;
          headwaySeconds: number | null;
          stopCount: number;
        }) => ({
          directionId: d.directionId,
          headsign: d.headsign,
          tripId: d.tripId,
          shapeId: d.shapeId,
          firstDeparture: d.firstDeparture,
          lastDeparture: d.lastDeparture,
          headwaySeconds: d.headwaySeconds,
          stopCount: d.stopCount,
        }),
      ),
      shapes,
    };
  }

  async findStops(id: string, directionId: number): Promise<RouteStopRecord[]> {
    const rows: Array<{
      id: string;
      code: string | null;
      name: string;
      lat: number;
      lon: number;
      sequence: number;
      arrivalTime: string;
      departureTime: string;
      distanceMeters: number;
    }> = await this.dataSource.query(
      `SELECT s.stop_id AS id,
              s.stop_code AS code,
              s.stop_name AS name,
              s.stop_lat AS lat,
              s.stop_lon AS lon,
              st.stop_sequence AS sequence,
              st.arrival_time AS "arrivalTime",
              st.departure_time AS "departureTime",
              COALESCE(st.shape_dist_traveled, 0) AS "distanceMeters"
       FROM trip t
       JOIN stop_time st ON st.trip_id = t.trip_id
       JOIN stop s ON s.stop_id = st.stop_id
       WHERE t.route_id = $1 AND t.direction_id = $2
       ORDER BY st.stop_sequence ASC`,
      [id, directionId],
    );
    return rows;
  }

  async findDepartureSources(
    id: string,
    stopId: string | null,
    directionId?: number,
  ): Promise<DepartureSourceRecord[]> {
    const rows: Array<{
      tripId: string;
      directionId: number;
      headsign: string | null;
      stopDepartureTime: string;
      startTime: string;
      endTime: string;
      headwaySeconds: number;
    }> = await this.dataSource.query(
      `SELECT t.trip_id AS "tripId",
              t.direction_id AS "directionId",
              t.trip_headsign AS "headsign",
              st.departure_time AS "stopDepartureTime",
              f.start_time AS "startTime",
              f.end_time AS "endTime",
              f.headway_secs AS "headwaySeconds"
       FROM trip t
       JOIN stop_time st ON st.trip_id = t.trip_id
       JOIN frequency f ON f.trip_id = t.trip_id
       WHERE t.route_id = $1
         AND (($2::text IS NULL AND st.stop_sequence = 1) OR st.stop_id = $2)
         AND ($3::int IS NULL OR t.direction_id = $3)
       ORDER BY t.direction_id ASC`,
      [id, stopId, directionId ?? null],
    );
    return rows;
  }
}

function toSummary(route: Route): RouteSummary {
  return {
    id: route.id,
    shortName: route.shortName,
    longName: route.longName,
    color: route.color,
    textColor: route.textColor,
    description: route.description,
    type: route.type,
    directions: route.directions,
    stopCount: route.stopCount,
    tripCount: route.tripCount,
    imageUrl: route.imageUrl,
    keyStops: [],
  };
}
