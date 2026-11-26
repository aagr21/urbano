import { CsvRow } from './gtfs-direction-fixer';
import {
  CsvTable,
  diagnoseDirections,
  idaVuelta,
  indexFeed,
  oneWaySegmentsFromOsm,
  reassignShapes,
  replaceRowBlocks,
  restrictToRoutes,
  reverseVueltas,
  shapePoints,
  stillReversedAfter,
} from './gtfs-feed-repair';

const table = (rows: CsvRow[]): CsvTable => ({
  header: rows.length ? Object.keys(rows[0]) : [],
  rows,
});

/**
 * Feed sintético: una ruta con ida por un corredor recto de 30 paradas
 * (~222 m entre ellas, ~6,4 km: el detector pide ≥ 2 km de espejo) y una vuelta por la acera de enfrente. Con
 * `duplicated` la vuelta se copia en el MISMO orden que la ida (el defecto
 * real del feed); sin él, en orden espejo (correcto).
 */
function syntheticFeed(duplicated: boolean) {
  const n = 30;
  const stops: CsvRow[] = [];
  const stopTimes: CsvRow[] = [];
  for (let i = 0; i < n; i++) {
    stops.push({
      stop_id: `I${i}`,
      stop_lat: String(-17.75 + i * 0.002),
      stop_lon: '-63.18',
    });
    stops.push({
      stop_id: `V${i}`,
      stop_lat: String(-17.75 + i * 0.002),
      stop_lon: '-63.1797',
    });
  }
  const time = (i: number) => `06:${String(i).padStart(2, '0')}:00`; // n ≤ 59
  for (let i = 0; i < n; i++) {
    stopTimes.push({
      trip_id: 'IDA',
      arrival_time: time(i),
      departure_time: time(i),
      stop_id: `I${i}`,
      stop_sequence: String(i + 1),
      shape_dist_traveled: String(i * 222),
    });
  }
  for (let i = 0; i < n; i++) {
    const stop = duplicated ? i : n - 1 - i;
    stopTimes.push({
      trip_id: 'VUELTA',
      arrival_time: time(i),
      departure_time: time(i),
      stop_id: `V${stop}`,
      stop_sequence: String(i + 1),
      shape_dist_traveled: String(i * 222),
    });
  }
  return {
    trips: table([
      { route_id: '17', trip_id: 'IDA', direction_id: '0', shape_id: 'S_IDA' },
      {
        route_id: '17',
        trip_id: 'VUELTA',
        direction_id: '1',
        shape_id: 'S_VUELTA',
      },
    ]),
    stops: table(stops),
    // Desordenadas a propósito: el índice debe ordenarlas por secuencia.
    stopTimes: table([...stopTimes].reverse()),
    shapes: table([
      {
        shape_id: 'S_IDA',
        shape_pt_lat: '-17.749',
        shape_pt_lon: '-63.18',
        shape_pt_sequence: '2',
      },
      {
        shape_id: 'S_IDA',
        shape_pt_lat: '-17.75',
        shape_pt_lon: '-63.18',
        shape_pt_sequence: '1',
      },
    ]),
  };
}

