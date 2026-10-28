import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { timeToSeconds } from '../../../core/common/utils/gtfs-time';
import { CandidateStop, StopRef, TripSchedule } from '../domain/journey.model';
import {
  JourneyDataPort,
  LegDetail,
  LegDetailQuery,
} from '../domain/journey-data.port';

interface TripScheduleRow {
  tripId: string;
  routeId: string;
  routeShortName: string;
  routeColor: string | null;
  directionId: number;
  headsign: string | null;
  startTime: string;
  endTime: string;
  headwaySeconds: number | null;
  stopId: string;
  sequence: number;
  arrivalTime: string;
  departureTime: string;
}

/** Implementación TypeORM/PostGIS del puerto de datos del planeador. */
@Injectable()
export class TypeOrmJourneyData implements JourneyDataPort {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async findStopsNear(
    lat: number,
    lon: number,
    radiusMeters: number,
    limit: number,
  ): Promise<CandidateStop[]> {
    const rows: Array<{
      stopId: string;
      name: string;
      lat: number;
      lon: number;
      distanceMeters: number;
    }> = await this.dataSource.query(
      `SELECT s.stop_id AS "stopId",
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
      [lat, lon, radiusMeters, limit],
    );
    return rows.map((r) => ({
      stopId: r.stopId,
      name: r.name,
      lat: r.lat,
      lon: r.lon,
      distanceMeters: Number(r.distanceMeters),
    }));
  }

  async findTripIdsServingStops(stopIds: string[]): Promise<string[]> {
    if (stopIds.length === 0) return [];
    const rows: Array<{ tripId: string }> = await this.dataSource.query(
      `SELECT DISTINCT st.trip_id AS "tripId"
       FROM stop_time st
       WHERE st.stop_id = ANY($1)`,
      [stopIds],
    );
    return rows.map((r) => r.tripId);
  }

  async loadTripSchedules(tripIds: string[]): Promise<TripSchedule[]> {
    if (tripIds.length === 0) return [];
    const rows: TripScheduleRow[] = await this.dataSource.query(
      `SELECT t.trip_id AS "tripId",
              t.route_id AS "routeId",
              r.route_short_name AS "routeShortName",
              r.route_color AS "routeColor",
              t.direction_id AS "directionId",
              t.trip_headsign AS headsign,
              f.start_time AS "startTime",
              f.end_time AS "endTime",
              f.headway_secs AS "headwaySeconds",
              st.stop_id AS "stopId",
              st.stop_sequence AS sequence,
              st.arrival_time AS "arrivalTime",
              st.departure_time AS "departureTime"
       FROM trip t
       JOIN route r ON r.route_id = t.route_id
       JOIN frequency f ON f.trip_id = t.trip_id
       JOIN stop_time st ON st.trip_id = t.trip_id
       WHERE t.trip_id = ANY($1)
       ORDER BY t.trip_id, st.stop_sequence ASC`,
      [tripIds],
    );

    const byTrip = new Map<string, TripSchedule>();
    for (const row of rows) {
      let trip = byTrip.get(row.tripId);
      if (!trip) {
        trip = {
          tripId: row.tripId,
          routeId: row.routeId,
          routeShortName: row.routeShortName,
          routeColor: row.routeColor,
          directionId: row.directionId,
          headsign: row.headsign,
          startTimeSec: timeToSeconds(row.startTime),
          endTimeSec: timeToSeconds(row.endTime),
          headwaySeconds: row.headwaySeconds ?? 0,
          stops: [],
        };
        byTrip.set(row.tripId, trip);
      }
      trip.stops.push({
        stopId: row.stopId,
        sequence: row.sequence,
        arrivalSec: timeToSeconds(row.arrivalTime),
        departureSec: timeToSeconds(row.departureTime),
      });
    }
    return [...byTrip.values()];
  }

  async loadLegDetails(legs: LegDetailQuery[]): Promise<LegDetail[]> {
    if (legs.length === 0) return [];

    // Una sola query para todos los tramos: trip → shape (por shape_id) y
    // stop_time/stop para las coordenadas de las paradas from/to.
    // El recorte usa ST_LineSubstring con LEAST/GREATEST de las fracciones de
    // ambas paradas (ST_LineLocatePoint), de modo que respeta el sentido de la
    // línea sin invertir nada en la aplicación.
    const rows: LegDetailRow[] = await this.dataSource.query(
      `WITH legs AS (
         SELECT *
         FROM unnest($1::text[], $2::text[], $3::text[])
              AS l(trip_id, from_stop_id, to_stop_id)
       ),
       from_seq AS (
         SELECT st.trip_id, st.stop_id, min(st.stop_sequence) AS seq
         FROM stop_time st
         JOIN legs l ON l.trip_id = st.trip_id AND l.from_stop_id = st.stop_id
         GROUP BY st.trip_id, st.stop_id
       ),
       to_seq AS (
         SELECT st.trip_id, st.stop_id, min(st.stop_sequence) AS seq
         FROM stop_time st
         JOIN legs l ON l.trip_id = st.trip_id AND l.to_stop_id = st.stop_id
         GROUP BY st.trip_id, st.stop_id
       )
       SELECT l.trip_id   AS "tripId",
              l.from_stop_id AS "fromStopId",
              l.to_stop_id   AS "toStopId",
              f.stop_name AS "fromName",
              f.stop_lat  AS "fromLat",
              f.stop_lon  AS "fromLon",
              t.stop_name AS "toName",
              t.stop_lat  AS "toLat",
              t.stop_lon  AS "toLon",
              ST_AsGeoJSON(
                oriented.segment
              ) AS geojson
       FROM legs l
       JOIN from_seq fs ON fs.trip_id = l.trip_id AND fs.stop_id = l.from_stop_id
       JOIN stop f ON f.stop_id = fs.stop_id
       JOIN to_seq ts ON ts.trip_id = l.trip_id AND ts.stop_id = l.to_stop_id
       JOIN stop t ON t.stop_id = ts.stop_id
       JOIN trip tr ON tr.trip_id = l.trip_id
       LEFT JOIN shape sh ON sh.shape_id = tr.shape_id
        CROSS JOIN LATERAL (
          SELECT
            ST_LineLocatePoint(sh.geom, ST_SetSRID(ST_MakePoint(f.stop_lon, f.stop_lat), 4326)) AS from_frac,
            ST_LineLocatePoint(sh.geom, ST_SetSRID(ST_MakePoint(t.stop_lon, t.stop_lat), 4326)) AS to_frac
        ) frac,
        LATERAL (
          SELECT CASE
            WHEN frac.from_frac <= frac.to_frac THEN
              ST_LineSubstring(sh.geom, frac.from_frac, frac.to_frac)
            ELSE
              ST_Reverse(ST_LineSubstring(sh.geom, frac.to_frac, frac.from_frac))
          END AS segment
        ) oriented`,
      [
        legs.map((l) => l.tripId),
        legs.map((l) => l.fromStopId),
        legs.map((l) => l.toStopId),
      ],
    );

    return rows.map((r) => ({
      tripId: r.tripId,
      fromStopId: r.fromStopId,
      toStopId: r.toStopId,
      fromStop: {
        id: r.fromStopId,
        name: r.fromName,
        lat: Number(r.fromLat),
        lon: Number(r.fromLon),
      },
      toStop: {
        id: r.toStopId,
        name: r.toName,
        lat: Number(r.toLat),
        lon: Number(r.toLon),
      },
      coordinates: toLineCoordinates(r.geojson),
    }));
  }

  async findStopRefs(ids: string[]): Promise<StopRef[]> {
    if (ids.length === 0) return [];
    const rows: Array<{
      id: string;
      name: string;
      lat: number;
      lon: number;
    }> = await this.dataSource.query(
      `SELECT s.stop_id AS id,
              s.stop_name AS name,
              s.stop_lat AS lat,
              s.stop_lon AS lon
       FROM stop s
       WHERE s.stop_id = ANY($1)`,
      [ids],
    );
    return rows.map((r) => ({
      id: r.id,
      name: r.name,
      lat: Number(r.lat),
      lon: Number(r.lon),
    }));
  }
}

interface LegDetailRow {
  tripId: string;
  fromStopId: string;
  toStopId: string;
  fromName: string;
  fromLat: number;
  fromLon: number;
  toName: string;
  toLat: number;
  toLon: number;
  /** GeoJSON del tramo recortado; `null` si la ruta no tiene shape. */
  geojson: string | null;
}

/**
 * Convierte el GeoJSON del tramo recortado en pares `[lon, lat]`.
 * `null` si no hay shape. Si el recorte colapsa a un punto (paradas cuya
 * proyección cae en el mismo lugar de la línea) lo devolvemos duplicado para
 * mantener un `LineString` válido de ≥2 posiciones.
 */
function toLineCoordinates(geojson: string | null): number[][] | null {
  if (!geojson) return null;
  let parsed: { type?: string; coordinates?: unknown };
  try {
    parsed = JSON.parse(geojson);
  } catch {
    return null;
  }
  const coordinates = parsed?.coordinates;
  if (!Array.isArray(coordinates) || coordinates.length === 0) return null;
  if (parsed.type === 'LineString') {
    const coords = coordinates as number[][];
    if (coords.length >= 2) return coords;
    if (coords.length === 1) return [coords[0], coords[0]];
    return null;
  }
  if (parsed.type === 'Point') {
    const point = coordinates as number[];
    return [point, point];
  }
  return null;
}
