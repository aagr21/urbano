import { computeUpcomingDepartures } from './departures';
import { DepartureSourceRecord } from '../domain/route.model';

describe('computeUpcomingDepartures (cálculo puro de próximas salidas)', () => {
  // Trip base en la parada a las 06:07:18, ventana 06:00-22:00, headway 300
  const source: DepartureSourceRecord = {
    tripId: 'T97',
    directionId: 0,
    headsign: 'Ida',
    stopDepartureTime: '06:07:18',
    startTime: '06:00:00',
    endTime: '22:00:00',
    headwaySeconds: 300,
  };

  const toSec = (s: string) => {
    const [h, m, sec] = s.split(':').map(Number);
    return h * 3600 + m * 60 + sec;
  };

  it('devuelve la primera salida >= fromSeconds', () => {
    const from = toSec('06:05:00');
    const result = computeUpcomingDepartures([source], from, 20);
    expect(result).toHaveLength(20);
    // primera: base 06:07:18 (k=0) ya que 06:07:18 >= 06:05
    expect(result[0].time).toBe('06:07:18');
    expect(result[1].time).toBe('06:12:18');
    expect(result[0].tripId).toBe('T97');
    expect(result[0].realTime).toBe(false);
    expect(result[0].headwaySeconds).toBe(300);
  });

  it('salta a la siguiente repetición si fromSeconds cae entre salidas', () => {
    const from = toSec('06:10:00');
    const result = computeUpcomingDepartures([source], from, 3);
    // 06:07:18 < 06:10 → siguiente 06:12:18
    expect(result.map((r) => r.time)).toEqual([
      '06:12:18',
      '06:17:18',
      '06:22:18',
    ]);
  });

  it('respeta maxResults', () => {
    const result = computeUpcomingDepartures([source], toSec('06:00:00'), 5);
    expect(result).toHaveLength(5);
  });

  it('mezcla y ordena varias fuentes por hora', () => {
    const other: DepartureSourceRecord = {
      ...source,
      tripId: 'T98',
      directionId: 1,
      headsign: 'Vuelta',
      stopDepartureTime: '06:02:00',
    };
    const result = computeUpcomingDepartures(
      [source, other],
      toSec('06:00:00'),
      4,
    );
    // other: 06:02:00, 06:07:00, 06:12:00... | source: 06:07:18, 06:12:18...
    expect(result.map((r) => r.time)).toEqual([
      '06:02:00',
      '06:07:00',
      '06:07:18',
      '06:12:00',
    ]);
  });

  it('devuelve vacío si no hay fuentes', () => {
    expect(computeUpcomingDepartures([], toSec('06:00:00'), 20)).toEqual([]);
  });
});
