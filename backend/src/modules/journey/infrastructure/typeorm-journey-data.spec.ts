import { TypeOrmJourneyData } from './typeorm-journey-data';
import type { LegDetailQuery } from '../domain/journey-data.port';

interface Call {
  sql: string;
  params: unknown[];
}

/** DataSource falso con resultados encolados y (sql, params) registrados. */
class FakeDataSource {
  calls: Call[] = [];
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

const repo = (ds: FakeDataSource) => new TypeOrmJourneyData(ds as never);

describe('TypeOrmJourneyData', () => {
  it('findStopsNear usa ST_DWithin con coordenadas LON primero y ordena por distancia', async () => {
    const ds = new FakeDataSource().next([
      { stopId: 'S1', name: 'A', lat: -17.78, lon: -63.18, distanceMeters: '55.7' },
    ]);

    const stops = await repo(ds).findStopsNear(-17.78, -63.18, 500, 3);

    expect(ds.calls[0].params).toEqual([-17.78, -63.18, 500, 3]);
    expect(ds.calls[0].sql).toContain('ST_DWithin');
    expect(ds.calls[0].sql).toContain('ORDER BY "distanceMeters" ASC');
    // La distancia que era string de PG llega como número.
    expect(stops[0].distanceMeters).toBe(55.7);
  });

  describe('cortes cortocircuitados en vacío (ni query)', () => {
    it('findTripIdsServingStops([]) y findStopRefs([]) no toca la DB', async () => {
      const ds = new FakeDataSource();
      const data = repo(ds);
      await expect(data.findTripIdsServingStops([])).resolves.toEqual([]);
      await expect(data.findStopRefs([])).resolves.toEqual([]);
      expect(ds.calls).toHaveLength(0);
    });

    it('loadTripSchedules([]) y loadLegDetails([]) no toca la DB', async () => {
      const ds = new FakeDataSource();
      const data = repo(ds);
      await expect(data.loadTripSchedules([])).resolves.toEqual([]);
      await expect(data.loadLegDetails([])).resolves.toEqual([]);
      expect(ds.calls).toHaveLength(0);
    });
  });

  it('loadTripSchedules agrupa filas por trip y convierte los GTFS HH:mm:ss a segundos', async () => {
    const ds = new FakeDataSource().next([
      {
        tripId: 'T1',
        routeId: 'R1',
        routeShortName: '7',
        routeColor: 'FF0000',
        directionId: 1,
        headsign: 'Terminal',
        startTime: '06:30:00',
        endTime: '21:00:00',
        headwaySeconds: 900,
        stopId: 'S1',
        sequence: 1,
        arrivalTime: '06:31:00',
        departureTime: '06:31:20',
      },
      {
        tripId: 'T1',
        routeId: 'R1',
        routeShortName: '7',
        routeColor: 'FF0000',
        directionId: 1,
        headsign: 'Terminal',
        startTime: '06:30:00',
        endTime: '21:00:00',
        headwaySeconds: 900,
        stopId: 'S2',
        sequence: 2,
        arrivalTime: '06:35:00',
        departureTime: '06:35:00',
      },
      {
        tripId: 'T2',
        routeId: 'R2',
        routeShortName: '105',
        routeColor: null,
        directionId: 0,
        headsign: null,
        startTime: '07:00:00',
        endTime: '22:00:00',
        headwaySeconds: null, // PG manda null → el repo lo normaliza a 0
        stopId: 'S9',
        sequence: 1,
        arrivalTime: '07:01:00',
        departureTime: '07:01:00',
      },
    ]);

    const schedules = await repo(ds).loadTripSchedules(['T1', 'T2']);

    // Dos filas de T1 → UNA entrada con dos paradas; null headway → 0.
    expect(schedules).toHaveLength(2);
    const [t1, t2] = schedules;
    expect(t1.tripId).toBe('T1');
    expect(t1.stops).toEqual([
      { stopId: 'S1', sequence: 1, arrivalSec: 23460, departureSec: 23480 },
      { stopId: 'S2', sequence: 2, arrivalSec: 23700, departureSec: 23700 },
    ]);
    expect(t1.startTimeSec).toBe(6 * 3600 + 30 * 60);
    expect(t2.headwaySeconds).toBe(0);
  });

  it('loadLegDetails parsea el GeoJSON del shape recortado y manda arrays lon/lat en UNA query', async () => {
    const ds = new FakeDataSource().next([
      {
        tripId: 'T1',
        fromStopId: 'S1',
        toStopId: 'S2',
        fromName: 'A',
        fromLat: -17.78,
        fromLon: -63.18,
        toName: 'B',
        toLat: -17.79,
        toLon: -63.19,
        geojson: JSON.stringify({
          type: 'LineString',
          coordinates: [
            [-63.18, -17.78],
            [-63.185, -17.785],
            [-63.19, -17.79],
          ],
        }),
      },
    ]);

    const legs = await repo(ds).loadLegDetails([
      { tripId: 'T1', fromStopId: 'S1', toStopId: 'S2' },
    ]);

    // Tres arrays desagregados (trip, from, to) — la query de shape es única.
    expect(ds.calls[0].params[0]).toEqual(['T1']);
    expect(ds.calls[0].params[1]).toEqual(['S1']);
    expect(ds.calls[0].params[2]).toEqual(['S2']);
    expect(legs[0].coordinates).toHaveLength(3);
    expect(legs[0].coordinates![0]).toEqual([-63.18, -17.78]);
  });
});
