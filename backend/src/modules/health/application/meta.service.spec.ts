import { MetaService } from './meta.service';
import { JOURNEY_LIMITS } from '../../journey/domain/journey-limits';
import { FeedInfo } from '../../gtfs-import/entities/feed-info.entity';

/**
 * Contrato de `GET /meta`: identidad del dataset + invariantes del planner.
 * El repo se mockea; lo que se LOCKEA es la forma y el snapshot de límites.
 */
describe('MetaService (contrato de la API meta)', () => {
  const feed = Object.assign(new FeedInfo(), {
    id: 1,
    publisherName: 'Municipalidad de Santa Cruz',
    publisherUrl: 'https://example.com',
    lang: 'es',
    startDate: '20251001',
    endDate: '20261001',
    version: 'v-2026-10',
  });

  const makeService = (row: FeedInfo | undefined) => {
    const repo = { findOne: jest.fn().mockResolvedValue(row) };
    return {
      service: new MetaService({
        getRepository: () => repo,
      } as never),
      repo: repo.findOne as jest.Mock,
    };
  };

  it('devuelve la identidad del feed + los límites congelados', async () => {
    const { service } = makeService(feed);
    const meta = await service.get();

    expect(meta.feed).toEqual({
      version: 'v-2026-10',
      publisher: 'Municipalidad de Santa Cruz',
      lang: 'es',
      startDate: '20251001',
      endDate: '20261001',
    });
    expect(meta.limits).toEqual(JOURNEY_LIMITS);
    // INMUTABLE: el contrato no se puede alterar por accidente.
    expect(Object.isFrozen(meta.limits)).toBe(true);
  });

  it('feed vacío (sin importar) → feed nulo, límites IGUALES (el contrato no depende del dataset)', async () => {
    const { service } = makeService(undefined);
    const meta = await service.get();

    expect(meta.feed).toEqual({
      version: null,
      publisher: null,
      lang: null,
      startDate: null,
      endDate: null,
    });
    expect(meta.limits).toEqual(JOURNEY_LIMITS);
  });

  it('consulta el repositorio de feed_info (una fila)', async () => {
    const { repo } = makeService(feed);
    await new MetaService({ getRepository: () => ({ findOne: repo }) } as never).get();
    expect(repo).toHaveBeenCalledTimes(1);
  });
});
