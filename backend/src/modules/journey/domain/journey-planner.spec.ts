import {
  planJourneys,
  rankAndCut,
  walkDurationMinutes,
  nextRunDeparture,
  orientBusLegGeometry,
  connectWalkAndBusGeometry,
  dropShortFirstRideTransfers,
  totalWalkMeters,
} from './journey-planner';
import { CandidateStop, JourneyOption, TripSchedule } from './journey.model';

describe('journey-planner (lógica pura)', () => {
  describe('walkDurationMinutes', () => {
    it('0 m → 0 min', () => {
      expect(walkDurationMinutes(0)).toBe(0);
    });
    it('80 m → 1 min (80 m/min)', () => {
      expect(walkDurationMinutes(80)).toBe(1);
    });
    it('redondea hacia arriba', () => {
      expect(walkDurationMinutes(81)).toBe(2);
      expect(walkDurationMinutes(160)).toBe(2);
      expect(walkDurationMinutes(161)).toBe(3);
    });
  });

  describe('nextRunDeparture', () => {
    // base 06:00, headway 300s, ventana 06:00-08:00 → kMax = 24
    it('devuelve la primera salida >= notBefore', () => {
      // base=06:00 (21600), notBefore=06:01 (21660) → k=1 → 06:05 (21900)
      const dep = nextRunDeparture(21600, 300, 24, 21660);
      expect(dep).toEqual({ k: 1, departureSec: 21900 });
    });
    it('devuelve k=0 si notBefore <= base', () => {
      const dep = nextRunDeparture(21600, 300, 24, 21000);
      expect(dep).toEqual({ k: 0, departureSec: 21600 });
    });
    it('devuelve null si se pasa la ventana', () => {
      // notBefore muy tarde → k > kMax
      const dep = nextRunDeparture(21600, 300, 24, 21600 + 100 * 300);
      expect(dep).toBeNull();
    });
  });

  describe('orientBusLegGeometry', () => {
    const optionWith = (coordinates: number[][]): JourneyOption => ({
      type: 'direct',
      departAt: '06:00:00',
      arriveAt: '06:20:00',
      durationMinutes: 20,
      walkToStop: { id: 'S1', name: 'Subida', distanceMeters: 0 },
      walkFromStop: { id: 'S2', name: 'Bajada', distanceMeters: 0 },
      legs: [
        {
          kind: 'bus',
          routeId: 'R1',
          routeShortName: 'R1',
          routeColor: null,
          tripId: 'T1',
          fromStopId: 'S1',
          toStopId: 'S2',
          departAt: '06:00:00',
          arriveAt: '06:20:00',
          stops: 2,
          fromStop: { id: 'S1', name: 'Subida', lat: -17.78, lon: -63.15 },
          toStop: { id: 'S2', name: 'Bajada', lat: -17.8, lon: -63.17 },
          geometry: { type: 'LineString', coordinates },
        },
      ],
    });

    it('invierte SOLO la geometría cuando viene al revés de fromStop → toStop', () => {
      const option = optionWith([
        [-63.17, -17.8],
        [-63.16, -17.79],
        [-63.15, -17.78],
      ]);

      orientBusLegGeometry([option]);

      const bus = option.legs[0];
      expect(bus.kind).toBe('bus');
      if (bus.kind !== 'bus') return;
      // Las paradas y sus ids no se tocan: subida sigue siendo S1.
      expect(bus.fromStopId).toBe('S1');
      expect(bus.toStopId).toBe('S2');
      expect(bus.geometry?.coordinates).toEqual([
        [-63.15, -17.78],
        [-63.16, -17.79],
        [-63.17, -17.8],
      ]);
    });

    it('deja intacta una geometría que ya sigue el sentido de las paradas', () => {
      const coordinates = [
        [-63.15, -17.78],
        [-63.16, -17.79],
        [-63.17, -17.8],
      ];
      const option = optionWith(coordinates);

      orientBusLegGeometry([option]);

      const bus = option.legs[0];
      if (bus.kind !== 'bus') return;
      expect(bus.geometry?.coordinates).toEqual(coordinates);
    });
  });

  describe('connectWalkAndBusGeometry', () => {
    /**
     * Avenida de doble calzada: el micro va por el carril (12 m al este de la
     * parada) y la caminata acaba en la parada de la acera.
     */
    const STOP_LON = -63.15014;
    const BUS_LON = STOP_LON + 0.000113;

    const optionWith = (busCoordinates: number[][]): JourneyOption => {
      const stopLon = STOP_LON;
      const stopLat = -17.78;
      return {
        type: 'direct',
        departAt: '06:00:00',
        arriveAt: '06:20:00',
        durationMinutes: 20,
        walkToStop: { id: 'S1', name: 'Subida', distanceMeters: 0 },
        walkFromStop: { id: 'S2', name: 'Bajada', distanceMeters: 0 },
        legs: [
          {
            kind: 'walk',
            durationMinutes: 2,
            distanceMeters: 120,
            geometry: {
              type: 'LineString',
              coordinates: [
                [-63.1512, -17.7812],
                [stopLon - 0.00005, -17.7805],
                [stopLon, -17.7801],
              ],
            },
          },
          {
            kind: 'bus',
            routeId: 'R1',
            routeShortName: 'R1',
            routeColor: null,
            tripId: 'T1',
            fromStopId: 'S1',
            toStopId: 'S2',
            departAt: '06:00:00',
            arriveAt: '06:20:00',
            stops: 2,
            fromStop: { id: 'S1', name: 'Subida', lat: stopLat, lon: stopLon },
            toStop: {
              id: 'S2',
              name: 'Bajada',
              lat: stopLat - 0.02,
              lon: stopLon,
            },
            geometry: { type: 'LineString', coordinates: busCoordinates },
          },
          {
            kind: 'walk',
            durationMinutes: 1,
            distanceMeters: 40,
            geometry: {
              type: 'LineString',
              coordinates: [
                [stopLon, stopLat - 0.0196],
                [stopLon + 0.0004, stopLat - 0.021],
              ],
            },
          },
        ],
      } as JourneyOption;
    };

    it('no mueve el trazado del micro: el shape es la verdad de la calzada', () => {
      const busCoordinates = [
        [BUS_LON, -17.78],
        [BUS_LON, -17.79],
        [BUS_LON, -17.8],
      ];
      const option = optionWith(busCoordinates);

      connectWalkAndBusGeometry([option]);

      const bus = option.legs[1];
      if (bus.kind !== 'bus') return;
      expect(bus.geometry?.coordinates).toEqual(busCoordinates);
    });

    it('hace que la caminata acabe exactamente donde arranca el micro', () => {
      const option = optionWith([
        [BUS_LON, -17.78],
        [BUS_LON, -17.8],
      ]);

      connectWalkAndBusGeometry([option]);

      const walk = option.legs[0];
      const bus = option.legs[1];
      if (walk.kind !== 'walk' || bus.kind !== 'bus') return;
      const walkCoords = walk.geometry?.coordinates ?? [];
      const busCoords = bus.geometry?.coordinates ?? [];
      expect(walkCoords[walkCoords.length - 1]).toEqual(busCoords[0]);
    });

    it('hace que la caminata de bajada arranque donde termina el micro', () => {
      const option = optionWith([
        [BUS_LON, -17.78],
        [BUS_LON, -17.8],
      ]);

      connectWalkAndBusGeometry([option]);

      const bus = option.legs[1];
      const walk = option.legs[2];
      if (walk.kind !== 'walk' || bus.kind !== 'bus') return;
      const walkCoords = walk.geometry?.coordinates ?? [];
      const busCoords = bus.geometry?.coordinates ?? [];
      expect(walkCoords[0]).toEqual(busCoords[busCoords.length - 1]);
    });

    it('no inventa un salto si el micro pasa lejos de la caminata', () => {
      const lejos = [
        [STOP_LON + 0.01, -17.78],
        [STOP_LON + 0.01, -17.8],
      ];
      const option = optionWith(lejos);
      const before = (
        option.legs[0] as { geometry?: { coordinates: number[][] } }
      ).geometry?.coordinates;

      connectWalkAndBusGeometry([option]);

      const walk = option.legs[0];
      if (walk.kind !== 'walk') return;
      expect(walk.geometry?.coordinates).toEqual(before);
    });
  });

  describe('planJourneys', () => {
    const H = 3600;
    const t = (h: number, m = 0, s = 0) => h * H + m * 60 + s;

    /** Trip de prueba: S1 → S2 → S3 → S4, 06:00-08:00, headway 300. */
    const makeTrip = (
      tripId: string,
      routeId: string,
      stops: Array<[string, number]>, // [stopId, arrivalSec]
      overrides: Partial<TripSchedule> = {}
    ): TripSchedule => ({
      tripId,
      routeId,
      routeShortName: routeId,
      routeColor: 'D35400',
      directionId: 0,
      headsign: 'Ida',
      startTimeSec: t(6),
      endTimeSec: t(8),
      headwaySeconds: 300,
      stops: stops.map(([stopId, arr], i) => ({
        stopId,
        sequence: i + 1,
        arrivalSec: arr,
        departureSec: arr,
      })),
      ...overrides,
    });

    /**
     * Coordenadas por parada: el guard de par subida/bajada (<150 m)
     * exige que las candidatas de prueba estén separadas de verdad.
     */
    const stopCoords: Record<string, { lat: number; lon: number }> = {
      S1: { lat: -17.78, lon: -63.15 },
      S4: { lat: -17.789, lon: -63.159 },
    };

    const cand = (
      stopId: string,
      distanceMeters: number,
      name = `Stop ${stopId}`
    ): CandidateStop => ({
      stopId,
      name,
      ...(stopCoords[stopId] ?? { lat: -17.78, lon: -63.15 }),
      distanceMeters,
    });

    it('devuelve vacío si no hay paradas de origen', () => {
      const options = planJourneys({
        originStops: [],
        destStops: [cand('S4', 100)],
        trips: [
          makeTrip('T1', 'R1', [
            ['S1', t(6)],
            ['S4', t(6, 30)],
          ]),
        ],
        timeSec: t(6),
        maxResults: 3,
      });
      expect(options).toEqual([]);
    });

    it('encuentra opción directa con horarios desplazados por headway', () => {
      // Trip llega a S4 a las 06:30. timeSec=06:00, walk 80m=1min → notBefore 06:01.
      // k=0 → sale 06:00 (aunque < 06:01? no: 06:00 < 06:01 → k=1 → 06:05)
      const trip = makeTrip('T1', 'R1', [
        ['S1', t(6)],
        ['S4', t(6, 30)],
      ]);
      const options = planJourneys({
        originStops: [cand('S1', 80)],
        destStops: [cand('S4', 160)],
        trips: [trip],
        timeSec: t(6),
        maxResults: 3,
      });
      expect(options).toHaveLength(1);
      const opt = options[0];
      expect(opt.type).toBe('direct');
      // walk 80m=1min → notBefore 06:01 → k=1 → micro 06:05, arrive bus 06:35, +walk 160m=2min → 06:37.
      // Puerta a puerta: se sale del origen 1 min antes del micro (06:04).
      expect(opt.departAt).toBe('06:04:00');
      expect(opt.arriveAt).toBe('06:37:00');
      expect(opt.durationMinutes).toBe(33);
      expect((opt.legs[1] as { departAt: string }).departAt).toBe('06:05:00');
      expect(opt.legs).toHaveLength(3);
      expect(opt.legs[0].kind).toBe('walk');
      expect(opt.legs[1].kind).toBe('bus');
      expect(opt.legs[2].kind).toBe('walk');
      const bus = opt.legs[1] as never as {
        tripId: string;
        fromStopId: string;
        toStopId: string;
        stops: number;
      };
      expect(bus.tripId).toBe('T1');
      expect(bus.fromStopId).toBe('S1');
      expect(bus.toStopId).toBe('S4');
      expect(bus.stops).toBe(2);
    });

    it('ignora directos donde el destino va antes que el origen en el trip', () => {
      // S4 antes que S1 → no hay dirección válida
      const trip = makeTrip('T1', 'R1', [
        ['S4', t(6)],
        ['S1', t(6, 10)],
      ]);
      const options = planJourneys({
        originStops: [cand('S1', 50)],
        destStops: [cand('S4', 50)],
        trips: [trip],
        timeSec: t(6),
        maxResults: 3,
      });
      expect(options.filter((o) => o.type === 'direct')).toHaveLength(0);
    });

    it('descarta opciones cuyas paradas de subir y bajar están a < 150 m', () => {
      // Subirse y bajarse en paradas contiguas (~50 m) es un absurdo: el
      // viaje "origen → destino" no debe devolverse (regresión: al arrastrar
      // los puntos juntos el plan ofrecía micro de una parada a la de al lado).
      const trip = makeTrip('T1', 'R1', [
        ['S1', t(6)],
        ['S4', t(6, 10)],
      ]);
      const options = planJourneys({
        originStops: [{ ...cand('S1', 50), lat: -17.78, lon: -63.15 }],
        destStops: [{ ...cand('S4', 60), lat: -17.7803, lon: -63.1504 }],
        trips: [trip],
        timeSec: t(6),
        maxResults: 3,
      });
      expect(options).toEqual([]);
    });

    it('conserva las opciones con paradas de subir/bajar bien separadas', () => {
      const trip = makeTrip('T1', 'R1', [
        ['S1', t(6)],
        ['S4', t(6, 10)],
      ]);
      const options = planJourneys({
        originStops: [cand('S1', 50)],
        destStops: [cand('S4', 60)], // ~1.4 km en el fixture
        trips: [trip],
        timeSec: t(6),
        maxResults: 3,
      });
      expect(options).toHaveLength(1);
    });

    it('encuentra opción con 1 transbordo en parada intermedia', () => {
      // Trip A: S1 → S2 (intermedia). Trip B: S2 → S4.
      const tripA = makeTrip('TA', 'RA', [
        ['S1', t(6)],
        ['S2', t(6, 10)],
      ]);
      const tripB = makeTrip(
        'TB',
        'RB',
        [
          ['S2', t(6, 15)],
          ['S4', t(6, 40)],
        ],
        { directionId: 1 }
      );
      const options = planJourneys({
        originStops: [cand('S1', 0)],
        destStops: [cand('S4', 0)],
        trips: [tripA, tripB],
        timeSec: t(6),
        maxResults: 5,
      });
      const transfer = options.find((o) => o.type === 'transfer');
      expect(transfer).toBeDefined();
      // A sale 06:00 (walk 0), llega S2 06:10. B sale S2 06:15 (k=0), llega S4 06:40.
      expect(transfer!.departAt).toBe('06:00:00');
      expect(transfer!.arriveAt).toBe('06:40:00');
      expect(transfer!.durationMinutes).toBe(40);
      // legs: walk, busA, busB, walk
      expect(transfer!.legs.map((l) => l.kind)).toEqual([
        'walk',
        'bus',
        'bus',
        'walk',
      ]);
    });

    it('ordena por duración y limita a maxResults', () => {
      // Trip rápido (llega 06:20) y trip lento (llega 06:50), ambos directos
      const fast = makeTrip('TF', 'RF', [
        ['S1', t(6)],
        ['S4', t(6, 20)],
      ]);
      const slow = makeTrip('TS', 'RS', [
        ['S1', t(6)],
        ['S4', t(6, 50)],
      ]);
      const options = planJourneys({
        originStops: [cand('S1', 0)],
        destStops: [cand('S4', 0)],
        trips: [slow, fast],
        timeSec: t(6),
        maxResults: 1,
      });
      expect(options).toHaveLength(1);
      expect(options[0].legs[1]).toMatchObject({ tripId: 'TF' });
      expect(options[0].durationMinutes).toBe(20);
    });

    it('prioriza viaje directo sobre transbordo levemente más corto por penalización cruceña', () => {
      // Directo: S1 -> S4 toma 35 min (llega 06:35).
      const directTrip = makeTrip('TD', 'RD', [
        ['S1', t(6)],
        ['S4', t(6, 35)],
      ]);
      // Transbordo: S1 -> S2 (10 min) + S2 -> S4 (sale 06:15, llega 06:30 = 30 min).
      // Duración neta transbordo: 30 min. Duración directo: 35 min.
      // Con TRANSFER_PENALTY_MINUTES (10 min), el costo del transbordo es 40 min,
      // por lo que el pasajero cruceño recibe primero el micro directo (1 pasaje).
      const tripA = makeTrip('TA', 'RA', [
        ['S1', t(6)],
        ['S2', t(6, 10)],
      ]);
      const tripB = makeTrip(
        'TB',
        'RB',
        [
          ['S2', t(6, 15)],
          ['S4', t(6, 30)],
        ],
        { directionId: 1 }
      );

      const options = planJourneys({
        originStops: [cand('S1', 0)],
        destStops: [cand('S4', 0)],
        trips: [directTrip, tripA, tripB],
        timeSec: t(6),
        maxResults: 2,
      });

      expect(options.length).toBeGreaterThanOrEqual(2);
      expect(options[0].type).toBe('direct');
      expect(options[0].durationMinutes).toBe(35);
      expect(options[1].type).toBe('transfer');
      expect(options[1].durationMinutes).toBe(30);
    });
  });

  describe('caminata mínima y primer micro de un transbordo', () => {
    const t = (h: number, m = 0) => h * 3600 + m * 60;
    /** ~1 m por cada 0.000009° de latitud: helpers para medir en metros. */
    const north = (meters: number) => -17.78 + meters / 111_320;

    const stop = (
      stopId: string,
      arr: number,
      i: number,
      latMeters?: number
    ) => ({
      stopId,
      sequence: i + 1,
      arrivalSec: arr,
      departureSec: arr,
      ...(latMeters === undefined
        ? {}
        : { lat: north(latMeters), lon: -63.15 }),
    });

    const trip = (
      tripId: string,
      stops: TripSchedule['stops'],
      directionId = 0
    ): TripSchedule => ({
      tripId,
      routeId: tripId,
      routeShortName: tripId,
      routeColor: 'D35400',
      directionId,
      headsign: null,
      startTimeSec: t(6),
      endTimeSec: t(8),
      headwaySeconds: 300,
      stops,
    });

    const cand = (
      stopId: string,
      distanceMeters: number,
      latMeters: number
    ): CandidateStop => ({
      stopId,
      name: stopId,
      lat: north(latMeters),
      lon: -63.15,
      distanceMeters,
    });

    it('no hace caminar hasta una parada más adelante de la MISMA línea', () => {
      // El usuario está a 100 m de S1; S5 (450 m) es la parada SIGUIENTE del
      // mismo micro. Antes la duración contaba desde que sale el micro, así
      // que subir en S5 "duraba" 2 min menos y ganaba: se caminaban 450 m
      // por un tramo que el micro ya recorría.
      const t1 = trip('T1', [
        stop('S1', t(6), 0, 0),
        stop('S5', t(6, 2), 1, 450),
        stop('S4', t(6, 30), 2, 5000),
      ]);
      const options = planJourneys({
        originStops: [cand('S1', 100, 0), cand('S5', 450, 450)],
        destStops: [cand('S4', 0, 5000)],
        trips: [t1],
        timeSec: t(5, 50),
        maxResults: 5,
      });
      // Una sola opción por micro, subiendo en la parada cercana.
      expect(options).toHaveLength(1);
      expect(options[0].walkToStop.id).toBe('S1');
      expect(totalWalkMeters(options[0])).toBe(100);
      // Puerta a puerta: 2 min a pie + 30 min de micro.
      expect(options[0].departAt).toBe('05:58:00');
      expect(options[0].durationMinutes).toBe(32);
    });

    it('descarta transbordos cuyo primer micro recorre < 1 km', () => {
      // TA solo lleva 200 m (S1 → S2) antes de bajarse para tomar TB.
      const ta = trip('TA', [
        stop('S1', t(6), 0, 0),
        stop('S2', t(6, 2), 1, 200),
      ]);
      const tb = trip(
        'TB',
        [stop('S2', t(6, 5), 0, 200), stop('S4', t(6, 30), 1, 5000)],
        1
      );
      const options = planJourneys({
        originStops: [cand('S1', 0, 0)],
        destStops: [cand('S4', 0, 5000)],
        trips: [ta, tb],
        timeSec: t(6),
        maxResults: 5,
      });
      expect(options.filter((o) => o.type === 'transfer')).toHaveLength(0);
    });

    it('conserva transbordos cuyo primer micro recorre ≥ 1 km', () => {
      const ta = trip('TA', [
        stop('S1', t(6), 0, 0),
        stop('S6', t(6, 3), 1, 600),
        stop('S2', t(6, 6), 2, 1200),
      ]);
      const tb = trip(
        'TB',
        [stop('S2', t(6, 10), 0, 1200), stop('S4', t(6, 30), 1, 5000)],
        1
      );
      const options = planJourneys({
        originStops: [cand('S1', 0, 0)],
        destStops: [cand('S4', 0, 5000)],
        trips: [ta, tb],
        timeSec: t(6),
        maxResults: 5,
      });
      const transfer = options.find((o) => o.type === 'transfer');
      expect(transfer).toBeDefined();
      expect(transfer!.legs[1]).toMatchObject({
        fromStopId: 'S1',
        toStopId: 'S2',
      });
    });

    it('dropShortFirstRideTransfers mide la geometría del primer micro (OTP)', () => {
      const transferWith = (firstRideMeters: number): JourneyOption => ({
        type: 'transfer',
        departAt: '06:00:00',
        arriveAt: '06:30:00',
        durationMinutes: 30,
        walkToStop: { id: 'S1', name: 'S1', distanceMeters: 0 },
        walkFromStop: { id: 'S4', name: 'S4', distanceMeters: 0 },
        legs: [
          {
            kind: 'bus',
            routeId: 'A',
            routeShortName: 'A',
            routeColor: null,
            tripId: 'TA',
            fromStopId: 'S1',
            toStopId: 'S2',
            departAt: '06:00:00',
            arriveAt: '06:05:00',
            stops: 2,
            geometry: {
              type: 'LineString',
              coordinates: [
                [-63.15, north(0)],
                [-63.15, north(firstRideMeters)],
              ],
            },
          },
          {
            kind: 'bus',
            routeId: 'B',
            routeShortName: 'B',
            routeColor: null,
            tripId: 'TB',
            fromStopId: 'S2',
            toStopId: 'S4',
            departAt: '06:10:00',
            arriveAt: '06:30:00',
            stops: 2,
          },
        ],
      });
      const kept = dropShortFirstRideTransfers([
        transferWith(200),
        transferWith(1500),
      ]);
      expect(kept).toHaveLength(1);
      expect(
        kept[0].legs[0].kind === 'bus' && kept[0].legs[0].geometry
      ).toBeTruthy();
    });
  });

  describe('rankAndCut (política compartida con OTP)', () => {
    const makeOption = (
      type: 'direct' | 'transfer',
      durationMinutes: number,
      departAt = '06:00:00'
    ): JourneyOption => ({
      type,
      departAt,
      arriveAt: '07:00:00',
      durationMinutes,
      walkToStop: { id: 'S1', name: 'P1', distanceMeters: 100 },
      walkFromStop: { id: 'S2', name: 'P2', distanceMeters: 100 },
      legs: [],
    });

    it('penaliza transbordos (directo 45 gana a transbordo 40)', () => {
      const ranked = rankAndCut(
        [makeOption('transfer', 40), makeOption('direct', 45)],
        2
      );
      expect(ranked[0].type).toBe('direct');
    });

    it('la duración desempata ANTES del tipo: transbordo 30 (costo 40) < directo 40', () => {
      const ranked = rankAndCut(
        [
          makeOption('transfer', 30), // costo 40
          makeOption('direct', 40), // costo 40, duración mayor
        ],
        2
      );
      expect(ranked.map((o) => o.type)).toEqual(['transfer', 'direct']);
    });

    it('recorta a maxResults', () => {
      const ranked = rankAndCut(
        [
          makeOption('direct', 10),
          makeOption('direct', 20),
          makeOption('direct', 30),
        ],
        2
      );
      expect(ranked).toHaveLength(2);
      expect(ranked.map((o) => o.durationMinutes)).toEqual([10, 20]);
    });

    it('orden determinístico en empate total: sale antes el que parte antes', () => {
      const ranked = rankAndCut(
        [
          makeOption('direct', 40, '06:10:00'),
          makeOption('direct', 40, '06:05:00'),
        ],
        2
      );
      expect(ranked[0].departAt).toBe('06:05:00');
    });
  });
});
