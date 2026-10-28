import { TypeOrmTripRepository } from './typeorm-trip.repository';

/** DataSource falso: resultados encolados por llamada y llamada registrada. */
class FakeDataSource {
  calls: Array<{ sql: string; params: unknown[] }> = [];
  private queue: Array<Array<Record<string, unknown>>> = [];

  next(rows: Array<Record<string, unknown>>): this {
    this.queue.push(rows);
    return this;
  }

  async query(sql: string, params?: unknown[]): Promise<unknown> {
    this.calls.push({ sql, params: params ?? [] });
    return this.queue.shift() ?? [];
  }
}

const repo = (ds: FakeDataSource) => new TypeOrmTripRepository(ds as never);

describe('TypeOrmTripRepository', () => {
  it('findById une encabezado + stop_times ordenadas por secuencia', async () => {
    const ds = new FakeDataSource()
      .next([
        {
          id: 'T1',
          routeId: 'R1',
          routeShortName: '7',
          routeColor: 'FF0000',
          directionId: 0,
          headsign: 'Terminal Noroeste',
          serviceId: 'SE1',
        },
      ])
      .next([
        {
          stopId: 'S1',
          name: 'A',
          sequence: 1,
          arrivalTime: '06:00:00',
          departureTime: '06:00:30',
          distanceMeters: 0,
          pickupType: 0,
          dropOffType: 0,
        },
        {
          stopId: 'S2',
          name: 'B',
          sequence: 2,
          arrivalTime: '06:05:00',
          departureTime: '06:05:00',
          distanceMeters: 850,
          pickupType: 1,
          dropOffType: 0,
        },
      ]);

    const detail = await repo(ds).findById('T1');

    expect(ds.calls).toHaveLength(2);
    expect(ds.calls[0].params).toEqual(['T1']);
    expect(ds.calls[1].sql).toContain('ORDER BY st.stop_sequence ASC');
    expect(detail!.routeShortName).toBe('7');
    expect(detail!.headsign).toBe('Terminal Noroeste');
    expect(detail!.stopTimes).toHaveLength(2);
  });

  it('findById con trip inexistente corta ANTES de pedir stop_times', async () => {
    const ds = new FakeDataSource().next([]);

    await expect(repo(ds).findById('T-x')).resolves.toBeNull();

    expect(ds.calls).toHaveLength(1);
  });
});
