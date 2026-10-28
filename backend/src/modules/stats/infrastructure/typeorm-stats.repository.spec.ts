import { TypeOrmStatsRepository } from './typeorm-stats.repository';

/** DataSource falso: cada llamada a query() consume el siguiente RESULTADO
 * (array de filas, como devuelve TypeORM — vacío si no hay filas). */
class FakeDataSource {
  calls: string[] = [];
  private queue: unknown[] = [];

  next(result: unknown): this {
    this.queue.push(result);
    return this;
  }

  async query(sql: string): Promise<unknown> {
    this.calls.push(sql);
    return this.queue.shift() ?? [];
  }
}

const repo = (ds: FakeDataSource) => new TypeOrmStatsRepository(ds as never);

const countersFull = { routes: 154, stops: 31461, trips: 890, shapes: 12034 };
const serviceAll = {
  serviceId: 'SE1',
  monday: true,
  tuesday: true,
  wednesday: true,
  thursday: true,
  friday: true,
  saturday: true,
  sunday: true,
  startDate: '20260101',
  endDate: '20261231',
};
const frequency = {
  firstDeparture: '05:45:00',
  lastDeparture: '23:10:00',
  headwaySeconds: 600,
};

describe('TypeOrmStatsRepository', () => {
  it('getStats consulta contadores, servicio y frecuencia y mapea el contrato', async () => {
    const ds = new FakeDataSource()
      .next([countersFull])
      .next([serviceAll])
      .next([frequency]);

    const stats = await repo(ds).getStats();

    expect(ds.calls).toHaveLength(3);
    // "shapes" del contrato = filas de shapes.txt (SUM de point_count), no ids.
    expect(ds.calls[0]).toContain('SUM(point_count)');
    expect(stats).toEqual({
      routes: 154,
      stops: 31461,
      trips: 890,
      shapes: 12034,
      service: { start: '2026-01-01', end: '2026-12-31', days: 'diario' },
      firstDeparture: '05:45:00',
      lastDeparture: '23:10:00',
      headwaySeconds: 600,
    });
  });

  it('calendario lunes a viernes (con sábado/domingo en 0) se describe como tal', async () => {
    const ds = new FakeDataSource()
      .next([{ ...countersFull, shapes: 0 }])
      .next([{ ...serviceAll, saturday: 0, sunday: '0' }])
      .next([frequency]);

    const stats = await repo(ds).getStats();

    // Acepta boolean true o '0'/'1' numérico como venga del driver.
    expect(stats.service.days).toBe('lunes a viernes');
  });

  it('sin servicio ni frecuencia: defaults del contrato (00:00:00 y headway null)', async () => {
    const ds = new FakeDataSource()
      .next([{ routes: 0, stops: 0, trips: 0, shapes: 0 }])
      .next([]) // sin service
      .next([]); // sin frequency

    const stats = await repo(ds).getStats();

    expect(stats).toMatchObject({
      routes: 0,
      service: { start: '', end: '', days: 'desconocido' },
      firstDeparture: '00:00:00',
      lastDeparture: '00:00:00',
      headwaySeconds: null,
    });
  });
});
