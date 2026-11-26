import { TypeOrmRouteRepository } from './typeorm-route.repository';
import { Route } from '../../gtfs-import/entities/route.entity';
import { ROUTE_NATURAL_ORDER_COLUMNS } from '../../../core/common/utils/route-order';
import type { RouteQuery } from '../domain/route.model';

/** QueryBuilder falso: registra la cadena orderBy/skip/take/where. */
class FakeQueryBuilder {
  calls: Array<{ op: string; args: unknown[] }> = [];

  constructor(private readonly result: [Route[], number]) {}

  orderBy(...args: unknown[]): this {
    this.calls.push({ op: 'orderBy', args });
    return this;
  }

  addOrderBy(...args: unknown[]): this {
    this.calls.push({ op: 'addOrderBy', args });
    return this;
  }

  skip(offset: number): this {
    this.calls.push({ op: 'skip', args: [offset] });
    return this;
  }

  take(limit: number): this {
    this.calls.push({ op: 'take', args: [limit] });
    return this;
  }

  where(cond: string, params: Record<string, unknown>): this {
    this.calls.push({ op: 'where', args: [cond, params] });
    return this;
  }

  async getManyAndCount(): Promise<[Route[], number]> {
    return this.result;
  }
}

/** DataSource falso: queryBuilder para findAll, query() encolado y repo de Route. */
class FakeDataSource {
  queryCalls: Array<{ sql: string; params: unknown[] }> = [];
  private queue: unknown[] = [];

  builder: FakeQueryBuilder = new FakeQueryBuilder([[], 0]);
  routeRow: Route | null = null;

  next(result: unknown): this {
    this.queue.push(result);
    return this;
  }

  createQueryBuilder(): FakeQueryBuilder {
    return this.builder;
  }

  getRepository(): { findOne(where: unknown): Promise<Route | null> } {
    return {
      findOne: async () => this.routeRow,
    };
  }

  async query(sql: string, params?: unknown[]): Promise<unknown> {
    this.queryCalls.push({ sql, params: params ?? [] });
    return this.queue.shift() ?? [];
  }
}

const row = (over: Partial<Route> = {}): Route =>
  ({
    id: 'R1',
    shortName: '7',
    longName: 'Barrio San Salvador - Centro',
    color: 'FF0000',
    textColor: 'FFFFFF',
    description: null,
    type: 3,
    directions: 2,
    stopCount: 40,
    tripCount: 12,
    imageUrl: null,
    ...over,
  }) as unknown as Route;

const repo = (ds: FakeDataSource) => new TypeOrmRouteRepository(ds as never);

const query = (over: Partial<RouteQuery> = {}): RouteQuery =>
  ({
    page: 1,
    limit: 20,
    sort: 'name',
    q: '',
    ...over,
  }) as unknown as RouteQuery;

