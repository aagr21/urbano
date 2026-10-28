import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';
import { AppConfigService } from '../src/core/config/app-config.service';

jest.setTimeout(30000);

interface BusLegBody {
  kind: string;
  tripId?: string;
  fromStopId?: string;
  toStopId?: string;
  geometry?: { type: string; coordinates: number[][] } | null;
  fromStop?: { id: string; name: string; lat: number; lon: number };
  toStop?: { id: string; name: string; lat: number; lon: number };
}

interface OptionBody {
  type: string;
  walkToStop: { id: string; name: string; distanceMeters: number; lat?: number; lon?: number };
  walkFromStop: { id: string; name: string; distanceMeters: number; lat?: number; lon?: number };
  legs: BusLegBody[];
}

describe('Journey (e2e) — geometría de mapa', () => {
  let app: INestApplication;
  let options: OptionBody[];

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    configureApp(app, app.get(AppConfigService));
    await app.init();

    const res = await request(app.getHttpServer())
      .get(
        '/api/v1/journey?originLat=-17.78&originLon=-63.15&destLat=-17.80&destLon=-63.17&time=08:00',
      )
      .expect(200);
    options = res.body.data.options;
  });

  afterAll(async () => {
    await app.close();
  });

  it('devuelve opciones (directas o con transbordo)', () => {
    expect(Array.isArray(options)).toBe(true);
    expect(options.length).toBeGreaterThan(0);
    expect(options.map((o) => o.type)).toEqual(
      expect.arrayContaining([expect.stringMatching(/^(direct|transfer)$/)]),
    );
  });

  it('todo tramo de bus trae geometry LineString con ≥2 puntos dentro del bbox de Santa Cruz', () => {
    const busLegs = options.flatMap((o) => o.legs).filter((l) => l.kind === 'bus');
    expect(busLegs.length).toBeGreaterThan(0);

    for (const leg of busLegs) {
      expect(leg.geometry).toBeDefined();
      expect(leg.geometry!.type).toBe('LineString');

      const coordinates = leg.geometry!.coordinates;
      expect(Array.isArray(coordinates)).toBe(true);
      expect(coordinates.length).toBeGreaterThanOrEqual(2);

      for (const point of coordinates) {
        expect(point).toHaveLength(2);
        const [lon, lat] = point;
        expect(typeof lon).toBe('number');
        expect(typeof lat).toBe('number');
        // bbox Santa Cruz de la Sierra
        expect(lon).toBeGreaterThanOrEqual(-64);
        expect(lon).toBeLessThanOrEqual(-62);
        expect(lat).toBeGreaterThanOrEqual(-19);
        expect(lat).toBeLessThanOrEqual(-17);
      }
    }
  });

  it('todo tramo de bus trae fromStop/toStop con lat/lon', () => {
    const busLegs = options.flatMap((o) => o.legs).filter((l) => l.kind === 'bus');

    for (const leg of busLegs) {
      for (const stop of [leg.fromStop, leg.toStop]) {
        expect(stop).toBeDefined();
        expect(stop!.id).toEqual(expect.any(String));
        expect(stop!.name).toEqual(expect.any(String));
        expect(stop!.lat).toEqual(expect.any(Number));
        expect(stop!.lon).toEqual(expect.any(Number));
        expect(stop!.lat).toBeGreaterThanOrEqual(-19);
        expect(stop!.lat).toBeLessThanOrEqual(-17);
        expect(stop!.lon).toBeGreaterThanOrEqual(-64);
        expect(stop!.lon).toBeLessThanOrEqual(-62);
      }
      // coherencia entre las paradas del mapa y los ids del tramo
      expect(leg.fromStop!.id).toBe(leg.fromStopId);
      expect(leg.toStop!.id).toBe(leg.toStopId);
    }
  });

  it('walkToStop y walkFromStop traen lat/lon para dibujar las caminatas', () => {
    for (const option of options) {
      expect(option.walkToStop.lat).toEqual(expect.any(Number));
      expect(option.walkToStop.lon).toEqual(expect.any(Number));
      expect(option.walkFromStop.lat).toEqual(expect.any(Number));
      expect(option.walkFromStop.lon).toEqual(expect.any(Number));
      expect(option.walkToStop.lat).toBeGreaterThanOrEqual(-19);
      expect(option.walkToStop.lat).toBeLessThanOrEqual(-17);
      expect(option.walkToStop.lon).toBeGreaterThanOrEqual(-64);
      expect(option.walkToStop.lon).toBeLessThanOrEqual(-62);
    }
  });
});
