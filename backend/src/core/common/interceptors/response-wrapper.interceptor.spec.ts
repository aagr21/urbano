import { CallHandler, ExecutionContext } from '@nestjs/common';
import { of } from 'rxjs';
import type { Observable } from 'rxjs';
import { ResponseWrapperInterceptor } from './response-wrapper.interceptor';
import { SKIP_WRAPPER_KEY } from '../decorators/skip-wrapper.decorator';
import { paginated, fullList } from '../models/paginated';

/** El wrapper solo envuelve respuestas EXITOSAS del contrato. */
describe('ResponseWrapperInterceptor (contrato { data, meta })', () => {
  const interceptor = new ResponseWrapperInterceptor();

  /** Contexto mínimo: el handler como función con/ sin los metadatos SkipWrapper. */
  const ctxOf = (withSkip: boolean): ExecutionContext =>
    ({
      getHandler: () => {
        const handler = (): void => {};
        if (withSkip) {
          Reflect.defineMetadata(SKIP_WRAPPER_KEY, true, handler);
        }
        return handler;
      },
    }) as unknown as ExecutionContext;

  const run = (payload: unknown, withSkip = false): Promise<unknown> =>
    new Promise((resolve) => {
      const next: CallHandler = { handle: () => of(payload) as Observable<unknown> };
      interceptor.intercept(ctxOf(withSkip), next).subscribe(resolve);
    });

  it('envuelve un payload simple en { data, meta: null }', async () => {
    const body = (await run({ hello: 'mundo' })) as Record<string, unknown>;
    expect(body).toEqual({ data: { hello: 'mundo' }, meta: null });
  });

  it('un PaginatedResult sale como { data: items, meta: { page, limit, total } }', async () => {
    const body = (await run(paginated([{ id: '41' }], { page: 2, limit: 20, total: 41 }))) as {
      data: unknown[];
      meta: { page: number; limit: number; total: number };
    };
    expect(body.data).toEqual([{ id: '41' }]);
    expect(body.meta).toEqual({ page: 2, limit: 20, total: 41 });
  });

  it('fullList sale paginado con total = items.length (rutas sin paginación real)', async () => {
    const body = (await run(fullList(['a', 'b', 'c']))) as {
      data: string[];
      meta: { total: number; limit: number; page: number };
    };
    expect(body.data).toEqual(['a', 'b', 'c']);
    expect(body.meta).toEqual({ page: 1, limit: 3, total: 3 });
  });

  it('un handler sin respuesta (void) sale como { data: null, meta: null }', async () => {
    const body = (await run(undefined)) as Record<string, unknown>;
    expect(body).toEqual({ data: null, meta: null });
  });

  it('un handler marcado con @SkipWrapper sale SIN envolver (contrato: /health)', async () => {
    const payload = { status: 'ok' };
    const body = await run(payload, true);
    expect(body).toEqual(payload);
  });
});
