import { Module } from '@nestjs/common';
import { HealthService } from './application/health.service';
import { MetaService } from './application/meta.service';
import { HealthController } from './presentation/health.controller';
import { MetaController } from './presentation/meta.controller';

@Module({
  controllers: [HealthController, MetaController],
  providers: [HealthService, MetaService],
})
export class HealthModule {}
