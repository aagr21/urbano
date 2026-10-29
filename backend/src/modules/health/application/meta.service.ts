import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { FeedInfo } from '../../gtfs-import/entities/feed-info.entity';
import { JOURNEY_LIMITS } from '../../journey/domain/journey-limits';

/** Contrato de `GET /meta` (documentado en docs/api-contract.md). */
export interface MetaResponse {
  feed: {
    version: string | null;
    publisher: string | null;
    lang: string | null;
    startDate: string | null;
    endDate: string | null;
  };
  /** Invariantes de la API y del planner que el cliente debe respetar. */
  limits: typeof JOURNEY_LIMITS;
}

/**
 * Estado "meta" del dataset: identidad del feed importado (feed_info.txt)
 * + los invariantes del contrato [JOURNEY_LIMITS].
 */
@Injectable()
export class MetaService {
  constructor(private readonly dataSource: DataSource) {}

  async get(): Promise<MetaResponse> {
    const feed =
      (await this.dataSource.getRepository(FeedInfo).findOne({
        where: {},
        // feed_info es una sola fila; el orderBy es cosmético.
        order: { id: 1 },
      })) ?? undefined;

    return {
      feed: {
        version: feed?.version ?? null,
        publisher: feed?.publisherName ?? null,
        lang: feed?.lang ?? null,
        startDate: feed?.startDate ?? null,
        endDate: feed?.endDate ?? null,
      },
      limits: JOURNEY_LIMITS,
    };
  }
}
