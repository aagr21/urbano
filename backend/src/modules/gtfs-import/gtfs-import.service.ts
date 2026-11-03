import { Injectable, Logger } from '@nestjs/common';
import { EntityManager, EntityTarget } from 'typeorm';
import { Agency } from './entities/agency.entity';
import { FeedInfo } from './entities/feed-info.entity';
import { Frequency } from './entities/frequency.entity';
import { Route } from './entities/route.entity';
import { Service } from './entities/service.entity';
import { Shape } from './entities/shape.entity';
import { StopTime } from './entities/stop-time.entity';
import { Stop } from './entities/stop.entity';
import { Trip } from './entities/trip.entity';
import { GtfsImportRepository } from './gtfs-import.repository';
import {
  buildShapeRows,
  mappedRows,
  readShapePoints,
  rowMappers,
} from './gtfs-row-mappers';
import { GtfsRow, GtfsZipReader } from './gtfs-zip.reader';
import { MicrosImagesService } from './micros-images.service';

export interface ImportSummary {
  durationMs: number;
  counts: Record<string, number>;
}

/**
 * Importador GTFS: lee el zip en streaming, TRUNCATEa las tablas e inserta
 * todo en UNA transacción con bulk inserts por lotes.
 *
 * Solo orquesta: los mapeos fila→entidad son puros (`gtfs-row-mappers.ts`), el
 * SQL vive en [GtfsImportRepository] y las fotos de las líneas en
 * [MicrosImagesService]. Cada tabla es un método corto de este servicio.
 */
@Injectable()
export class GtfsImportService {
  private readonly logger = new Logger(GtfsImportService.name);

  constructor(
    private readonly repository: GtfsImportRepository,
    private readonly microsImages: MicrosImagesService,
  ) {}

  async import(zipPath: string): Promise<ImportSummary> {
    const startedAt = Date.now();
    const reader = await GtfsZipReader.open(zipPath);
    this.logger.log(`Importando GTFS desde ${zipPath}`);

    const counts = await this.repository.transaction((manager) =>
      this.importFeed(manager, reader),
    );

    // Geometrías e índices espaciales fuera de la transacción de inserción.
    await this.repository.populateStopGeometry();
    await this.repository.populateShapeGeometry();
    counts.microsImages = await this.microsImages.apply();

    const durationMs = Date.now() - startedAt;
    this.logSummary(durationMs, counts);
    return { durationMs, counts };
  }

  /**
   * Todas las tablas del feed en el orden que exigen las claves foráneas:
   * referencias primero, hechos después, y los conteos derivados al final.
   */
  private async importFeed(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<Record<string, number>> {
    await this.repository.truncate(manager);

    const counts: Record<string, number> = {};
    counts.agency = await this.importTable(
      manager,
      reader,
      'agency.txt',
      Agency,
      rowMappers.agency,
    );
    counts.service = await this.importTable(
      manager,
      reader,
      'calendar.txt',
      Service,
      rowMappers.service,
    );
    counts.feedInfo = await this.importFeedInfo(manager, reader);
    counts.routes = await this.importTable(
      manager,
      reader,
      'routes.txt',
      Route,
      rowMappers.route,
    );
    counts.stops = await this.importTable(
      manager,
      reader,
      'stops.txt',
      Stop,
      rowMappers.stop,
    );
    counts.trips = await this.importTable(
      manager,
      reader,
      'trips.txt',
      Trip,
      rowMappers.trip,
    );
    counts.stopTimes = await this.importTable(
      manager,
      reader,
      'stop_times.txt',
      StopTime,
      rowMappers.stopTime,
    );
    counts.shapes = await this.importShapes(manager, reader);
    counts.frequencies = await this.importTable(
      manager,
      reader,
      'frequencies.txt',
      Frequency,
      rowMappers.frequency,
    );

    await this.repository.deriveRouteCounts(manager);
    return counts;
  }

  /** Inserta un `.txt` del feed mapeando sus filas en streaming. */
  private importTable<T>(
    manager: EntityManager,
    reader: GtfsZipReader,
    fileName: string,
    entity: EntityTarget<T>,
    map: (row: GtfsRow, index: number) => T,
  ): Promise<number> {
    return this.repository.insertStream(
      manager,
      entity,
      mappedRows(reader, fileName, map),
    );
  }

  /** feed_info.txt es opcional: su ausencia no falla la importación. */
  private async importFeedInfo(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<number> {
    try {
      return await this.importTable(
        manager,
        reader,
        'feed_info.txt',
        FeedInfo,
        rowMappers.feedInfo,
      );
    } catch {
      this.logger.warn('feed_info.txt no presente en el zip; se omite');
      return 0;
    }
  }

  /** shapes.txt se agrupa por shape_id en memoria antes de insertar. */
  private async importShapes(
    manager: EntityManager,
    reader: GtfsZipReader,
  ): Promise<number> {
    const rows = buildShapeRows(await readShapePoints(reader));
    return this.repository.insertInBatches(manager, Shape, rows);
  }

  private logSummary(
    durationMs: number,
    counts: Record<string, number>,
  ): void {
    this.logger.log(
      `Importación completada en ${durationMs} ms: ` +
        Object.entries(counts)
          .map(([key, value]) => `${key}=${value}`)
          .join(', '),
    );
  }
}
