import { Client } from 'pg';

/**
 * Crea las extensiones de PostGIS y pg_trgm ANTES del arranque de Nest,
 * porque TypeORM (synchronize) genera DDL con el tipo `geography(Point,4326)`
 * que requiere la extensión instalada en la base destino.
 *
 * Se ejecuta en main.ts y en el CLI de importación GTFS, con una conexión pg cruda.
 */
export async function ensurePostgresExtensions(): Promise<void> {
  const client = new Client({
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 5432),
    user: process.env.DB_USERNAME ?? 'urbano',
    password: process.env.DB_PASSWORD ?? 'urbano',
    database: process.env.DB_DATABASE ?? 'urbano',
  });
  await client.connect();
  try {
    await client.query('CREATE EXTENSION IF NOT EXISTS postgis');
    await client.query('CREATE EXTENSION IF NOT EXISTS pg_trgm');
  } finally {
    await client.end();
  }
}
