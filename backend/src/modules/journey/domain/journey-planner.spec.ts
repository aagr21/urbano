import {
  planJourneys,
  walkDurationMinutes,
  nextRunDeparture,
} from './journey-planner';
import { CandidateStop, TripSchedule } from './journey.model';

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

  describe('planJourneys', () => {
    const H = 3600;
    const t = (h: number, m = 0, s = 0) => h * H + m * 60 + s;

    /** Trip de prueba: S1 → S2 → S3 → S4, 06:00-08:00, headway 300. */
    const makeTrip = (
      tripId: string,
      routeId: string,
      stops: Array<[string, number]>, // [stopId, arrivalSec]
      overrides: Partial<TripSchedule> = {},
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
      name = `Stop ${stopId}`,
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
        trips: [makeTrip('T1', 'R1', [['S1', t(6)], ['S4', t(6, 30)]])],
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
      // walk 80m=1min → notBefore 06:01 → k=1 → depart 06:05, arrive bus 06:35, +walk 160m=2min → 06:37
      expect(opt.departAt).toBe('06:05:00');
      expect(opt.arriveAt).toBe('06:37:00');
      expect(opt.durationMinutes).toBe(32);
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
      const tripB = makeTrip('TB', 'RB', [
        ['S2', t(6, 15)],
        ['S4', t(6, 40)],
      ], { directionId: 1 });
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
      expect(transfer!.legs.map((l) => l.kind)).toEqual(['walk', 'bus', 'bus', 'walk']);
    });

    it('ordena por duración y limita a maxResults', () => {
      // Trip rápido (llega 06:20) y trip lento (llega 06:50), ambos directos
      const fast = makeTrip('TF', 'RF', [['S1', t(6)], ['S4', t(6, 20)]]);
      const slow = makeTrip('TS', 'RS', [['S1', t(6)], ['S4', t(6, 50)]]);
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
        { directionId: 1 },
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
});
