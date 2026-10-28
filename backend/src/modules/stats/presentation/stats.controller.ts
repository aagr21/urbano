import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import {
  Controller,
  Get,
  UseInterceptors,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CACHE_TTL_MS } from '../../../core/common/tokens';
import { StatsService } from '../application/stats.service';

@ApiTags('stats')
@Controller('stats')
@UseInterceptors(CacheInterceptor)
export class StatsController {
  constructor(private readonly statsService: StatsService) {}

  @Get()
  @CacheTTL(CACHE_TTL_MS)
  @ApiOperation({ summary: 'Estadísticas del feed (home/dashboard)' })
  stats() {
    return this.statsService.getStats();
  }
}
