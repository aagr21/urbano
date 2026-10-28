import { Module } from '@nestjs/common';
import { STATS_REPOSITORY } from '../../core/common/tokens';
import { StatsService } from './application/stats.service';
import { TypeOrmStatsRepository } from './infrastructure/typeorm-stats.repository';
import { StatsController } from './presentation/stats.controller';

@Module({
  controllers: [StatsController],
  providers: [
    StatsService,
    { provide: STATS_REPOSITORY, useClass: TypeOrmStatsRepository },
  ],
})
export class StatsModule {}
