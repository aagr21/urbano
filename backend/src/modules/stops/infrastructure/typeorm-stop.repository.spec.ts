import { TypeOrmStopRepository } from './typeorm-stop.repository';
import type { NearbyQuery } from '../domain/stop.model';

interface Call {
  sql: string;
  params: unknown[];
}

/** DataSource falso: encola resultados por llamada y registra (sql, params). */
class FakeDataSource {
  calls: Call[] = [];

  private queue: Array<Array<Record<string, unknown>>> = [];

  /** Encola la(s) fila(s) que devolverá la siguiente llamada a query(). */
  next(rows: Array<Record<string, unknown>>): this {
    this.queue.push(rows);
    return this;
  }

  async query(sql: string, params?: unknown[]): Promise<unknown> {
    this.calls.push({ sql, params: params ?? [] });
    const rows = this.queue.shift() ?? [];
    return rows;
  }
}

function repo(ds: FakeDataSource): TypeOrmStopRepository {
  return new TypeOrmStopRepository(ds as never);
}

const nearby = (over: Partial<NearbyQuery> = {}): NearbyQuery => ({
  lat: -17.78,
  lon: -63.18,
  radiusMeters: 400,
  limit: 10,
  ...over,
});

describe('TypeOrmStopRepository', () => {
  it('findNearby consulta con ST_DWithin sobre geography y pasa [lat, lon, radio, límite]', async () => {
    const ds = new FakeDataSource();
    // 1ª query: filas nearby; 2ª: count; 3ª: rutas por stop.
    ds.next([
      {
        id: 'S1',
        code: '101',
        name: 'Monseñor Terrazas',
        lat: -17.781,
        lon: -63.181,
        distanceMeters: 123.456,
      },
    ])
      .next([{ count: '7' }])
      .next([]);

    const page = await repo(ds).findNearby(nearby());

    // La coordenada entra como ($2, $1): LON primero en MakePoint (PostGIS).
    expect(ds.calls[0].sql).toContain('ST_DWithin');
    expect(ds.calls[0].sql).toContain('ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography');
    expect(ds.calls[0].params).toEqual([-17.78, -63.18, 400, 10]);
    // La distancia se redondea a 1 decimal y sin rutas queda lista vacía.
    expect(page.items[0]).toMatchObject({
      id: 'S1',
      distanceMeters: 123.5,
      routes: [],
    });
    expect(page.total).toBe(7);
  });

  it('findNearby agrupa las rutas por stop en UNA sola query extra (no N+1)', async () => {
    const ds = new FakeDataSource();
    ds.next([
      { id: 'S1', code: null, name: 'A', lat: 1, lon: 2, distanceMeters: 10 },
      { id: 'S2', code: null, name: 'B', lat: 3, lon: 4, distanceMeters: 20 },
    ])
      .next([{ count: '2' }])
      .next([
        { stopId: 'S1', id: 'R1', shortName: '7', color: 'FF0000' },
        { stopId: 'S1', id: 'R2', shortName: '105', color: null },
        { stopId: 'S2', id: 'R1', shortName: '7', color: 'FF0000' },
      ]);

    const page = await repo(ds).findNearby(nearby());

    expect(ds.calls).toHaveLength(3);
    expect(ds.calls[2].sql).toContain('ANY($1)');
    expect(ds.calls[2].params).toEqual([['S1', 'S2']]);
    expect(page.items[0].routes).toEqual([
      { id: 'R1', shortName: '7', color: 'FF0000' },
      { id: 'R2', shortName: '105', color: null },
    ]);
  });

  it('search normaliza el LIKE a minúsculas y prioriza coincidencia exacta/rango', async () => {
    const ds = new FakeDataSource();
    ds.next([]).next([{ count: '0' }]);

    await repo(ds).search('CUATRO Anillo', 5);

    expect(ds.calls[0].params[0]).toBe('%cuatro anillo%');
    expect(ds.calls[0].params[1]).toBe('cuatro anillo');
    expect(ds.calls[0].params[2]).toBe('cuatro anillo%');
    expect(ds.calls[0].params[3]).toBe(5);
    // La prioridad por CASE está en el SQL (exacta=0, prefijo=1, resto=2).
    expect(ds.calls[0].sql).toContain('WHEN LOWER(s.stop_id) = $2 THEN 0');
  });

  it('findById arma GeoJSON Point [lon, lat] y null cuando no hay filas', async () => {
    const ds = new FakeDataSource();
    ds.next([
      { id: 'S1', code: '9', name: 'Terminal', lat: -17.8, lon: -63.2 },
    ])
      .next([{ stopId: 'S1', id: 'R5', shortName: '5', color: '00FF00' }]);

    const detail = await repo(ds).findById('S1');

    expect(ds.calls[0].params).toEqual(['S1']);
    expect(detail!.location).toEqual({
      type: 'Point',
      coordinates: [-63.2, -17.8],
    });
    expect(detail!.routes).toHaveLength(1);

    const vacia = new FakeDataSource();
    vacia.next([]);
    await expect(repo(vacia).findById('S-x')).resolves.toBeNull();
    expect(vacia.calls).toHaveLength(1); // corta antes de preguntar rutas
  });

  it('routesForStops no consulta nada para lista vacía de ids', async () => {
    const ds = new FakeDataSource();
    ds.next([]).next([{ count: '0' }]);

    const page = await repo(ds).findNearby(nearby({ limit: 0 }));

    expect(ds.calls).toHaveLength(2);
    expect(page.items).toHaveLength(0);
  });
});
