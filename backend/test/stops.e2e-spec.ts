import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';
import { AppConfigService } from '../src/core/config/app-config.service';

jest.setTimeout(30000);

describe('Stops (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    configureApp(app, app.get(AppConfigService));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /api/v1/stops/nearby returns stops sorted by distance with routes', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/stops/nearby?lat=-17.78&lon=-63.15&radius=500')
      .expect(200);

    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThan(0);

    const distances = res.body.data.map((s: { distanceMeters: number }) => s.distanceMeters);
    expect([...distances].sort((a, b) => a - b)).toEqual(distances);
    expect(distances[distances.length - 1]).toBeLessThanOrEqual(500);

    const stop = res.body.data[0];
    expect(stop).toMatchObject({
      id: expect.any(String),
      name: expect.any(String),
      lat: expect.any(Number),
      lon: expect.any(Number),
      distanceMeters: expect.any(Number),
      routes: expect.any(Array),
    });
    // cerca del punto consultado (Santa Cruz, lon < lat en valor absoluto)
    expect(stop.lon).toBeCloseTo(-63.15, 1);
    expect(stop.lat).toBeCloseTo(-17.78, 1);
  });

  it('GET /api/v1/stops/nearby rejects invalid coordinates', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/stops/nearby?lat=abc&lon=-63.15')
      .expect(400);
  });

  it('GET /api/v1/stops/search finds stops by name without distanceMeters', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/stops/search?q=avenida')
      .expect(200);

    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThan(0);

    const stop = res.body.data[0];
    expect(stop).toMatchObject({
      id: expect.any(String),
      name: expect.any(String),
      routes: expect.any(Array),
    });
    expect(stop.name.toLowerCase()).toContain('avenida');
    expect(stop).not.toHaveProperty('distanceMeters');
  });

  it('GET /api/v1/stops/:id returns detail with GeoJSON location', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/stops/S19386').expect(200);

    expect(res.body.data).toMatchObject({
      id: 'S19386',
      location: { type: 'Point' },
      routes: expect.any(Array),
    });
    const [lon, lat] = res.body.data.location.coordinates;
    expect(lon).toBeCloseTo(res.body.data.lon, 6);
    expect(lat).toBeCloseTo(res.body.data.lat, 6);
  });

  it('GET /api/v1/stops/:id returns 404 for unknown stop', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/stops/NOPE').expect(404);

    expect(res.body).toMatchObject({
      error: { statusCode: 404, message: expect.any(String) },
    });
  });
});