describe('gtfs-feed-repair', () => {
  describe('indexFeed', () => {
    it('agrupa y ordena stop_times y shapes por su secuencia', () => {
      const feed = indexFeed(syntheticFeed(false));
      const ida = feed.rowsByTrip.get('IDA') ?? [];
      expect(ida.map((r) => Number(r['stop_sequence']))).toEqual(
        Array.from({ length: 30 }, (_, i) => i + 1)
      );
      expect(shapePoints(feed, 'S_IDA')?.[0]).toEqual({
        lat: -17.75,
        lon: -63.18,
      });
      expect(feed.shapeUsage.get('S_IDA')).toBe(1);
      expect(idaVuelta(feed.tripsByRoute.get('17') ?? [])?.vuelta.tripId).toBe(
        'VUELTA'
      );
    });

    it('un shape con menos de 2 puntos o inexistente no cuenta', () => {
      const feed = indexFeed(syntheticFeed(false));
      expect(shapePoints(feed, 'NO')).toBeNull();
      expect(shapePoints(feed, null)).toBeNull();
    });
  });

  describe('paso 1: vuelta duplicada', () => {
    it('detecta la vuelta copiada en el orden de la ida', () => {
      const plan = diagnoseDirections(indexFeed(syntheticFeed(true)));
      expect(plan.reversed.map((t) => t.tripId)).toEqual(['VUELTA']);
      expect(plan.diagnoses[0].status).toBe('reversed');
    });

    it('una vuelta en espejo está bien y no se toca', () => {
      const plan = diagnoseDirections(indexFeed(syntheticFeed(false)));
      expect(plan.reversed).toEqual([]);
      expect(plan.diagnoses[0].status).toBe('ok');
    });

    it('tras invertirla, la verificación ya no la ve duplicada', () => {
      const feed = indexFeed(syntheticFeed(true));
      const { reversed } = diagnoseDirections(feed);
      const fixed = reverseVueltas(feed, reversed);
      expect(fixed.get('VUELTA')?.[0]['stop_id']).toBe('V29');
      expect(stillReversedAfter(feed, reversed, fixed)).toEqual([]);
    });
  });

  describe('restrictToRoutes (--routes)', () => {
    const detected = [
      { tripId: 'a', routeId: '1', directionId: 1, shapeId: null },
      { tripId: 'b', routeId: '2', directionId: 1, shapeId: null },
    ];

    it('sin lista blanca, todo lo detectado', () => {
      expect(restrictToRoutes(detected, null).selected).toHaveLength(2);
    });

    it('con lista, filtra y avisa de las rutas pedidas que no se detectaron', () => {
      const { selected, missing } = restrictToRoutes(detected, ['2', '9']);
      expect(selected.map((t) => t.routeId)).toEqual(['2']);
      expect(missing).toEqual(['9']);
    });
  });

  describe('reconstrucción de CSV', () => {
    it('sustituye cada bloque en el lugar de su primera fila, sin duplicar', () => {
      const rows: CsvRow[] = [
        { k: 'A', v: '1' },
        { k: 'B', v: '1' },
        { k: 'A', v: '2' },
        { k: 'C', v: '1' },
      ];
      const out = replaceRowBlocks(
        rows,
        'k',
        new Map([['A', [{ k: 'A', v: 'x' }]]])
      );
      expect(out).toEqual([
        { k: 'A', v: 'x' },
        { k: 'B', v: '1' },
        { k: 'C', v: '1' },
      ]);
    });

    it('reasigna el shape solo a los viajes que cambian', () => {
      const rows: CsvRow[] = [
        { trip_id: 'IDA', shape_id: 'S1' },
        { trip_id: 'VUELTA', shape_id: 'S2' },
        { trip_id: 'OTRO', shape_id: 'S3' },
      ];
      const out = reassignShapes(
        rows,
        new Map([
          ['IDA', 'S2'],
          ['VUELTA', 'S2'],
        ])
      );
      expect(out.map((r) => r['shape_id'])).toEqual(['S2', 'S2', 'S3']);
      expect(out[1]).toBe(rows[1]);
      expect(out[2]).toBe(rows[2]);
    });
  });

  describe('oneWaySegmentsFromOsm', () => {
    const line = (
      oneway: string | undefined,
      extra: Record<string, unknown> = {}
    ) => ({
      geometry: {
        type: 'LineString',
        coordinates: [
          [-63.18, -17.75],
          [-63.18, -17.74],
        ],
      },
      properties: {
        highway: 'primary',
        ...(oneway ? { oneway } : {}),
        ...extra,
      },
    });

    it('solo calles de un sentido, orientadas en el sentido permitido', () => {
      const [forward] = oneWaySegmentsFromOsm([line('yes')]);
      expect(forward.a.lat).toBe(-17.75);
      const [backward] = oneWaySegmentsFromOsm([line('-1')]);
      expect(backward.a.lat).toBe(-17.74);
    });

    it('doble sentido y no-calles se ignoran; la rotonda es de un sentido', () => {
      expect(oneWaySegmentsFromOsm([line(undefined), line('no')])).toEqual([]);
      expect(
        oneWaySegmentsFromOsm([
          { ...line(undefined), properties: { building: 'yes' } },
        ])
      ).toEqual([]);
      expect(
        oneWaySegmentsFromOsm([line(undefined, { junction: 'roundabout' })])
      ).toHaveLength(1);
    });
  });
});
