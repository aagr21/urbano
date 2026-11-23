import { plainToInstance, Transform } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
  validateSync,
} from 'class-validator';

const toBoolean = ({ value }: { value: unknown }): unknown => {
  if (typeof value === 'string') {
    return value.toLowerCase() === 'true';
  }
  return value;
};

const toNumber = ({ value }: { value: unknown }): unknown => {
  if (typeof value === 'string' && value.trim() !== '') {
    return Number(value);
  }
  return value;
};

/**
 * Variables de entorno requeridas por la aplicación, validadas al arrancar.
 * Las variables de base de datos son opcionales: en entornos sin DB
 * (p. ej. Vercel sin Postgres configurada) la app arranca y responde
 * los endpoints que no necesitan persistencia.
 */
export class EnvironmentVariables {
  @IsOptional()
  @IsString()
  NODE_ENV?: string;

  @Transform(toNumber)
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(65535)
  PORT?: number;

  @IsOptional()
  @IsString()
  GTFS_FILE?: string;

  @IsOptional()
  @IsString()
  DB_HOST?: string;

  @Transform(toNumber)
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(65535)
  DB_PORT?: number;

  @IsOptional()
  @IsString()
  DB_USERNAME?: string;

  @IsOptional()
  @IsString()
  DB_PASSWORD?: string;

  @IsOptional()
  @IsString()
  DB_DATABASE?: string;

  @Transform(toBoolean)
  @IsOptional()
  @IsBoolean()
  DB_SYNCHRONIZE?: boolean;

  @Transform(toNumber)
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  DB_POOL_MAX?: number;

  @IsOptional()
  @IsString()
  CORS_ORIGINS?: string;
}

export function validateEnvironment(
  config: Record<string, unknown>
): EnvironmentVariables {
  // En Vercel serverless, config puede ser un objeto vacío si dotenv
  // no encontró .env y no fusionó process.env. Usar process.env como
  // respaldo garantiza que las variables lleguen al validador.
  const merged: Record<string, unknown> = {
    ...process.env,
    ...config,
  };
  const validated = plainToInstance(EnvironmentVariables, merged, {
    enableImplicitConversion: false,
  });
  const errors = validateSync(validated, { skipMissingProperties: false });
  if (errors.length > 0) {
    throw new Error(
      `Configuración de entorno inválida:\n${errors
        .map((e) => Object.values(e.constraints ?? {}).join(', '))
        .join('\n')}`
    );
  }
  return validated;
}
