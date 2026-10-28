import { StatsService } from './stats.service';
import type { FeedStats, StatsRepositoryPort } from '../domain/stats.model';

describe('StatsService', () => {
  it('entrega el FeedStats del puerto SIN transformación (contrato 1:1)', async () => {
    const stats: FeedStats = {
      routes: 154,
      stops: 3210,
      trips: 4021,
      shapes: 1389,
      service: { start: '2026-01-01', end: '2027-01-01', days: '1111111' },
      firstDeparture: '05:30:00',
      lastDeparture: '23:45:00',
      headwaySeconds: 600,
    };
    const port: Pick<StatsRepositoryPort, 'getStats'> = {
      getStats: async () => stats,
    };
    const service = new StatsService(port as StatsRepositoryPort);

    await expect(service.getStats()).resolves.toBe(stats);
  });
});
