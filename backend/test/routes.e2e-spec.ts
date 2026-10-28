import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';
import { AppConfigService } from '../src/core/config/app-config.service';

jest.setTimeout(30000);

describe('Routes (e2e)', () => {
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

  it('GET /api/v1/routes returns wrapped route list', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/routes?q=101').expect(200);

    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('meta');
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThan(0);

    const route = res.body.data[0];
    expect(route).toMatchObject({
      id: expect.any(String),
      shortName: expect.any(String),
      longName: expect.any(String),
      color: expect.stringMatching(/^[0-9A-F]{6}$/),
      textColor: expect.stringMatching(/^[0-9A-F]{6}$/),
    });
    expect(route.color).not.toContain('#');
    expect(route.type).toBe(3);
  });

  it('GET /api/v1/routes returns paginated meta', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/routes').expect(200);

    expect(res.body.meta).toMatchObject({
      page: 1,
      limit: expect.any(Number),
      total: expect.any(Number),
    });
    expect(res.body.meta.total).toBeGreaterThanOrEqual(154);
  });

  it('GET /api/v1/routes/:id returns detail with shape GeoJSON', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/routes/101%20ANGOSTURA?directionId=0')
      .expect(200);

    const route = res.body.data;
    expect(route.id).toBe('101 ANGOSTURA');
    expect(route.directions.length).toBeGreaterThan(0);
    expect(route.shape.type).toBe('Feature');
    expect(route.shape.geometry.type).toBe('LineString');
    const coords = route.shape.geometry.coordinates as [number, number][];
    expect(coords[0]).toHaveLength(2);
    const [lon, lat] = coords[0];
    expect(lon).toBeGreaterThanOrEqual(-64);
    expect(lon).toBeLessThanOrEqual(-62);
    expect(lat).toBeGreaterThanOrEqual(-18);
    expect(lat).toBeLessThanOrEqual(-17);
  });

  it('GET /api/v1/routes/:id/stops returns ordered stops for a direction', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/routes/101%20ANGOSTURA/stops?directionId=0')
      .expect(200);

    expect(res.body.data.length).toBeGreaterThan(0);
    expect(res.body.data[0]).toMatchObject({
      id: expect.any(String),
      name: expect.any(String),
      sequence: expect.any(Number),
      lat: expect.any(Number),
      lon: expect.any(Number),
      departureTime: expect.stringMatching(/^\d{2}:\d{2}:\d{2}$/),
    });
    // sequences strictly increasing
    const seqs = res.body.data.map((s: { sequence: number }) => s.sequence);
    expect([...seqs].sort((a, b) => a - b)).toEqual(seqs);
  });

  it('GET /api/v1/routes/:id/departures returns upcoming departures in HH:mm:ss', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/routes/101%20ANGOSTURA/departures?stopId=S16309&time=06:05')
      .expect(200);

    expect(res.body.data.length).toBeGreaterThan(0);
    for (const dep of res.body.data.slice(0, 5)) {
      expect(dep.time).toMatch(/^\d{2}:\d{2}:\d{2}$/);
      expect(dep.tripId).toBeTruthy();
    }
    // times ascending
    const times = res.body.data.map((d: { time: string }) => d.time);
    expect([...times].sort()).toEqual(times);
  });

  it('GET /api/v1/routes/:id returns 404 for unknown route', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/routes/NO-EXISTE')
      .expect(404);

    expect(res.body).toMatchObject({
      error: { statusCode: 404, message: expect.any(String) },
    });
  });
});
