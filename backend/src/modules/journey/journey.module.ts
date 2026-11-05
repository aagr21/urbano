import { Module } from '@nestjs/common';
import {
  JOURNEY_DATA_PORT,
  JOURNEY_ROUTER_PORT,
  JOURNEY_WALK_GEOMETRY_PORT,
} from '../../core/common/tokens';
import { AppConfigService } from '../../core/config/app-config.service';
import { JourneyService } from './application/journey.service';
import { JourneyRouterPort } from './domain/journey-router.port';
import { WalkGeometryPort } from './domain/walk-geometry.port';
import { OtpJourneyRouter } from './infrastructure/otp/otp-journey-router';
import { TypeOrmJourneyData } from './infrastructure/typeorm-journey-data';
import { ValhallaWalkGeometry } from './infrastructure/valhalla/valhalla-walk-geometry';
import { JourneyController } from './presentation/journey.controller';

/** Router externo (OTP2) o null cuando `OTP_URL` no está configurado. */
export function journeyRouterProvider(
  config: AppConfigService
): JourneyRouterPort | null {
  return config.otpUrl ? new OtpJourneyRouter(config) : null;
}

/**
 * Ruteador peatonal (Valhalla) o null cuando `WALK_ROUTER_URL` no está
 * configurado. Da geometría a las caminatas que OTP no trazó (producción
 * Vercel, sin OTP), para que el mapa siga calles y no corte en recta.
 */
export function journeyWalkGeometryProvider(
  config: AppConfigService
): WalkGeometryPort | null {
  return config.walkRouterUrl ? new ValhallaWalkGeometry(config) : null;
}

@Module({
  controllers: [JourneyController],
  providers: [
    JourneyService,
    { provide: JOURNEY_DATA_PORT, useClass: TypeOrmJourneyData },
    {
      provide: JOURNEY_ROUTER_PORT,
      useFactory: journeyRouterProvider,
      inject: [AppConfigService],
    },
    {
      provide: JOURNEY_WALK_GEOMETRY_PORT,
      useFactory: journeyWalkGeometryProvider,
      inject: [AppConfigService],
    },
  ],
})
export class JourneyModule {}
