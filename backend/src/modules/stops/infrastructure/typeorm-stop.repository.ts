import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
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
}

/**
 * Implementación TypeORM/PostGIS del puerto de paradas.
 * nearby usa ST_DWithin/ST_Distance sobre geography(Point,4326) con índice GIST.
 */
@Injectable()
export class TypeOrmStopRepository implements StopRepositoryPort {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

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
      [query.lat, query.lon, query.radiusMeters, query.limit],
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
      [query.lat, query.lon, query.radiusMeters],
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
      [like, q.toLowerCase(), `${q.toLowerCase()}%`, limit],
    );

    const totalRows: Array<{ count: string }> = await this.dataSource.query(
      `SELECT COUNT(*)::text AS count
       FROM stop s
       WHERE LOWER(s.stop_name) LIKE $1 OR LOWER(s.stop_id) LIKE $1`,
      [like],
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
      [id],
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

  /** Rutas que sirven cada parada, agrupadas por stop_id (una sola query). */
  private async routesForStops(stopIds: string[]): Promise<Map<string, RouteRef[]>> {
    const map = new Map<string, RouteRef[]>();
    if (stopIds.length === 0) return map;

    const rows: RouteRow[] = await this.dataSource.query(
      `SELECT DISTINCT st.stop_id AS "stopId",
              r.route_id AS id,
              r.route_short_name AS "shortName",
              r.route_color AS color
       FROM stop_time st
       JOIN trip t ON t.trip_id = st.trip_id
       JOIN route r ON r.route_id = t.route_id
       WHERE st.stop_id = ANY($1)
       ORDER BY r.route_short_name ASC`,
      [stopIds],
    );
    for (const row of rows) {
      const list = map.get(row.stopId);
      const ref: RouteRef = {
        id: row.id,
        shortName: row.shortName,
        color: row.color,
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
