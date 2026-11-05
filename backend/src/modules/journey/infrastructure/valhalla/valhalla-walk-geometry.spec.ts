import { AppConfigService } from '../../../../core/config/app-config.service';
import {
  ValhallaWalkGeometry,
  parseValhallaShape,
} from './valhalla-walk-geometry';

const configWithRouter = {
  walkRouterUrl: 'https://valhalla.test/route',
  walkRouterTimeoutMs: 500,
} as AppConfigService;

const configWithoutRouter = {
  walkRouterUrl: '',
  walkRouterTimeoutMs: 500,
} as AppConfigService;

function settingUpFetch(stub: unknown): void {
  (global as { fetch: unknown }).fetch = stub;
}

function okResponse(json: unknown): Response {
  return new Response(JSON.stringify(json), { status: 200 });
}

describe('parseValhallaShape', () => {
  it('acepta una LineString GeoJSON con al menos dos coordenadas', () => {
    expect(
      parseValhallaShape({
        type: 'LineString',
        coordinates: [
          [-63.18, -17.78],
          [-63.17, -17.79],
        ],
      })
    ).toEqual({
      type: 'LineString',
      coordinates: [
        [-63.18, -17.78],
        [-63.17, -17.79],
      ],
    });
  });

  it('decodifica una polilínea codificada (polyline6 del demo)', () => {
    const g = parseValhallaShape('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(g?.type).toBe('LineString');
    expect(g?.coordinates).toHaveLength(3);
  });

  it('rechaza formas degeneradas o ausentes', () => {
    expect(parseValhallaShape(undefined)).toBeNull();
    expect(parseValhallaShape('')).toBeNull();
    expect(
      parseValhallaShape({ type: 'LineString', coordinates: [[0, 0]] })
    ).toBeNull();
    expect(
      parseValhallaShape({ type: 'MultiLineString', coordinates: [] })
    ).toBeNull();
  });
});

describe('ValhallaWalkGeometry.route', () => {
  afterEach(() => {
    jest.restoreAllMocks();
    (global as { fetch: unknown }).fetch = undefined;
  });

  it('sin WALK_ROUTER_URL devuelve null sin tocar la red', async () => {
    const spy = jest.fn();
    settingUpFetch(spy);
    const geometry = await new ValhallaWalkGeometry(configWithoutRouter).route(
      { lat: -17.78, lon: -63.18 },
      { lat: -17.79, lon: -63.17 }
    );
    expect(geometry).toBeNull();
    expect(spy).not.toHaveBeenCalled();
  });

  it('rutea a pie por POST y parsea la geometría de la respuesta', async () => {
    const fetchMock = jest.fn().mockResolvedValue(
      okResponse({
        trip: {
          legs: [
            {
              shape: {
                type: 'LineString',
                coordinates: [
                  [-63.1826, -17.7833],
                  [-63.1783, -17.7836],
                ],
              },
            },
          ],
        },
      })
    );
    settingUpFetch(fetchMock);

    const geometry = await new ValhallaWalkGeometry(configWithRouter).route(
      { lat: -17.7833, lon: -63.1826 },
      { lat: -17.7836, lon: -63.1783 }
    );

    expect(geometry).toEqual({
      type: 'LineString',
      coordinates: [
        [-63.1826, -17.7833],
        [-63.1783, -17.7836],
      ],
    });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://valhalla.test/route');
    expect(init.method).toBe('POST');
    const body = JSON.parse(init.body as string);
    expect(body.costing).toBe('pedestrian');
    expect(body.locations).toEqual([
      { lat: -17.7833, lon: -63.1826 },
      { lat: -17.7836, lon: -63.1783 },
    ]);
  });

  it('degrada a null si Valhalla responde un error HTTP', async () => {
    settingUpFetch(
      jest.fn().mockResolvedValue(new Response('no', { status: 503 }))
    );
    const geometry = await new ValhallaWalkGeometry(configWithRouter).route(
      { lat: 0, lon: 0 },
      { lat: 1, lon: 1 }
    );
    expect(geometry).toBeNull();
  });

  it('degrada a null si la llamada lanza (timeout / red)', async () => {
    settingUpFetch(
      jest.fn().mockRejectedValue(new Error('The operation was aborted'))
    );
    const geometry = await new ValhallaWalkGeometry(configWithRouter).route(
      { lat: 0, lon: 0 },
      { lat: 1, lon: 1 }
    );
    expect(geometry).toBeNull();
  });

  it('degrada a null si la respuesta no trae trip.legs', async () => {
    settingUpFetch(
      jest.fn().mockResolvedValue(okResponse({ error: 'sin red peatonal' }))
    );
    const geometry = await new ValhallaWalkGeometry(configWithRouter).route(
      { lat: 0, lon: 0 },
      { lat: 1, lon: 1 }
    );
    expect(geometry).toBeNull();
  });
});
