import { Module } from '@nestjs/common';
import { TRIP_REPOSITORY } from '../../core/common/tokens';
import { TripsService } from './application/trips.service';
import { TypeOrmTripRepository } from './infrastructure/typeorm-trip.repository';
import { TripsController } from './presentation/trips.controller';

@Module({
  controllers: [TripsController],
  providers: [
    TripsService,
    { provide: TRIP_REPOSITORY, useClass: TypeOrmTripRepository },
  ],
  exports: [TripsService],
})
export class TripsModule {}
