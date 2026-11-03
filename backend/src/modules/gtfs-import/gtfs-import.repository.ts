import { Injectable, Logger } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import {
  DataSource,
  EntityManager,
  EntityTarget,
  ObjectLiteral,
  QueryDeepPartialEntity,
} from 'typeorm';
import { Route } from './entities/route.entity';

/** Filas por INSERT masivo (el driver se ahoga con lotes más grandes). */
export const BATCH_SIZE = 5000;

/**
 * Acceso a datos de la importación GTFS: TODO el TypeORM/SQL del módulo vive
 * aquí (truncate, inserts por lote, derivados y geometrías). El servicio se
 * queda con la orquestación y los mapeos puros.
 */
@Injectable()
export class GtfsImportRepository {
  private readonly logger = new Logger(GtfsImportRepository.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  /** Ejecuta [work] dentro de una transacción (una sola conexión). */
  transaction<T>(work: (manager: EntityManager) => Promise<T>): Promise<T> {
    return this.dataSource.transaction(work);
  }

  /** Vacía las tablas del feed (las dependencias caen en cascada). */
  async truncate(manager: EntityManager): Promise<void> {
    await manager.query(
      `TRUNCATE TABLE frequency, stop_time, trip, shape, stop, route, feed_info, service, agency RESTART IDENTITY CASCADE`,
    );
  }

  /** Inserta un lote ya materializado, en tandas de [BATCH_SIZE]. */
  async insertInBatches<T>(
    manager: EntityManager,
    entity: EntityTarget<T>,
    rows: T[],
  ): Promise<number> {
    let inserted = 0;
    for (let offset = 0; offset < rows.length; offset += BATCH_SIZE) {
      const batch = rows.slice(offset, offset + BATCH_SIZE);
      await this.insert(manager, entity, batch);
      inserted += batch.length;
    }
    return inserted;
  }

  /**
   * Inserta un flujo de filas SIN materializarlo (stop_times.txt ronda el
   * millón de filas), en tandas de [BATCH_SIZE].
   */
  async insertStream<T>(
    manager: EntityManager,
    entity: EntityTarget<T>,
    rows: AsyncIterable<T>,
  ): Promise<number> {
    let count = 0;
    let batch: T[] = [];
    for await (const row of rows) {
      batch.push(row);
      if (batch.length >= BATCH_SIZE) {
        await this.insert(manager, entity, batch);
        count += batch.length;
        batch = [];
      }
    }
    if (batch.length > 0) {
      await this.insert(manager, entity, batch);
      count += batch.length;
    }
    return count;
  }

  /** Deriva stopCount / directions / tripCount por ruta. */
  async deriveRouteCounts(manager: EntityManager): Promise<void> {
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
  async populateStopGeometry(): Promise<void> {
    const result = await this.dataSource.query(
      `UPDATE stop SET geom = ST_SetSRID(ST_MakePoint(stop_lon, stop_lat), 4326)::geography
       WHERE geom IS NULL`,
    );
    this.logger.log(`stop.geom populada en ${result[1] ?? '?'} filas`);
  }

  /** Popula shape.geom (geometry LineString) desde coordinates jsonb. */
  async populateShapeGeometry(): Promise<void> {
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

  /**
   * Asigna la foto de una línea por `route_short_name`. Idempotente: solo
   * UPDATE, no TRUNCATEa nada.
   */
  async assignRouteImage(shortName: string, url: string): Promise<void> {
    await this.dataSource
      .createQueryBuilder()
      .update(Route)
      .set({ imageUrl: url })
      .where('route_short_name = :name', { name: shortName })
      .execute();
  }

  private async insert<T>(
    manager: EntityManager,
    entity: EntityTarget<T>,
    batch: T[],
  ): Promise<void> {
    // TypeORM tipa `insert` contra `ObjectLiteral`; aquí el lote es homogéneo
    // y ya viene mapeado a la entidad, así que el cast queda contenido.
    await manager.insert(
      entity as EntityTarget<ObjectLiteral>,
      batch as QueryDeepPartialEntity<ObjectLiteral>[],
    );
  }
}
