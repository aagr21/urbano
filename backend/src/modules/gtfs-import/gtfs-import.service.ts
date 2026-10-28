import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource, EntityManager } from 'typeorm';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { parse } from 'csv-parse/sync';
import { Agency } from './entities/agency.entity';
import { FeedInfo } from './entities/feed-info.entity';
import { Frequency } from './entities/frequency.entity';
import { Route } from './entities/route.entity';
import { Service } from './entities/service.entity';
import { Shape } from './entities/shape.entity';
import { StopTime } from './entities/stop-time.entity';
import { Stop } from './entities/stop.entity';
import { Trip } from './entities/trip.entity';
import { GtfsRow, GtfsZipReader, gtfs } from './gtfs-zip.reader';

export interface ImportSummary {
  durationMs: number;
  counts: Record<string, number>;
}

const BATCH_SIZE = 5000;

interface ShapePoint {
  lat: number;
  lon: number;
}

/**
 * Importador GTFS: lee el zip en streaming, TRUNCATEa las tablas e inserta
 * todo en UNA transacción con bulk inserts por lotes.
 */
@Injectable()
export class GtfsImportService {
  private readonly logger = new Logger(GtfsImportService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async import(zipPath: string): Promise<ImportSummary> {
    const startedAt = Date.now();
    const reader = await GtfsZipReader.open(zipPath);
    this.logger.log(`Importando GTFS desde ${zipPath}`);

    const shapePoints = new Map<string, ShapePoint[]>();
    const counts: Record<string, number> = {};

    await this.dataSource.transaction(async (manager) => {
      await this.truncate(manager);
      counts.agency = await this.importAgency(manager, reader);
      counts.service = await this.importCalendar(manager, reader);
      counts.feedInfo = await this.importFeedInfo(manager, reader);
      counts.routes = await this.importRoutes(manager, reader);
      counts.stops = await this.importStops(manager, reader);
      counts.trips = await this.importTrips(manager, reader);
      counts.stopTimes = await this.importStopTimes(manager, reader);
      counts.shapes = await this.importShapes(manager, reader, shapePoints);
      counts.frequencies = await this.importFrequencies(manager, reader);
      await this.deriveRouteCounts(manager);
    });

    // Geometrías e índices espaciales fuera de la transacción de inserción
    await this.populateStopGeometry();
    await this.populateShapeGeometry();

    counts.microsImages = await this.applyMicrosImages();

    const durationMs = Date.now() - startedAt;
    this.logger.log(
      `Importación completada en ${durationMs} ms: ` +
        Object.entries(counts)
          .map(([k, v]) => `${k}=${v}`)
          .join(', '),
    );
    return { durationMs, counts };
  }

  private async truncate(manager: EntityManager): Promise<void> {
    await manager.query(
      `TRUNCATE TABLE frequency, stop_time, trip, shape, stop, route, feed_info, service, agency RESTART IDENTITY CASCADE`,
    );
  }

  private async importAgency(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<number> {
    const rows: Agency[] = [];
    for await (const row of reader.rows('agency.txt')) {
      rows.push({
        id: gtfs.str(row, 'agency_id') || 'default',
        name: gtfs.str(row, 'agency_name'),
        url: gtfs.nullableStr(row, 'agency_url'),
        timezone: gtfs.nullableStr(row, 'agency_timezone'),
        lang: gtfs.nullableStr(row, 'agency_lang'),
      });
    }
    if (rows.length > 0) {
      await manager.insert(Agency, rows);
    }
    return rows.length;
  }

  private async importCalendar(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<number> {
    const rows: Service[] = [];
    for await (const row of reader.rows('calendar.txt')) {
      rows.push({
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
      });
    }
    if (rows.length > 0) {
      await manager.insert(Service, rows);
    }
    return rows.length;
  }

  private async importFeedInfo(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<number> {
    const rows: FeedInfo[] = [];
    let id = 1;
    try {
      for await (const row of reader.rows('feed_info.txt')) {
        rows.push({
          id: id++,
          publisherName: gtfs.nullableStr(row, 'feed_publisher_name'),
          publisherUrl: gtfs.nullableStr(row, 'feed_publisher_url'),
          lang: gtfs.nullableStr(row, 'feed_lang'),
          startDate: gtfs.nullableStr(row, 'feed_start_date'),
          endDate: gtfs.nullableStr(row, 'feed_end_date'),
          version: gtfs.nullableStr(row, 'feed_version'),
        });
      }
    } catch {
      this.logger.warn('feed_info.txt no presente en el zip; se omite');
      return 0;
    }
    if (rows.length > 0) {
      await manager.insert(FeedInfo, rows);
    }
    return rows.length;
  }

  private async importRoutes(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<number> {
    let count = 0;
    let batch: Route[] = [];
    for await (const row of reader.rows('routes.txt')) {
      batch.push({
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
      });
      if (batch.length >= BATCH_SIZE) {
        await manager.insert(Route, batch);
        count += batch.length;
        batch = [];
      }
    }
    if (batch.length > 0) {
      await manager.insert(Route, batch);
      count += batch.length;
    }
    return count;
  }

  private async importStops(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<number> {
    let count = 0;
    let batch: Stop[] = [];
    for await (const row of reader.rows('stops.txt')) {
      batch.push({
        id: gtfs.str(row, 'stop_id'),
        code: gtfs.nullableStr(row, 'stop_code'),
        name: gtfs.str(row, 'stop_name'),
        description: gtfs.nullableStr(row, 'stop_desc'),
        lat: gtfs.num(row, 'stop_lat'),
        lon: gtfs.num(row, 'stop_lon'),
        geom: null,
      });
      if (batch.length >= BATCH_SIZE) {
        await manager.insert(Stop, batch);
        count += batch.length;
        batch = [];
      }
    }
    if (batch.length > 0) {
      await manager.insert(Stop, batch);
      count += batch.length;
    }
    return count;
  }

  private async importTrips(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<number> {
    let count = 0;
    let batch: Trip[] = [];
    for await (const row of reader.rows('trips.txt')) {
      batch.push({
        id: gtfs.str(row, 'trip_id'),
        routeId: gtfs.str(row, 'route_id'),
        serviceId: gtfs.str(row, 'service_id'),
        headsign: gtfs.nullableStr(row, 'trip_headsign'),
        directionId: gtfs.int01(row, 'direction_id'),
        shapeId: gtfs.nullableStr(row, 'shape_id'),
        wheelchairBoarding: gtfs.int01(row, 'wheelchair_boarding'),
      });
      if (batch.length >= BATCH_SIZE) {
        await manager.insert(Trip, batch);
        count += batch.length;
        batch = [];
      }
    }
    if (batch.length > 0) {
      await manager.insert(Trip, batch);
      count += batch.length;
    }
    return count;
  }

  private async importStopTimes(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<number> {
    let count = 0;
    let batch: StopTime[] = [];
    for await (const row of reader.rows('stop_times.txt')) {
      batch.push({
        tripId: gtfs.str(row, 'trip_id'),
        stopSequence: gtfs.int01(row, 'stop_sequence'),
        stopId: gtfs.str(row, 'stop_id'),
        arrivalTime: gtfs.str(row, 'arrival_time'),
        departureTime: gtfs.str(row, 'departure_time'),
        pickupType: gtfs.int01(row, 'pickup_type'),
        dropOffType: gtfs.int01(row, 'drop_off_type'),
        shapeDistTraveled: gtfs.nullableNum(row, 'shape_dist_traveled'),
      });
      if (batch.length >= BATCH_SIZE) {
        await manager.insert(StopTime, batch);
        count += batch.length;
        batch = [];
      }
    }
    if (batch.length > 0) {
      await manager.insert(StopTime, batch);
      count += batch.length;
    }
    return count;
  }

  /**
   * shapes.txt agrupado por shape_id en memoria (130k puntos es manejable).
   * Guarda coordinates jsonb + bbox; el geom PostGIS se populatea después.
   */
  private async importShapes(
    manager: EntityManager,
    reader: GtfsZipReader,
    shapePoints: Map<string, ShapePoint[]>,
  ): Promise<number> {
    for await (const row of reader.rows('shapes.txt')) {
      const shapeId = gtfs.str(row, 'shape_id');
      const point: ShapePoint = {
        lat: gtfs.num(row, 'shape_pt_lat'),
        lon: gtfs.num(row, 'shape_pt_lon'),
      };
      const list = shapePoints.get(shapeId);
      if (list) {
        list.push(point);
      } else {
        shapePoints.set(shapeId, [point]);
      }
    }

    const rows: Shape[] = [];
    for (const [shapeId, points] of shapePoints) {
      // shapes.txt ya viene ordenado por sequence; por las dudas ordenamos
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
    if (rows.length > 0) {
      await manager.insert(Shape, rows);
    }
    return rows.length;
  }

  private async importFrequencies(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<number> {
    type FrequencyInsert = Omit<Frequency, 'id'>;
    let count = 0;
    let batch: FrequencyInsert[] = [];
    for await (const row of reader.rows('frequencies.txt')) {
      batch.push({
        tripId: gtfs.str(row, 'trip_id'),
        startTime: gtfs.str(row, 'start_time'),
        endTime: gtfs.str(row, 'end_time'),
        headwaySeconds: gtfs.int01(row, 'headway_secs'),
        exactTimes: gtfs.int01(row, 'exact_times'),
      });
      if (batch.length >= BATCH_SIZE) {
        await manager.insert(Frequency, batch);
        count += batch.length;
        batch = [];
      }
    }
    if (batch.length > 0) {
      await manager.insert(Frequency, batch);
      count += batch.length;
    }
    return count;
  }

  /**
   * Asigna imageUrl a las rutas desde micros.csv (columnas name,url).
   * La clave es route_short_name; el CSV del feed actual trae los 154
   * short_names exactos. Idempotente: solo UPDATE, no TRUNCATEa nada.
   */
  async applyMicrosImages(): Promise<number> {
    const csvPath = resolve(process.cwd(), 'micros.csv');
    if (!existsSync(csvPath)) {
      this.logger.warn(`micros.csv no presente en ${csvPath}; sin imágenes`);
      return 0;
    }
    const rows = parse(readFileSync(csvPath, 'utf8'), {
      columns: true,
      skip_empty_lines: true,
    }) as Array<{ name?: string; url?: string }>;

    let assigned = 0;
    for (const row of rows) {
      const name = row.name?.trim();
      const url = row.url?.trim();
      if (!name || !url) continue;
      await this.dataSource
        .createQueryBuilder()
        .update(Route)
        .set({ imageUrl: url })
        .where('route_short_name = :name', { name })
        .execute();
      assigned += 1;
    }
    this.logger.log(
      `micros.csv: ${assigned} imágenes asignadas por route_short_name`,
    );
    return assigned;
  }

  /** Deriva stopCount / directions / tripCount por ruta. */
  private async deriveRouteCounts(manager: EntityManager): Promise<void> {
    await manager.query(`
      UPDATE route r SET
        stop_count = sub.stop_count,
        directions = sub.directions,
        trip_count = sub.trip_count
      FROM (
        SELECT t.route_id,
               COUNT(DISTINCT st.stop_id)::int AS stop_count,
               COUNT(DISTINCT t.direction_id)::int AS directions,
               COUNT(DISTINCT t.trip_id)::int AS trip_count
        FROM trip t
        LEFT JOIN stop_time st ON st.trip_id = t.trip_id
        GROUP BY t.route_id
      ) sub
      WHERE r.route_id = sub.route_id
    `);
  }

  /** Popula stop.geom (geography Point) desde lat/lon planos. */
  private async populateStopGeometry(): Promise<void> {
    const result = await this.dataSource.query(
      `UPDATE stop SET geom = ST_SetSRID(ST_MakePoint(stop_lon, stop_lat), 4326)::geography
       WHERE geom IS NULL`,
    );
    this.logger.log(`stop.geom populada en ${result[1] ?? '?'} filas`);
  }

  /** Popula shape.geom (geometry LineString) desde coordinates jsonb. */
  private async populateShapeGeometry(): Promise<void> {
    await this.dataSource.query(`
      UPDATE shape
      SET geom = ST_SetSRID(
        ST_MakeLine(
          ARRAY(
            SELECT ST_MakePoint((c->>0)::float8, (c->>1)::float8)
            FROM jsonb_array_elements(coordinates) WITH ORDINALITY AS t(c, ord)
            ORDER BY ord
          )
        ), 4326)
      WHERE geom IS NULL AND coordinates IS NOT NULL
    `);
  }
}
