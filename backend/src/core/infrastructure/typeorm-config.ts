import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { AppConfigService } from '../config/app-config.service';
import { ALL_ENTITIES } from './entities';

/** Opciones de TypeORM derivadas del entorno validado. */
export function buildTypeOrmOptions(config: AppConfigService): TypeOrmModuleOptions {
  const db = config.database;
  return {
    type: 'postgres',
    host: db.host,
    port: db.port,
    username: db.username,
    password: db.password,
    database: db.database,
    entities: ALL_ENTITIES,
    synchronize: db.synchronize,
    logging: false,
  };
}
