import { GtfsRow, gtfs } from './gtfs-zip.reader';
import {
  GtfsRowSource,
  buildShapeRows,
  mappedRows,
  readShapePoints,
  rowMappers,
} from './gtfs-row-mappers';

/** Fuente de filas en memoria: un archivo GTFS por nombre. */
const source = (files: Record<string, GtfsRow[]>): GtfsRowSource => ({
  async *rows(fileName: string) {
    for (const row of files[fileName] ?? []) yield row;
  },
});

const collect = async <T>(iterable: AsyncIterable<T>): Promise<T[]> => {
  const out: T[] = [];
  for await (const item of iterable) out.push(item);
  return out;
};

describe('gtfs-row-mappers', () => {
  describe('helpers de campos (gtfs)', () => {
    it('vacío o ausente: cadena vacía, null o 0 según el helper', () => {
      const row = { a: '  ', b: ' x ' };
      expect(gtfs.str(row, 'a')).toBe('');
      expect(gtfs.str(row, 'nope')).toBe('');
      expect(gtfs.str(row, 'b')).toBe('x');
      expect(gtfs.nullableStr(row, 'a')).toBeNull();
      expect(gtfs.num(row, 'a')).toBe(0);
      expect(gtfs.nullableNum(row, 'a')).toBeNull();
      expect(gtfs.int01(row, 'nope')).toBe(0);
    });

    it('bool01 solo es verdadero con «1»', () => {
      expect(gtfs.bool01({ d: '1' }, 'd')).toBe(true);
      expect(gtfs.bool01({ d: '0' }, 'd')).toBe(false);
      expect(gtfs.bool01({ d: 'true' }, 'd')).toBe(false);
    });
  });

  describe('rowMappers', () => {
    it('agency sin id usa «default»', () => {
      expect(rowMappers.agency({ agency_name: 'SCZ' }).id).toBe('default');
      expect(
        rowMappers.agency({ agency_id: 'A1', agency_name: 'SCZ' }).id
      ).toBe('A1');
    });

    it('service lee los siete días y las fechas', () => {
      const service = rowMappers.service({
        service_id: 'LV',
        monday: '1',
        tuesday: '1',
        wednesday: '1',
        thursday: '1',
        friday: '1',
        saturday: '0',
        sunday: '0',
        start_date: '20260101',
        end_date: '20261231',
      });
      expect(service).toMatchObject({
        id: 'LV',
        monday: true,
        friday: true,
        saturday: false,
        sunday: false,
        startDate: '20260101',
        endDate: '20261231',
      });
    });

    it('feed_info numera desde 1 según su posición', () => {
      expect(rowMappers.feedInfo({}, 0).id).toBe(1);
      expect(rowMappers.feedInfo({ feed_version: 'v2' }, 2)).toMatchObject({
        id: 3,
        version: 'v2',
      });
    });

    it('route deja los contadores en 0 y sin imagen (se calculan después)', () => {
      const route = rowMappers.route({
        route_id: '17',
        route_short_name: '17',
        route_long_name: '',
        route_type: '3',
        route_color: 'D35400',
      });
      expect(route).toEqual({
        id: '17',
        agencyId: null,
        shortName: '17',
        longName: null,
        description: null,
        type: 3,
        color: 'D35400',
        textColor: null,
        imageUrl: null,
        stopCount: 0,
        directions: 0,
        tripCount: 0,
      });
    });

    it('stop convierte las coordenadas a número y deja geom para PostGIS', () => {
      expect(
        rowMappers.stop({
          stop_id: 'S1',
          stop_name: 'Plaza',
          stop_lat: '-17.7833',
          stop_lon: '-63.1821',
        })
      ).toMatchObject({ id: 'S1', lat: -17.7833, lon: -63.1821, geom: null });
    });

    it('trip sin direction_id ni shape: ida y shape nulo', () => {
      expect(
        rowMappers.trip({ trip_id: 'T', route_id: '17', service_id: 'LV' })
      ).toMatchObject({ directionId: 0, shapeId: null, wheelchairBoarding: 0 });
    });

    it('stop_time conserva los horarios como texto (pueden pasar de 24 h)', () => {
      const stopTime = rowMappers.stopTime({
        trip_id: 'T',
        stop_sequence: '12',
        stop_id: 'S1',
        arrival_time: '25:10:00',
        departure_time: '25:10:30',
        shape_dist_traveled: '',
      });
      expect(stopTime).toMatchObject({
        stopSequence: 12,
        arrivalTime: '25:10:00',
        departureTime: '25:10:30',
        shapeDistTraveled: null,
      });
    });

    it('frequency lee el headway en segundos', () => {
      expect(
        rowMappers.frequency({
          trip_id: 'T',
          start_time: '06:00:00',
          end_time: '22:00:00',
          headway_secs: '600',
        })
      ).toEqual({
        tripId: 'T',
        startTime: '06:00:00',
        endTime: '22:00:00',
        headwaySeconds: 600,
        exactTimes: 0,
      });
    });
  });

  it('mappedRows aplica el mapeo con su índice, fila a fila', async () => {
    const rows = await collect(
      mappedRows(
        source({ 'feed_info.txt': [{}, {}] }),
        'feed_info.txt',
        rowMappers.feedInfo
      )
    );
    expect(rows.map((r) => r.id)).toEqual([1, 2]);
  });

  describe('shapes', () => {
    const pt = (shape: string, seq: number, lat: number, lon: number) => ({
      shape_id: shape,
      shape_pt_sequence: String(seq),
      shape_pt_lat: String(lat),
      shape_pt_lon: String(lon),
    });

    it('agrupa por shape y ORDENA por secuencia aunque el archivo venga desordenado', async () => {
      const points = await readShapePoints(
        source({
          'shapes.txt': [
            pt('A', 3, -17.3, -63.3),
            pt('B', 1, -17.9, -63.9),
            pt('A', 1, -17.1, -63.1),
            pt('A', 2, -17.2, -63.2),
          ],
        })
      );
      expect(points.get('A')).toEqual([
        { lat: -17.1, lon: -63.1 },
        { lat: -17.2, lon: -63.2 },
        { lat: -17.3, lon: -63.3 },
      ]);
      expect(points.get('B')).toHaveLength(1);
    });

    it('con secuencias repetidas conserva el orden de lectura', async () => {
      const points = await readShapePoints(
        source({
          'shapes.txt': [pt('A', 1, -17.1, -63.1), pt('A', 1, -17.2, -63.2)],
        })
      );
      expect(points.get('A')?.map((p) => p.lat)).toEqual([-17.1, -17.2]);
    });

    it('buildShapeRows: coordenadas [lon, lat], conteo y bbox', () => {
      const [row] = buildShapeRows(
        new Map([
          [
            'A',
            [
              { lat: -17.8, lon: -63.2 },
              { lat: -17.7, lon: -63.1 },
              { lat: -17.9, lon: -63.15 },
            ],
          ],
        ])
      );
      expect(row).toEqual({
        id: 'A',
        pointCount: 3,
        bboxMinLon: -63.2,
        bboxMinLat: -17.9,
        bboxMaxLon: -63.1,
        bboxMaxLat: -17.7,
        coordinates: [
          [-63.2, -17.8],
          [-63.1, -17.7],
          [-63.15, -17.9],
        ],
        geom: null,
      });
    });
  });
});
