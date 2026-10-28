import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { PaginatedResult } from '../../../core/common/models/paginated';
import { STOP_REPOSITORY } from '../../../core/common/tokens';
import {
  StopDetail,
  StopNearby,
  StopRepositoryPort,
  StopWithRoutes,
} from '../domain/stop.model';
import { NearbyStopsQueryDto, SearchStopsQueryDto } from './stop.dto';

@Injectable()
export class StopsService {
  constructor(
    @Inject(STOP_REPOSITORY) private readonly stopRepository: StopRepositoryPort,
  ) {}

  async nearby(query: NearbyStopsQueryDto): Promise<PaginatedResult<StopNearby>> {
    const { items, total } = await this.stopRepository.findNearby({
      lat: query.lat,
      lon: query.lon,
      radiusMeters: query.radius,
      limit: query.limit,
    });
    return new PaginatedResult(items, {
      page: 1,
      limit: query.limit,
      total,
    });
  }

  async search(query: SearchStopsQueryDto): Promise<PaginatedResult<StopWithRoutes>> {
    const { items, total } = await this.stopRepository.search(
      query.q.trim(),
      query.limit,
    );
    return new PaginatedResult(items, {
      page: 1,
      limit: query.limit,
      total,
    });
  }

  async detail(id: string): Promise<StopDetail> {
    const stop = await this.stopRepository.findById(id);
    if (!stop) {
      throw new NotFoundException(`Stop ${id} not found`);
    }
    return stop;
  }
}
