import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DataSource } from 'typeorm';

/**
 * Ajustes de esquema que TypeORM no modela bien:
 *  - tipomod de columnas espaciales (geography(Point,4326) / geometry(LineString,4326))
 *  - índices GIST espaciales, GIN pg_trgm para búsqueda y B-tree de apoyo
 *
 * Todo idempotente (se ejecuta en cada arranque).
 */
@Injectable()
export class DatabaseSetupService implements OnModuleInit {
  private readonly logger = new Logger(DatabaseSetupService.name);

  constructor(private readonly dataSource: DataSource) {}

  async onModuleInit(): Promise<void> {
    await this.ensureSpatialTypmods();
    await this.createIndexes();
  }

  private async ensureSpatialTypmods(): Promise<void> {
    await this.ensureTypmod('stop', 'geom', 'geography(Point,4326)');
    await this.ensureTypmod('shape', 'geom', 'geometry(LineString,4326)');
  }

  private async ensureTypmod(table: string, column: string, target: string): Promise<void> {
    const rows: Array<{ current: string | null }> = await this.dataSource.query(
      `SELECT pg_catalog.format_type(a.atttypid, a.atttypmod) AS current
       FROM pg_catalog.pg_attribute a
       WHERE a.attrelid = to_regclass($1)
         AND a.attname = $2
         AND NOT a.attisdropped`,
      [table, column],
    );
    if (rows.length === 0) {
      // Tabla todavía no existe (primera ejecución sin synchronize) — nada que hacer
      return;
    }
    if (rows[0].current === target) {
      return;
    }
    this.logger.log(`Ajustando ${table}.${column}: ${rows[0].current} → ${target}`);
    await this.dataSource.query(
      `ALTER TABLE "${table}" ALTER COLUMN "${column}" TYPE ${target} USING "${column}"::${target}`,
    );
  }

  private async createIndexes(): Promise<void> {
    const statements = [
      // Espaciales (nearby, bbox): índice GIST
      'CREATE INDEX IF NOT EXISTS idx_stop_geom ON stop USING GIST (geom)',
      'CREATE INDEX IF NOT EXISTS idx_shape_geom ON shape USING GIST (geom)',
      // Búsqueda textual: pg_trgm (ILIKE '%q%') + B-tree para ordenamiento
      'CREATE INDEX IF NOT EXISTS idx_route_short_name_trgm ON route USING GIN (route_short_name gin_trgm_ops)',
      'CREATE INDEX IF NOT EXISTS idx_route_long_name_trgm ON route USING GIN (route_long_name gin_trgm_ops)',
      'CREATE INDEX IF NOT EXISTS idx_route_short_name ON route (route_short_name)',
      'CREATE INDEX IF NOT EXISTS idx_route_long_name ON route (route_long_name)',
      'CREATE INDEX IF NOT EXISTS idx_stop_name ON stop (stop_name)',
      'CREATE INDEX IF NOT EXISTS idx_stop_name_trgm ON stop USING GIN (stop_name gin_trgm_ops)',
      'CREATE INDEX IF NOT EXISTS idx_stop_lat_lon ON stop (stop_lat, stop_lon)',
      // Navegación GTFS
      'CREATE INDEX IF NOT EXISTS idx_stop_time_trip_seq ON stop_time (trip_id, stop_sequence)',
      'CREATE INDEX IF NOT EXISTS idx_stop_time_stop ON stop_time (stop_id)',
      'CREATE INDEX IF NOT EXISTS idx_trip_route ON trip (route_id, direction_id)',
      'CREATE INDEX IF NOT EXISTS idx_trip_shape ON trip (shape_id)',
      'CREATE INDEX IF NOT EXISTS idx_frequency_trip ON frequency (trip_id)',
    ];
    for (const statement of statements) {
      try {
        await this.dataSource.query(statement);
      } catch (error: unknown) {
        // IF NOT EXISTS no es atómico: si dos procesos crean el mismo índice a la
        // vez, Postgres puede lanzar unique_violation en pg_class. Es seguro
        // ignorarlo (el índice ya existe o lo creará el otro proceso).
        const code = (error as { code?: string } | null)?.code;
        if (code !== '23505' && code !== '42P07' && code !== '42710') {
          throw error;
        }
        this.logger.debug(`Índice ya creado por otra sesión: ${statement}`);
      }
    }
  }
}
