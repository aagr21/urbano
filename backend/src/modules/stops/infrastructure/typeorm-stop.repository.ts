import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { ROUTE_NATURAL_ORDER_COLUMNS } from '../../../core/common/utils/route-order';
import {
  NearbyQuery,
  RouteRef,
  StopDetail,
  StopNearby,
  StopNearbyPage,
  StopRepositoryPort,
  StopSearchPage,
  StopWithRoutes,
} from '../domain/stop.model';

interface RouteRow {
  stopId: string;
  id: string;
  shortName: string;
  color: string | null;
  longName: string | null;
  imageUrl: string | null;
  /** Postgres devuelve `int[]`; node-postgres puede traer números o strings. */
  directionIds: Array<number | string> | null;
}

/**
 * Implementación TypeORM/PostGIS del puerto de paradas.
 * nearby usa ST_DWithin/ST_Distance sobre geography(Point,4326) con índice GIST.
 */
@Injectable()
export class TypeOrmStopRepository implements StopRepositoryPort {
  constructor(@InjectDataSource() private readonly dataSource: DataSource) {}

  async findNearby(query: NearbyQuery): Promise<StopNearbyPage> {
    const rows: Array<{
      id: string;
      code: string | null;
      name: string;
      lat: number;
      lon: number;
      distanceMeters: number;
    }> = await this.dataSource.query(
      `SELECT s.stop_id AS id,
              s.stop_code AS code,
              s.stop_name AS name,
              s.stop_lat AS lat,
              s.stop_lon AS lon,
              ST_Distance(
                s.geom,
                ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
              ) AS "distanceMeters"
       FROM stop s
       WHERE s.geom IS NOT NULL
         AND ST_DWithin(
               s.geom,
               ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
               $3
             )
       ORDER BY "distanceMeters" ASC
       LIMIT $4`,
      [query.lat, query.lon, query.radiusMeters, query.limit]
    );

    const total = await this.countNearby(query);
    const routesByStop = await this.routesForStops(rows.map((r) => r.id));

    const items: StopNearby[] = rows.map((row) => ({
      id: row.id,
      code: row.code,
      name: row.name,
      lat: row.lat,
      lon: row.lon,
      distanceMeters: Number(Number(row.distanceMeters).toFixed(1)),
      routes: routesByStop.get(row.id) ?? [],
    }));
    return { items, total };
  }

  private async countNearby(query: NearbyQuery): Promise<number> {
    const rows: Array<{ count: string }> = await this.dataSource.query(
      `SELECT COUNT(*)::text AS count
       FROM stop s
       WHERE s.geom IS NOT NULL
         AND ST_DWithin(
               s.geom,
               ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography,
               $3
             )`,
      [query.lat, query.lon, query.radiusMeters]
    );
    return Number(rows[0]?.count ?? 0);
  }

  async search(q: string, limit: number): Promise<StopSearchPage> {
    const like = `%${q.toLowerCase()}%`;
    const rows: Array<{
      id: string;
      code: string | null;
      name: string;
      lat: number;
      lon: number;
    }> = await this.dataSource.query(
      `SELECT s.stop_id AS id,
              s.stop_code AS code,
              s.stop_name AS name,
              s.stop_lat AS lat,
              s.stop_lon AS lon
       FROM stop s
       WHERE LOWER(s.stop_name) LIKE $1 OR LOWER(s.stop_id) LIKE $1
       ORDER BY
         CASE WHEN LOWER(s.stop_id) = $2 THEN 0
              WHEN LOWER(s.stop_name) LIKE $3 THEN 1
              ELSE 2 END,
         s.stop_name ASC,
         s.stop_id ASC
       LIMIT $4`,
      [like, q.toLowerCase(), `${q.toLowerCase()}%`, limit]
    );

    const totalRows: Array<{ count: string }> = await this.dataSource.query(
      `SELECT COUNT(*)::text AS count
       FROM stop s
       WHERE LOWER(s.stop_name) LIKE $1 OR LOWER(s.stop_id) LIKE $1`,
      [like]
    );

    const routesByStop = await this.routesForStops(rows.map((r) => r.id));
    const items: StopWithRoutes[] = rows.map((row) => ({
      ...row,
      routes: routesByStop.get(row.id) ?? [],
    }));
    return { items, total: Number(totalRows[0]?.count ?? 0) };
  }

  async findById(id: string): Promise<StopDetail | null> {
    const rows: Array<{
      id: string;
      code: string | null;
      name: string;
      lat: number;
      lon: number;
    }> = await this.dataSource.query(
      `SELECT s.stop_id AS id,
              s.stop_code AS code,
              s.stop_name AS name,
              s.stop_lat AS lat,
              s.stop_lon AS lon
       FROM stop s
       WHERE s.stop_id = $1`,
      [id]
    );
    if (rows.length === 0) return null;

    const routesByStop = await this.routesForStops([id]);
    const row = rows[0];
    return {
      id: row.id,
      code: row.code,
      name: row.name,
      lat: row.lat,
      lon: row.lon,
      routes: routesByStop.get(id) ?? [],
      location: { type: 'Point', coordinates: [row.lon, row.lat] },
    };
  }

  /**
   * Rutas que sirven cada parada, agrupadas por stop_id (una sola query).
   *
   * Se agrupa (y no `SELECT DISTINCT`) para poder traer los **sentidos reales**
   * de cada línea en ESA parada: un micro puede parar aquí solo en la ida. Sin
   * el `array_agg` el listado de lugares no tiene forma de decirlo y toca
   * pagar un `/routes/:id` por línea visible (N+1). `longName`/`imageUrl`
   * vienen en la misma vuelta para que la tarjeta muestre trayecto y foto.
   */
  private async routesForStops(
    stopIds: string[]
  ): Promise<Map<string, RouteRef[]>> {
    const map = new Map<string, RouteRef[]>();
    if (stopIds.length === 0) return map;

    const rows: RouteRow[] = await this.dataSource.query(
      `SELECT st.stop_id AS "stopId",
              r.route_id AS id,
              r.route_short_name AS "shortName",
              r.route_color AS color,
              r.route_long_name AS "longName",
              r.image_url AS "imageUrl",
              ARRAY_AGG(DISTINCT t.direction_id)::int[] AS "directionIds",
              MIN(${ROUTE_NATURAL_ORDER_COLUMNS[0]}) AS "sortNumber",
              MIN(${ROUTE_NATURAL_ORDER_COLUMNS[1]}) AS "sortSuffix"
       FROM stop_time st
       JOIN trip t ON t.trip_id = st.trip_id
       JOIN route r ON r.route_id = t.route_id
       WHERE st.stop_id = ANY($1)
       GROUP BY st.stop_id,
                r.route_id,
                r.route_short_name,
                r.route_color,
                r.route_long_name,
                r.image_url
       ORDER BY "sortNumber" ASC, "sortSuffix" ASC, ${ROUTE_NATURAL_ORDER_COLUMNS[2]} ASC, r.route_id ASC`,
      [stopIds]
    );
    for (const row of rows) {
      const list = map.get(row.stopId);
      const ref: RouteRef = {
        id: row.id,
        shortName: row.shortName,
        color: row.color,
        longName: row.longName,
        imageUrl: row.imageUrl,
        directionIds: [...new Set((row.directionIds ?? []).map(Number))].sort(),
      };
      if (list) {
        list.push(ref);
      } else {
        map.set(row.stopId, [ref]);
      }
    }
    return map;
  }
}
