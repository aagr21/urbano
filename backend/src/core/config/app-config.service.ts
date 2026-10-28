import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DatabaseConfig } from './config.type';

/**
 * Fachada tipada sobre ConfigService. Toda la configuración de la app
 * se lee desde aquí (single source of truth del env).
 */
@Injectable()
export class AppConfigService {
  constructor(private readonly configService: ConfigService) {}

  get nodeEnv(): string {
    return this.configService.get<string>('NODE_ENV', 'development');
  }

  get isDevelopment(): boolean {
    return this.nodeEnv !== 'production';
  }

  get port(): number {
    return Number(this.configService.get<number>('PORT', 3000));
  }

  /** Ruta al zip GTFS (relativa al cwd o absoluta). */
  get gtfsFile(): string {
    return this.configService.get<string>('GTFS_FILE', './gtfs.zip');
  }

  /** URL base dell'istanza OTP2 (vuota = router esterno disattivato). */
  get otpUrl(): string {
    return this.configService.get<string>('OTP_URL', '').trim();
  }

  /** Timeout (ms) per le richieste al router OTP2. */
  get otpTimeoutMs(): number {
    return Number(this.configService.get<number>('OTP_TIMEOUT_MS', 8000));
  }

  get database(): DatabaseConfig {
    const syncRaw = this.configService.get<string | boolean>('DB_SYNCHRONIZE', 'true');
    return {
      host: this.configService.get<string>('DB_HOST', 'localhost'),
      port: Number(this.configService.get<number>('DB_PORT', 5432)),
      username: this.configService.get<string>('DB_USERNAME', 'urbano'),
      password: this.configService.get<string>('DB_PASSWORD', 'urbano'),
      database: this.configService.get<string>('DB_DATABASE', 'urbano'),
      // @Transform(toBoolean) ya puede haberlo convertido a boolean
      synchronize: syncRaw === true || syncRaw === 'true',
    };
  }

  get corsOrigins(): string[] {
    const raw = this.configService.get<string>('CORS_ORIGINS', '*');
    return raw
      .split(',')
      .map((origin) => origin.trim())
      .filter(Boolean);
  }
}
