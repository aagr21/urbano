import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../../app.module';
import { GtfsImportService } from './gtfs-import.service';

/**
 * CLI de imágenes de micros: npm run import:micros-images
 * No repele la importación GTFS: solo asigna route.image_url desde
 * micros.csv (match por route_short_name). Es idempotente.
 */
async function main(): Promise<void> {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['log', 'warn', 'error'],
  });
  try {
    const importer = app.get(GtfsImportService);
    const assigned = await importer.applyMicrosImages();
    // eslint-disable-next-line no-console
    console.log(`\nImágenes de micros asignadas: ${assigned}\n`);
  } finally {
    await app.close();
  }
}

main().catch((error) => {
  // eslint-disable-next-line no-console
  console.error('Error asignando imágenes de micros:', error);
  process.exit(1);
});
