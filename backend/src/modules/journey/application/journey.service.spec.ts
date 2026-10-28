import { JourneyService } from './journey.service';
import { JourneyQueryDto } from './journey.dto';
import { JourneyDataPort, LegDetail, LegDetailQuery } from '../domain/journey-data.port';
import { CandidateStop, JourneyOption, TripSchedule } from '../domain/journey.model';

/**
 * Servicio con el puerto mockeado: verifica el enriquecimiento de mapa
 * (geometría del tramo + coordenadas de paradas) y la deduplicación de
 * tramos de bus (una sola llamada al puerto por lote).
 */
describe('JourneyService — motor externo (OTP2)', () => {
  const query: JourneyQueryDto = {
    originLat: -17.78,
    originLon: -63.15,
    destLat: -17.8,
    destLon: -63.17,
    time: '06:00',
    maxResults: 3,
  };

  const otpOption: JourneyOption = {
    type: 'direct',
    departAt: '06:00:00',
    arriveAt: '06:40:00',
    durationMinutes: 40,
    walkToStop: { id: 'S1', name: 'P1', distanceMeters: 180, lat: -17.78, lon: -63.15 },
    walkFromStop: { id: 'S2', name: 'P2', distanceMeters: 240, lat: -17.8, lon: -63.17 },
    legs: [
      {
        kind: 'walk',
        durationMinutes: 3,
        distanceMeters: 180,
        geometry: { type: 'LineString', coordinates: [[-63.151, -17.781]] },
      } as never,
      {
        kind: 'bus',
        routeId: 'R1',
        routeShortName: '1',
        routeColor: 'D35400',
        tripId: 'T1',
        fromStopId: 'S1',
        toStopId: 'S2',
        departAt: '06:03:00',
        arriveAt: '06:38:00',
        stops: 5,
        geometry: { type: 'LineString', coordinates: [[-63.15, -17.78]] },
        fromStop: { id: 'S1', name: 'P1', lat: -17.78, lon: -63.15 },
        toStop: { id: 'S2', name: 'P2', lat: -17.8, lon: -63.17 },
      },
    ] as never,
  };

  function makeServiceWithRouter(router: { plan: jest.Mock }) {
    const port = {
      findStopsNear: jest.fn(),
      findTripIdsServingStops: jest.fn(),
      loadTripSchedules: jest.fn(),
      loadLegDetails: jest.fn(),
      findStopRefs: jest.fn(),
    };
    const service = new JourneyService(
      port as unknown as JourneyDataPort,
      (router as unknown) as never,
    );
    return { service, port };
  }

  it('si OTP responde opciones, las devuelve tal cual (sin tocar la base de datos)', async () => {
    const plan = jest.fn().mockResolvedValue([otpOption]);
    const { service, port } = makeServiceWithRouter({ plan });

    const { options } = await service.plan(query);

    expect(options).toEqual([otpOption]);
    expect(plan).toHaveBeenCalledWith(
      expect.objectContaining({
        originLat: -17.78,
        destLon: -63.17,
        timeSec: 6 * 3600,
        maxResults: 3,
      }),
    );
    // El pipeline PostGIS (planner legacy) no se usó
    expect(port.findStopsNear).not.toHaveBeenCalled();
  });

  it('si OTP devuelve null (no disponible), degrada al planner interno', async () => {
    const port = {
      findStopsNear: jest.fn(async (lat: number) =>
        lat === query.originLat ? [{ stopId: 'S1', name: 'P1', lat: -17.78, lon: -63.15, distanceMeters: 80 }] : [{ stopId: 'S2', name: 'P2', lat: -17.8, lon: -63.17, distanceMeters: 80 }]),
      findTripIdsServingStops: jest.fn(async () => ['T1']),
      loadTripSchedules: jest.fn(async () => [
        {
          tripId: 'T1', routeId: 'R1', routeShortName: 'R1', routeColor: 'D35400', directionId: 0,
          headsign: 'Ida', startTimeSec: 6 * 3600, endTimeSec: 8 * 3600, headwaySeconds: 300,
          stops: [
            { stopId: 'S1', sequence: 1, arrivalSec: 6 * 3600, departureSec: 6 * 3600 },
            { stopId: 'S2', sequence: 2, arrivalSec: 6 * 3600 + 60, departureSec: 6 * 3600 + 60 },
          ],
        },
      ]),
      loadLegDetails: jest.fn(async (legs: LegDetailQuery[]) =>
        legs.map((leg) => ({ ...leg, fromStop: undefined, toStop: undefined, coordinates: [[-63.15, -17.78], [-63.17, -17.8]] }))),
      findStopRefs: jest.fn(async (ids: string[]) => ids.map((id) => ({ id, name: `Ref ${id}`, lat: -17.78, lon: -63.15 }))),
    };
    const plan = jest.fn().mockResolvedValue(null); // OTP caído
    const service = new JourneyService(
      port as unknown as JourneyDataPort,
      { plan } as never,
    );

    const { options } = await service.plan(query);

    // El planner interno produjo la opción (con geometría del shape recortado)
    expect(options.length).toBeGreaterThan(0);
    expect(plan).toHaveBeenCalledTimes(1);
    for (const option of options) {
      expect(option.type).toBe('direct');
    }
  });

  it('si OTP lanza, degrada al planner interno sin romper el endpoint', async () => {
    const port = {
      findStopsNear: jest.fn(async (lat: number) =>
        lat === query.originLat ? [{ stopId: 'S1', name: 'P1', lat: -17.78, lon: -63.15, distanceMeters: 80 }] : [{ stopId: 'S2', name: 'P2', lat: -17.8, lon: -63.17, distanceMeters: 80 }]),
      findTripIdsServingStops: jest.fn(async () => ['T1']),
      loadTripSchedules: jest.fn(async () => [
        {
          tripId: 'T1', routeId: 'R1', routeShortName: 'R1', routeColor: 'D35400', directionId: 0,
          headsign: 'Ida', startTimeSec: 6 * 3600, endTimeSec: 8 * 3600, headwaySeconds: 300,
          stops: [
            { stopId: 'S1', sequence: 1, arrivalSec: 6 * 3600, departureSec: 6 * 3600 },
            { stopId: 'S2', sequence: 2, arrivalSec: 6 * 3600 + 60, departureSec: 6 * 3600 + 60 },
          ],
        },
      ]),
      loadLegDetails: jest.fn(async (legs: LegDetailQuery[]) =>
        legs.map((leg) => ({ ...leg, fromStop: undefined, toStop: undefined, coordinates: [[-63.15, -17.78], [-63.17, -17.8]] }))),
      findStopRefs: jest.fn(async (ids: string[]) => ids.map((id) => ({ id, name: `Ref ${id}`, lat: -17.78, lon: -63.15 }))),
    };
    const plan = jest.fn().mockRejectedValue(new Error('boom'));
    const service = new JourneyService(
      port as unknown as JourneyDataPort,
      { plan } as never,
    );

    const { options } = await service.plan(query);
    expect(options.length).toBeGreaterThan(0);
  });
});

