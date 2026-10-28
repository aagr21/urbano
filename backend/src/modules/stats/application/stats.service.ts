import { Inject, Injectable } from '@nestjs/common';
import { STATS_REPOSITORY } from '../../../core/common/tokens';
import { FeedStats, StatsRepositoryPort } from '../domain/stats.model';

@Injectable()
export class StatsService {
  constructor(
    @Inject(STATS_REPOSITORY) private readonly statsRepository: StatsRepositoryPort,
  ) {}

  getStats(): Promise<FeedStats> {
    return this.statsRepository.getStats();
  }
}
