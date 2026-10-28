import { Module } from '@nestjs/common';
import { AppConfigService } from '../../core/config/app-config.service';
import { JOURNEY_DATA_PORT, JOURNEY_ROUTER_PORT } from '../../core/common/tokens';
import { JourneyService } from './application/journey.service';
import { TypeOrmJourneyData } from './infrastructure/typeorm-journey-data';
import { OtpJourneyRouter } from './infrastructure/otp/otp-journey-router';
import { JourneyRouterPort } from './domain/journey-router.port';
import { JourneyController } from './presentation/journey.controller';

/** Router externo (OTP2) o null cuando `OTP_URL` no está configurado. */
export function journeyRouterProvider(config: AppConfigService): JourneyRouterPort | null {
  return config.otpUrl ? new OtpJourneyRouter(config) : null;
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
  ],
})
export class JourneyModule {}
