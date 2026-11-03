import { Injectable, Logger } from '@nestjs/common';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { parse } from 'csv-parse/sync';
import { GtfsImportRepository } from './gtfs-import.repository';

interface MicrosCatalogueRow {
  name?: string;
  url?: string;
}

/**
 * Fotos de las líneas: asigna `route.image_url` desde `micros.csv` (columnas
 * `name,url`), con match por `route_short_name`.
 *
 * Vive aparte de la importación GTFS porque es otra fuente (un CSV del
 * proyecto, no el zip del feed) y se puede correr sola:
 * `npm run import:micros-images`.
 */
@Injectable()
export class MicrosImagesService {
  private readonly logger = new Logger(MicrosImagesService.name);

  constructor(private readonly repository: GtfsImportRepository) {}

  /** Asigna las imágenes y devuelve cuántas quedaron puestas. */
  async apply(): Promise<number> {
    const rows = this.readCatalogue();
    if (rows === null) return 0;

    let assigned = 0;
    for (const { name, url } of rows) {
      if (!name || !url) continue;
      await this.repository.assignRouteImage(name, url);
      assigned += 1;
    }
    this.logger.log(
      `micros.csv: ${assigned} imágenes asignadas por route_short_name`,
    );
    return assigned;
  }

  /** Lee `micros.csv`; `null` cuando el archivo no está (sesión sin fotos). */
  private readCatalogue(): Array<{ name: string; url: string }> | null {
    const csvPath = resolve(process.cwd(), 'micros.csv');
    if (!existsSync(csvPath)) {
      this.logger.warn(`micros.csv no presente en ${csvPath}; sin imágenes`);
      return null;
    }
    const rows = parse(readFileSync(csvPath, 'utf8'), {
      columns: true,
      skip_empty_lines: true,
    }) as MicrosCatalogueRow[];

    return rows
      .map((row) => ({ name: row.name?.trim() ?? '', url: row.url?.trim() ?? '' }))
      .filter((row) => row.name !== '' && row.url !== '');
  }
}
