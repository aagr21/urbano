import 'reflect-metadata';
import { existsSync } from 'fs';
import { resolve } from 'path';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../../app.module';
import { AppConfigService } from '../../core/config/app-config.service';
import { ensurePostgresExtensions } from '../../core/infrastructure/postgres-extensions';
import { GtfsImportService } from './gtfs-import.service';

/**
 * CLI de importación: npm run import:gtfs
 * Abre un application context (sin HTTP), crea extensiones PostGIS y
 * ejecuta la importación completa del zip configurado en GTFS_FILE.
 */
async function main(): Promise<void> {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['log', 'warn', 'error'],
  });
  try {
    await ensurePostgresExtensions();
    const config = app.get(AppConfigService);
    const zipPath = resolve(config.gtfsFile);
    if (!existsSync(zipPath)) {
      throw new Error(
        `No se encontró el zip GTFS en ${zipPath}. Configura GTFS_FILE en .env`,
      );
    }
    const importer = app.get(GtfsImportService);
    const summary = await importer.import(zipPath);

    // Resumen de conteos por tabla
    const rows = Object.entries(summary.counts).map(([table, count]) => ({
      table,
      count,
    }));
    // eslint-disable-next-line no-console
    console.log('\n=== Resumen de importación GTFS ===');
    // eslint-disable-next-line no-console
    console.table(rows);
    // eslint-disable-next-line no-console
    console.log(`Duración: ${(summary.durationMs / 1000).toFixed(1)} s\n`);
  } finally {
    await app.close();
  }
}

main().catch((error) => {
  // eslint-disable-next-line no-console
  console.error('Error importando GTFS:', error);
  process.exit(1);
});
