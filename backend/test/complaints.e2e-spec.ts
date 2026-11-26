import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { DataSource } from 'typeorm';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';
import { AppConfigService } from '../src/core/config/app-config.service';

jest.setTimeout(30000);

/**
 * Denuncias contra Postgres real: lo que los unitarios no pueden probar son
 * las consultas SQL de los contadores (apoyos/comentarios por queja y «lo
 * apoyé yo»). Todo lo creado aquí se borra en `afterAll`.
 */
describe('Complaints (e2e)', () => {
  let app: INestApplication;
  let db: DataSource;
  let routeId: string;
  const created: string[] = [];
  // Únicos por corrida: no chocan con datos de desarrollo ni entre corridas.
  const me = `e2e-${Date.now()}`;
  const other = `${me}-otro`;

  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    configureApp(app, app.get(AppConfigService));
    await app.init();
    db = app.get(DataSource);
    const [route] = await db.query('SELECT route_id FROM route LIMIT 1');
    routeId = route.route_id;
  });

  afterAll(async () => {
    if (created.length > 0) {
      await db.query(
        'DELETE FROM complaint_comment WHERE complaint_id = ANY($1)',
        [created]
      );
      await db.query(
        'DELETE FROM complaint_like WHERE complaint_id = ANY($1)',
        [created]
      );
      await db.query('DELETE FROM complaint WHERE id = ANY($1)', [created]);
    }
    await app.close();
  });

  const create = async (description: string) => {
    const res = await http()
      .post('/api/v1/complaints')
      .field('routeId', routeId)
      .field('category', 'vehicle')
      .field('description', description)
      .expect(201);
    created.push(res.body.data.id);
    return res.body.data as { id: string; status: string };
  };

  const listAs = async (deviceKey: string) => {
    const res = await http()
      .get(`/api/v1/complaints?deviceKey=${deviceKey}`)
      .expect(200);
    return res.body.data as Array<{
      id: string;
      description: string;
      likeCount: number;
      commentCount: number;
      likedByMe: boolean;
    }>;
  };

  it('crea una queja pendiente con la descripción recortada', async () => {
    const complaint = await create('  frenó de golpe  ');
    expect(complaint.status).toBe('pending');

    const mine = (await listAs(me)).find((c) => c.id === complaint.id);
    expect(mine).toMatchObject({
      description: 'frenó de golpe',
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
    });
  });

  it('rechaza una categoría inválida con 400 y el formato de error', async () => {
    const res = await http()
      .post('/api/v1/complaints')
      .field('routeId', routeId)
      .field('category', 'ruido')
      .expect(400);
    expect(res.body.error).toMatchObject({
      statusCode: 400,
      message: 'Ruta o categoría inválida',
    });
  });

  it('los contadores por SQL: apoyos sin duplicar, comentarios y «lo apoyé yo»', async () => {
    const { id } = await create('contadores');

    // Dos apoyos del mismo dispositivo cuentan uno; otro dispositivo suma.
    await http().post(`/api/v1/complaints/${id}/like`).send({ deviceKey: me });
    await http().post(`/api/v1/complaints/${id}/like`).send({ deviceKey: me });
    const like = await http()
      .post(`/api/v1/complaints/${id}/like`)
      .send({ deviceKey: other })
      .expect(201);
    expect(like.body.data).toEqual({ likeCount: 2, likedByMe: true });

    await http()
      .post(`/api/v1/complaints/${id}/comments`)
      .send({ deviceKey: me, body: '  yo también lo vi ', authorName: ' Ana ' })
      .expect(201);

    const forMe = (await listAs(me)).find((c) => c.id === id);
    expect(forMe).toMatchObject({
      likeCount: 2,
      commentCount: 1,
      likedByMe: true,
    });

    // Para un tercero cuenta igual, pero no figura como apoyado por él.
    const forStranger = (await listAs(`${me}-nadie`)).find((c) => c.id === id);
    expect(forStranger).toMatchObject({ likeCount: 2, likedByMe: false });

    const comments = await http()
      .get(`/api/v1/complaints/${id}/comments`)
      .expect(200);
    expect(comments.body.data).toEqual([
      expect.objectContaining({ body: 'yo también lo vi', authorName: 'Ana' }),
    ]);

    // Quitar el apoyo baja el conteo.
    const unlike = await http()
      .delete(`/api/v1/complaints/${id}/like?deviceKey=${me}`)
      .expect(200);
    expect(unlike.body.data).toEqual({ likeCount: 1, likedByMe: false });
  });

  it('una queja inexistente responde 404', async () => {
    await http()
      .get('/api/v1/complaints/00000000-0000-0000-0000-000000000000/comments')
      .expect(404);
  });
});
