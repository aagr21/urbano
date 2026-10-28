import {
  OtpJourneyRouter,
  mapItinerary,
  formatHmsInTz,
  laPazIsoFromTimeSec,
  stripFeedId,
  normalizeColor,
  OtpItinerary,
  OtpLeg,
} from './otp-journey-router';
import { JourneyOption } from '../../domain/journey.model';
import { AppConfigService } from '../../../../core/config/app-config.service';

const configWithOtp = {
  otpUrl: 'http://otp.local:8081/otp',
  otpTimeoutMs: 500,
} as AppConfigService;

const configWithoutOtp = {
  otpUrl: '',
  otpTimeoutMs: 500,
} as AppConfigService;

/* ---------- Fixtures en el shape de la respuesta GraphQL de OTP2 ---------- */

function walkLeg(overrides: Partial<OtpLeg> = {}): OtpLeg {
  return {
    mode: 'WALK',
    startTime: 1792663200000, // 06:00:00-04:00
    endTime: 1792663380000, // 06:03:00-04:00
    distance: 180,
    legGeometry: { points: '~sokBn~l`KzEnK' },
    ...overrides,
  };
}

function busLeg(overrides: Partial<OtpLeg> = {}): OtpLeg {
  return {
    mode: 'BUS',
    startTime: 1792663380000, // 06:03:00-04:00
    endTime: 1792665540000, // 06:39:00-04:00
    distance: 9876,
    intermediateStops: [{ stop: { gtfsId: 'FEED:S2' } }, { stop: { gtfsId: 'FEED:S3' } }],
    legGeometry: { points: '~sokBn~l`KzEnK' },
    from: { name: 'Parada S1', lat: -17.78, lon: -63.15, stop: { gtfsId: 'FEED:S1' } },
    to: { name: 'Parada S4', lat: -17.79, lon: -63.16, stop: { gtfsId: 'FEED:S4' } },
    route: { gtfsId: 'FEED:R1', shortName: '1', longName: 'Micro 1', color: '#D35400' },
    trip: { gtfsId: 'FEED:T1' },
    ...overrides,
  };
}

function itinerary(legs: OtpLeg[], start: string, end: string): OtpItinerary {
  return { start, end, legs };
}

function settingUpFetch(stub: unknown): void {
  (global as { fetch: unknown }).fetch = stub;
}

function okResponse(json: unknown): Response {
  return new Response(JSON.stringify(json), { status: 200 });
}

const directItinerary = itinerary(
  [walkLeg(), busLeg(), walkLeg({ startTime: 1792665540000, endTime: 1792665900000, distance: 240 })],
  '2026-10-22T06:00:00-04:00',
  '2026-10-22T06:45:00-04:00',
);

describe('helpers puros', () => {
  it('stripFeedId quita el prefijo de feed', () => {
    expect(stripFeedId('FEED:S10')).toBe('S10');
    expect(stripFeedId('S10')).toBe('S10');
    expect(stripFeedId(null)).toBe('');
  });

  it('normalizeColor deja el hex sin # (convención del contrato)', () => {
    expect(normalizeColor('#D35400')).toBe('D35400');
    expect(normalizeColor('D35400')).toBe('D35400');
    expect(normalizeColor(null)).toBeNull();
  });

  it('formatHmsInTz formatea epoch millis e ISO strings en America/La_Paz', () => {
    expect(formatHmsInTz(1792663380000)).toBe('06:03:00');
    expect(formatHmsInTz('2026-10-22T06:03:00-04:00')).toBe('06:03:00');
    expect(formatHmsInTz(null)).toBe('00:00:00');
  });

  it('laPazIsoFromTimeSec compone fecha de hoy + hora con offset -04:00', () => {
    const iso = laPazIsoFromTimeSec(6 * 3600 + 5 * 60, new Date('2026-01-02T12:00:00Z'));
    expect(iso).toMatch(/T06:05:00(-05:00|-04:00)$/);
  });
});

