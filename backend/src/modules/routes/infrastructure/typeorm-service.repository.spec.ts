import { TypeOrmServiceRepository } from './typeorm-service.repository';

/** DataSource falso con resultado único encolado. */
class FakeDataSource {
  private result: unknown = [];

  next(result: unknown): this {
    this.result = result;
    return this;
  }

  async query(sql: string): Promise<unknown> {
    expect(sql).toContain(
      'ORDER BY service_id ASC\n       LIMIT 1',
    );
    return this.result;
  }
}

describe('TypeOrmServiceRepository', () => {
  it('findActiveCalendar toma el primer service por id ASC', async () => {
    const ds = new FakeDataSource().next([
      {
        serviceId: 'SE1',
        monday: true,
        startDate: '20260101',
        endDate: '20261231',
      },
    ]);

    const calendar = await new TypeOrmServiceRepository(ds as never).findActiveCalendar();

    expect(calendar!.serviceId).toBe('SE1');
  });

  it('sin filas devuelve null (rows[0] ?? null)', async () => {
    const ds = new FakeDataSource().next([]);
    await expect(new TypeOrmServiceRepository(ds as never).findActiveCalendar()).resolves.toBeNull();
  });
});