describe('TypeOrmRouteRepository', () => {
  it('findAll pagina por (page-1)*limit, límite del query y sort válido', async () => {
    const ds = new FakeDataSource().next([{ total: 1 }]).next([
      {
        id: 'R1',
        shortName: '7',
        longName: 'Barrio San Salvador - Centro',
        color: 'FF0000',
        textColor: 'FFFFFF',
        description: null,
        type: 3,
        directions: 2,
        stopCount: 40,
        tripCount: 12,
        imageUrl: null,
        keyStops: [],
      },
    ]);

    const page = await repo(ds).findAll(
      query({ page: 3, limit: 10, sort: 'stopCount' })
    );

    // Verifica que la consulta SQL usa el sort correcto y los parámetros de paginación
    expect(ds.queryCalls).toHaveLength(2);
    expect(ds.queryCalls[1].params).toEqual([10, 20]);
    expect(ds.queryCalls[1].sql).toContain('r.stop_count ASC');
    expect(page).toEqual({
      items: [
        expect.objectContaining({ id: 'R1', shortName: '7', stopCount: 40 }),
      ],
      total: 1,
    });
  });

  it.each(['name', 'shortName'] as const)(
    'findAll con sort=%s ordena por número y desempata por sufijo alfabético',
    async (sort) => {
      const ds = new FakeDataSource().next([{ total: 0 }]).next([]);

      await repo(ds).findAll(query({ sort }));

      // La consulta SQL debe contener las columnas de orden natural
      const sql = ds.queryCalls[1].sql;
      expect(sql).toContain(ROUTE_NATURAL_ORDER_COLUMNS[0]);
      expect(sql).toContain(ROUTE_NATURAL_ORDER_COLUMNS[1]);
      expect(sql).toContain(ROUTE_NATURAL_ORDER_COLUMNS[2]);
      // "60 ROJO" va junto al 60: primero el prefijo numérico, luego el sufijo.
      expect(ROUTE_NATURAL_ORDER_COLUMNS[0]).toContain(
        "substring(r.route_short_name from '^[0-9]+')"
      );
      expect(ROUTE_NATURAL_ORDER_COLUMNS[1]).toContain(
        "regexp_replace(r.route_short_name, '^[0-9]+', '')"
      );
    }
  );

  it('findAll con sort=longName conserva el orden literal (sin clave natural)', async () => {
    const ds = new FakeDataSource().next([{ total: 0 }]).next([]);

    await repo(ds).findAll(query({ sort: 'longName' }));

    const sql = ds.queryCalls[1].sql;
    expect(sql).toContain('r.route_long_name ASC');
    expect(sql).not.toContain('substring');
  });

  it('findAll con filtro de texto parametriza el patrón (nunca lo concatena)', async () => {
    const ds = new FakeDataSource().next([{ total: 0 }]).next([]);

    await repo(ds).findAll(query({ q: '  Centro  ' }));

    const [count, page] = ds.queryCalls;
    // El texto viaja como parámetro: el SQL sólo lleva el marcador $N.
    expect(count.sql).toContain('ILIKE $1');
    expect(count.params).toEqual(['%Centro%']);
    expect(page.sql).toContain('ILIKE $3');
    expect(page.params).toEqual([20, 0, '%Centro%']);
    expect(page.sql).not.toContain('Centro');
  });

  it('findAll escapa los comodines de LIKE que vienen del cliente', async () => {
    const ds = new FakeDataSource().next([{ total: 0 }]).next([]);

    await repo(ds).findAll(query({ q: '50%_off\\' }));

    // % y _ se escapan para que el usuario busque el carácter, no un comodín.
    expect(ds.queryCalls[1].params).toEqual([20, 0, '%50\\%\\_off\\\\%']);
  });

  it('findAll con q en blanco NO filtra (solo espacios ⇒ sin cláusula where)', async () => {
    const ds = new FakeDataSource().next([{ total: 0 }]).next([]);

    await repo(ds).findAll(query({ q: '   ' }));

    const [count, page] = ds.queryCalls;
    // No debe contener ILIKE si q está en blanco, y no se pasan parámetros extra.
    expect(page.sql).not.toContain('ILIKE');
    expect(count.params).toEqual([]);
    expect(page.params).toEqual([20, 0]);
  });

  it('findById arma detalle con direcciones y shapes agrupados por shapeId', async () => {
    const ds = new FakeDataSource()
      .next([
        {
          directionId: 0,
          headsign: 'Ida Centro',
          tripId: 'T1',
          shapeId: 'S-A',
          firstDeparture: '06:00:00',
          lastDeparture: '22:00:00',
          headwaySeconds: 600,
          stopCount: 30,
        },
        {
          directionId: 1,
          headsign: 'Vuelta B° San Salvador',
          tripId: 'T2',
          shapeId: null, // trip sin shape → la coordenada no entra al mapa
          firstDeparture: '06:00:00',
          lastDeparture: '22:00:00',
          headwaySeconds: null,
          stopCount: 28,
        },
      ])
      .next([
        {
          shapeId: 'S-A',
          coordinates: [
            [-63.18, -17.78],
            [-63.19, -17.79],
          ],
          bboxMinLon: -63.19,
          bboxMinLat: -17.79,
          bboxMaxLon: -63.18,
          bboxMaxLat: -17.78,
        },
      ]);
    ds.routeRow = row();

    const detail = await repo(ds).findById('R1');

    expect(ds.queryCalls[0].params).toEqual(['R1']);
    // Solo pidió el shape S-A (el null del direction 1 quedó filtrado).
    expect(ds.queryCalls[1].params).toEqual([['S-A']]);
    expect(ds.queryCalls[1].sql).toContain('ANY($1)');
    expect(detail!.shapes['S-A']).toEqual({
      coordinates: [
        [-63.18, -17.78],
        [-63.19, -17.79],
      ],
      bbox: [-63.19, -17.79, -63.18, -17.78],
    });
    expect(detail!.directions).toHaveLength(2);
    expect(detail!.directions[1].shapeId).toBeNull();
  });

  it('findById de ruta sin shapes NO consulta la tabla shape', async () => {
    const ds = new FakeDataSource().next([
      {
        directionId: 0,
        headsign: null,
        tripId: 'T1',
        shapeId: null,
        firstDeparture: '06:00:00',
        lastDeparture: '22:00:00',
        headwaySeconds: null,
        stopCount: 10,
      },
    ]);
    ds.routeRow = row();

    const detail = await repo(ds).findById('R1');

    expect(ds.queryCalls).toHaveLength(1);
    expect(detail!.shapes).toEqual({});
  });

  it('findStops pasa ruta Y direction_id y respeta el orden de secuencia', async () => {
    const ds = new FakeDataSource().next([
      {
        id: 'S1',
        code: null,
        name: 'A',
        lat: -17.78,
        lon: -63.18,
        sequence: 1,
        arrivalTime: '06:00:00',
        departureTime: '06:00:00',
        distanceMeters: 0,
      },
    ]);

    const stops = await repo(ds).findStops('R1', 1);

    expect(ds.queryCalls[0].params).toEqual(['R1', 1]);
    expect(ds.queryCalls[0].sql).toContain('ORDER BY st.stop_sequence ASC');
    expect(stops[0].id).toBe('S1');
  });

  it('findDepartureSources con stopId null usa stop_sequence=1; con direction llama por dirección', async () => {
    const ds = new FakeDataSource().next([]).next([]);

    await repo(ds).findDepartureSources('R1', null, 1);
    expect(ds.queryCalls[0].params).toEqual(['R1', null, 1]);
    expect(ds.queryCalls[0].sql).toContain('st.stop_sequence = 1');

    await repo(ds).findDepartureSources('R1', 'S9', undefined);
    expect(ds.queryCalls[1].params).toEqual(['R1', 'S9', null]);
  });

  it('findById con ruta inexistente corta en el findOne (ni direcciones ni shapes)', async () => {
    const ds = new FakeDataSource();
    ds.routeRow = null;

    await expect(repo(ds).findById('R-x')).resolves.toBeNull();
    expect(ds.queryCalls).toHaveLength(0);
  });
});
