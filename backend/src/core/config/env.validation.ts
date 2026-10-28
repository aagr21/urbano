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
 * Si alguna falta o es inválida el proceso no arranca (fail-fast).
 */
export class EnvironmentVariables {
  @IsOptional()
  @IsString()
  NODE_ENV?: string;

  @Transform(toNumber)
  @IsInt()
  @Min(1)
  @Max(65535)
  PORT: number;

  @IsString()
  GTFS_FILE: string;

  @IsString()
  DB_HOST: string;

  @Transform(toNumber)
  @IsInt()
  @Min(1)
  @Max(65535)
  DB_PORT: number;

  @IsString()
  DB_USERNAME: string;

  @IsString()
  DB_PASSWORD: string;

  @IsString()
  DB_DATABASE: string;

  @Transform(toBoolean)
  @IsBoolean()
  DB_SYNCHRONIZE: boolean;

  @IsOptional()
  @IsString()
  CORS_ORIGINS?: string;
}

export function validateEnvironment(
  config: Record<string, unknown>,
): EnvironmentVariables {
  const validated = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: false,
  });
  const errors = validateSync(validated, { skipMissingProperties: false });
  if (errors.length > 0) {
    throw new Error(
      `Configuración de entorno inválida:\n${errors
        .map((e) => Object.values(e.constraints ?? {}).join(', '))
        .join('\n')}`,
    );
  }
  return validated;
}
