import { Module } from '@nestjs/common';
import { STOP_REPOSITORY } from '../../core/common/tokens';
import { StopsService } from './application/stops.service';
import { TypeOrmStopRepository } from './infrastructure/typeorm-stop.repository';
import { StopsController } from './presentation/stops.controller';

@Module({
  controllers: [StopsController],
  providers: [
    StopsService,
    { provide: STOP_REPOSITORY, useClass: TypeOrmStopRepository },
  ],
  exports: [STOP_REPOSITORY, StopsService],
})
export class StopsModule {}
