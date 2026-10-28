import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import {
  Controller,
  Get,
  Param,
  UseInterceptors,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CACHE_TTL_MS } from '../../../core/common/tokens';
import { TripsService } from '../application/trips.service';

@ApiTags('trips')
@Controller('trips')
@UseInterceptors(CacheInterceptor)
export class TripsController {
  constructor(private readonly tripsService: TripsService) {}

  @Get(':id')
  @CacheTTL(CACHE_TTL_MS)
  @ApiOperation({ summary: 'Detalle de viaje con stop_times' })
  detail(@Param('id') id: string) {
    return this.tripsService.detail(id);
  }
}