describe('mapItinerary', () => {
  it('mapea un itinerario directo: walk + bus + walk', () => {
    const option = mapItinerary(directItinerary) as JourneyOption;

    expect(option.type).toBe('direct');
    expect(option.departAt).toBe('06:00:00');
    expect(option.arriveAt).toBe('06:45:00');
    expect(option.durationMinutes).toBe(45);

    // walkToStop es la parada de embarque del primer micro, con el total
    // real de metros caminados para llegar a ella (por la red viaria).
    expect(option.walkToStop).toEqual({
      id: 'S1', name: 'Parada S1', distanceMeters: 180, lat: -17.78, lon: -63.15,
    });
    expect(option.walkFromStop?.id).toBe('S4');
    expect(option.walkFromStop?.distanceMeters).toBe(240);

    expect(option.legs.map((l) => l.kind)).toEqual(['walk', 'bus', 'walk']);

    const bus = option.legs[1] as Extract<JourneyOption['legs'][number], { kind: 'bus' }>;
    expect(bus.routeShortName).toBe('1');
    expect(bus.routeColor).toBe('D35400'); // sin #
    expect(bus.tripId).toBe('T1');
    expect(bus.fromStopId).toBe('S1');
    expect(bus.toStopId).toBe('S4');
    expect(bus.departAt).toBe('06:03:00');
    expect(bus.stops).toBe(4); // 2 intermedias + subida + bajada
    // Geometría decodificada (polyline de OTP → GeoJSON [lon, lat])
    expect(bus.geometry?.coordinates).toEqual([
      [-63.15, -17.78],
      [-63.152, -17.7811],
    ]);
    const firstWalk = option.legs[0] as Extract<JourneyOption['legs'][number], { kind: 'walk' }>;
    // Geometría de caminata por la red viaria (2 puntos del fixture)
    expect(firstWalk.geometry?.coordinates).toEqual([
      [-63.15, -17.78],
      [-63.152, -17.7811],
    ]);
    expect(firstWalk.durationMinutes).toBe(3); // 180 m a 80 m/min
  });

  it('mapea un itinerario con transbordo (2 micros)', () => {
    const option = mapItinerary(itinerary(
      [
        walkLeg(),
        busLeg(),
        busLeg({
          from: { name: 'Parada S4', lat: -17.79, lon: -63.16, stop: { gtfsId: 'FEED:S4' } },
          to: { name: 'Parada S5', lat: -17.8, lon: -63.17, stop: { gtfsId: 'FEED:S5' } },
          route: { gtfsId: 'FEED:R2', shortName: '2', longName: 'Micro 2', color: '3498DB' },
          trip: { gtfsId: 'FEED:T2' },
        }),
        walkLeg({ startTime: 1792666500000, distance: 100 }),
      ],
      '2026-10-22T06:00:00-04:00',
      '2026-10-22T07:00:00-04:00',
    )) as JourneyOption;

    expect(option.type).toBe('transfer');
    expect(option.walkFromStop?.id).toBe('S5');
    expect(option.walkFromStop?.distanceMeters).toBe(100);
  });

  it('descarta itinerarios 100% a pie (sin micro)', () => {
    expect(mapItinerary(itinerary(
      [walkLeg({ distance: 800 })],
      '2026-10-22T06:00:00-04:00',
      '2026-10-22T06:10:00-04:00',
    ))).toBeNull();
  });

  it('descarta el itinerario si el micro no tiene parada con id', () => {
    expect(mapItinerary(itinerary(
      [busLeg({ from: { name: 'x', lat: 1, lon: 1 } })],
      '2026-10-22T06:00:00-04:00',
      '2026-10-22T06:10:00-04:00',
    ))).toBeNull();
  });
});

describe('OtpJourneyRouter.plan', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  const query = {
    originLat: -17.78,
    originLon: -63.15,
    destLat: -17.79,
    destLon: -63.16,
    timeSec: 6 * 3600,
    maxResults: 3,
  };

  function stubFetchReturning(json: unknown): jest.Mock {
    const stub = jest.fn().mockResolvedValue(okResponse(json));
    settingUpFetch(stub);
    return stub;
  }

  function otpResponse(itineraries: OtpItinerary[]): unknown {
    return { data: { planConnection: { edges: itineraries.map((node) => ({ node })) } } };
  }

  it('consulta /index/graphql por POST y mapea los itinerarios', async () => {
    const stub = stubFetchReturning(otpResponse([directItinerary]));

    const options = await new OtpJourneyRouter(configWithOtp).plan(query);

    expect(stub).toHaveBeenCalledWith(
      'http://otp.local:8081/otp/index/graphql',
      expect.objectContaining({ method: 'POST' }),
    );
    const body = JSON.parse(
      ((stub.mock.calls[0] as unknown[])[1] as { body: string }).body,
    );
    expect(body.variables.from).toEqual({
      location: { coordinate: { latitude: -17.78, longitude: -63.15 } },
    });
    expect(body.variables.to.location.coordinate).toEqual({
      latitude: -17.79, longitude: -63.16,
    });
    expect(body.variables.first).toBe(3);
    expect(body.variables.dateTime.earliestDeparture).toMatch(/-0[45]:00$/);
    expect(options).toHaveLength(1);
    expect(options![0].walkToStop?.id).toBe('S1');
  });

  it('devuelve null con OTP_URL vacío (motor desactivado)', async () => {
    const stub = stubFetchReturning(otpResponse([directItinerary]));

    expect(await new OtpJourneyRouter(configWithoutOtp).plan(query)).toBeNull();
    expect(stub).not.toHaveBeenCalled();
  });

  it('devuelve null si OTP falla (HTTP 503 / error de red / GraphQL errors)', async () => {
    settingUpFetch(jest.fn().mockResolvedValue(new Response('no', { status: 503 })));
    expect(await new OtpJourneyRouter(configWithOtp).plan(query)).toBeNull();

    settingUpFetch(jest.fn().mockRejectedValue(new Error('ECONNREFUSED')));
    expect(await new OtpJourneyRouter(configWithOtp).plan(query)).toBeNull();

    stubFetchReturning({ errors: [{ message: 'bad' }] });
    expect(await new OtpJourneyRouter(configWithOtp).plan(query)).toBeNull();
  });

  it('devuelve [] si OTP responde ok pero sin itinerarios', async () => {
    stubFetchReturning(otpResponse([]));
    expect(await new OtpJourneyRouter(configWithOtp).plan(query)).toEqual([]);
  });

  it('recorta resultados a maxResults', async () => {
    const itineraries = Array.from({ length: 5 }, (_, i) => itinerary(
      [walkLeg(), busLeg({ trip: { gtfsId: `FEED:T${i}` } })],
      '2026-10-22T06:00:00-04:00',
      '2026-10-22T06:45:00-04:00',
    ));
    stubFetchReturning(otpResponse(itineraries));
    const options = await new OtpJourneyRouter(configWithOtp).plan(query);
    expect(options).toHaveLength(3);
  });
});