/**
 * Servicio con el puerto mockeado: verifica el enriquecimiento de mapa
 * (geometría del tramo + coordenadas de paradas) y la deduplicación de
 * tramos de bus (una sola llamada al puerto por lote).
 */
describe('JourneyService (enriquecimiento de mapa)', () => {
  const originStop: CandidateStop = {
    stopId: 'S1',
    name: 'Parada origen',
    lat: -17.78,
    lon: -63.15,
    distanceMeters: 80,
  };
  const destStopS2: CandidateStop = {
    stopId: 'S2',
    name: 'Parada destino 2',
    lat: -17.79,
    lon: -63.16,
    distanceMeters: 160,
  };
  const destStopS3: CandidateStop = {
    stopId: 'S3',
    name: 'Parada destino 3',
    lat: -17.8,
    lon: -63.17,
    distanceMeters: 200,
  };

  const t = (h: number, m = 0) => h * 3600 + m * 60;

  const trips: TripSchedule[] = [
    {
      tripId: 'T1',
      routeId: 'R1',
      routeShortName: 'R1',
      routeColor: 'D35400',
      directionId: 0,
      headsign: 'Ida',
      startTimeSec: t(6),
      endTimeSec: t(8),
      headwaySeconds: 300,
      stops: [
        { stopId: 'S1', sequence: 1, arrivalSec: t(6), departureSec: t(6) },
        { stopId: 'S2', sequence: 2, arrivalSec: t(6, 20), departureSec: t(6, 20) },
        { stopId: 'S3', sequence: 3, arrivalSec: t(6, 30), departureSec: t(6, 30) },
      ],
    },
    {
      tripId: 'T2',
      routeId: 'R2',
      routeShortName: 'R2',
      routeColor: '2ECC71',
      directionId: 1,
      headsign: 'Vuelta',
      startTimeSec: t(6),
      endTimeSec: t(8),
      headwaySeconds: 300,
      stops: [
        { stopId: 'S2', sequence: 1, arrivalSec: t(6, 25), departureSec: t(6, 25) },
        { stopId: 'S3', sequence: 2, arrivalSec: t(6, 50), departureSec: t(6, 50) },
      ],
    },
  ];

  const query: JourneyQueryDto = {
    originLat: -17.78,
    originLon: -63.15,
    destLat: -17.8,
    destLon: -63.17,
    time: '06:00',
    maxResults: 3,
  };

  const SHAPED_COORDINATES = [
    [-63.15, -17.78],
    [-63.16, -17.79],
    [-63.17, -17.8],
  ];

  interface MockOptions {
    /** Coordinates que devuelve loadLegDetails (null = ruta sin shape). */
    coordinates?: number[][] | null;
  }

  function makeService(options: MockOptions = {}) {
    const loadLegDetails = jest.fn(
      async (legs: LegDetailQuery[]): Promise<LegDetail[]> =>
        legs.map((leg) => ({
          ...leg,
          fromStop: { id: leg.fromStopId, name: `Nombre ${leg.fromStopId}`, lat: -17.78, lon: -63.15 },
          toStop: { id: leg.toStopId, name: `Nombre ${leg.toStopId}`, lat: -17.8, lon: -63.17 },
          coordinates:
            options.coordinates === undefined ? SHAPED_COORDINATES : options.coordinates,
        })),
    );
    const findStopRefs = jest.fn(
      async (ids: string[]): Promise<Array<{ id: string; name: string; lat: number; lon: number }>> =>
        ids.map((id) => ({ id, name: `Ref ${id}`, lat: -17.781, lon: -63.151 })),
    );

    const port = {
      findStopsNear: jest.fn(async (lat: number) =>
        lat === query.originLat ? [originStop] : [destStopS2, destStopS3],
      ),
      findTripIdsServingStops: jest.fn(async () => ['T1', 'T2']),
      loadTripSchedules: jest.fn(async () => trips),
      loadLegDetails,
      findStopRefs,
    };

    const service = new JourneyService(port as unknown as JourneyDataPort);
    return { service, port, loadLegDetails, findStopRefs };
  }

  const busLegsOf = (options: Awaited<ReturnType<JourneyService['plan']>>['options']) =>
    options.flatMap((o) => o.legs).filter((l) => l.kind === 'bus');

  it('adjunta geometry (LineString no vacío) y fromStop/toStop con lat/lon a cada tramo de bus', async () => {
    const { service } = makeService();

    const { options } = await service.plan(query);
    expect(options.length).toBeGreaterThan(0);

    const busLegs = busLegsOf(options);
    expect(busLegs.length).toBeGreaterThan(0);

    for (const leg of busLegs) {
      expect(leg.kind).toBe('bus');
      if (leg.kind !== 'bus') continue;
      expect(leg.geometry).toBeDefined();
      expect(leg.geometry!.type).toBe('LineString');
      expect(leg.geometry!.coordinates.length).toBeGreaterThanOrEqual(2);
      expect(leg.geometry!.coordinates).toEqual(SHAPED_COORDINATES);
      expect(leg.fromStop).toMatchObject({
        id: leg.fromStopId,
        name: expect.any(String),
        lat: expect.any(Number),
        lon: expect.any(Number),
      });
      expect(leg.toStop).toMatchObject({
        id: leg.toStopId,
        name: expect.any(String),
        lat: expect.any(Number),
        lon: expect.any(Number),
      });
    }
  });

  it('deduplica tramos compartidos: 2 opciones con el mismo leg ⇒ 1 sola llamada al puerto con ese leg', async () => {
    const { service, loadLegDetails, findStopRefs } = makeService();

    const { options } = await service.plan(query);

    // directo (T1: S1→S2) y transbordo (T1: S1→S2 + T2: S2→S3) comparten el
    // primer tramo ⇒ 4 tramos en total, 3 únicos.
    const busLegs = busLegsOf(options);
    expect(busLegs.length).toBe(4);
    const keys = busLegs.map((l) =>
      l.kind === 'bus' ? `${l.tripId}:${l.fromStopId}:${l.toStopId}` : '',
    );
    expect(keys.filter((k) => k === 'T1:S1:S2')).toHaveLength(2);

    expect(loadLegDetails).toHaveBeenCalledTimes(1);
    const requested: LegDetailQuery[] = loadLegDetails.mock.calls[0][0];
    expect(requested).toHaveLength(3);
    expect(requested.map((l) => `${l.tripId}:${l.fromStopId}:${l.toStopId}`)).toEqual(
      expect.arrayContaining(['T1:S1:S2', 'T1:S1:S3', 'T2:S2:S3']),
    );
    // sin duplicados
    expect(new Set(requested.map((l) => `${l.tripId}:${l.fromStopId}:${l.toStopId}`)).size).toBe(
      requested.length,
    );

    expect(findStopRefs).toHaveBeenCalledTimes(1);
  });

  it('añade lat/lon a walkToStop y walkFromStop de cada opción', async () => {
    const { service } = makeService();

    const { options } = await service.plan(query);
    expect(options.length).toBeGreaterThan(0);

    for (const option of options) {
      expect(option.walkToStop).toMatchObject({
        id: expect.any(String),
        distanceMeters: expect.any(Number),
        lat: expect.any(Number),
        lon: expect.any(Number),
      });
      expect(option.walkFromStop).toMatchObject({
        id: expect.any(String),
        distanceMeters: expect.any(Number),
        lat: expect.any(Number),
        lon: expect.any(Number),
      });
    }
    // resueltas por id con findStopRefs
    const walkTo = options[0].walkToStop;
    expect(walkTo.id).toBe('S1');
    expect(walkTo.lat).toBeCloseTo(-17.781, 6);
    expect(walkTo.lon).toBeCloseTo(-63.151, 6);
  });

  it('deja geometry: null si el puerto no devuelve coordenadas (ruta sin shape)', async () => {
    const { service } = makeService({ coordinates: null });

    const { options } = await service.plan(query);
    const busLegs = busLegsOf(options);
    expect(busLegs.length).toBeGreaterThan(0);

    for (const leg of busLegs) {
      if (leg.kind !== 'bus') continue;
      expect(leg.geometry).toBeNull();
      // las paradas siguen enriquecidas aunque no haya shape
      expect(leg.fromStop).toMatchObject({ lat: expect.any(Number), lon: expect.any(Number) });
      expect(leg.toStop).toMatchObject({ lat: expect.any(Number), lon: expect.any(Number) });
    }
  });

  it('sin paradas candidatas devuelve options vacío sin tocar loadLegDetails', async () => {
    const loadLegDetails = jest.fn(async () => []);
    const port = {
      findStopsNear: jest.fn(async () => []),
      findTripIdsServingStops: jest.fn(async () => []),
      loadTripSchedules: jest.fn(async () => []),
      loadLegDetails,
      findStopRefs: jest.fn(async () => []),
    };
    const service = new JourneyService(port as unknown as JourneyDataPort);

    const { options } = await service.plan(query);
    expect(options).toEqual([]);
    expect(loadLegDetails).not.toHaveBeenCalled();
  });

  it('origen y destino a < 150 m: responde vacío sin tocar la base de datos', async () => {
    // Regresión del reporte de usuario: al arrastrar los puntos uno sobre
    // el otro, el backend planificaba un viaje "de una parada a la de al
    // lado" y el resultado mostraba origen y destino en el mismo lugar.
    const { service, port } = makeService();

    const { options } = await service.plan({
      ...query,
      destLat: query.originLat + 0.0005, // ~55 m
      destLon: query.originLon,
    });

    expect(options).toEqual([]);
    expect(port.findStopsNear).not.toHaveBeenCalled();
  });
});
