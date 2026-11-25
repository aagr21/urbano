import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import { Controller, Get, Query, UseInterceptors } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { JOURNEY_CACHE_TTL_MS } from '../../../core/common/tokens';
import { JourneyService } from '../application/journey.service';
import { JourneyQueryDto } from '../application/journey.dto';

@ApiTags('journey')
@Controller('journey')
@UseInterceptors(CacheInterceptor)
export class JourneyController {
  constructor(private readonly journeyService: JourneyService) {}

  @Get()
  @CacheTTL(JOURNEY_CACHE_TTL_MS)
  @ApiOperation({ summary: 'Planeador de viaje (directo + 1 transbordo)' })
  plan(@Query() query: JourneyQueryDto) {
    return this.journeyService.plan(query);
  }
}
