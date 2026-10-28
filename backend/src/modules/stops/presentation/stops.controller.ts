import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import {
  Controller,
  Get,
  Param,
  Query,
  UseInterceptors,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CACHE_TTL_MS } from '../../../core/common/tokens';
import { StopsService } from '../application/stops.service';
import { NearbyStopsQueryDto, SearchStopsQueryDto } from '../application/stop.dto';

@ApiTags('stops')
@Controller('stops')
@UseInterceptors(CacheInterceptor)
export class StopsController {
  constructor(private readonly stopsService: StopsService) {}

  @Get('nearby')
  @CacheTTL(CACHE_TTL_MS)
  @ApiOperation({ summary: 'Paradas cercanas con rutas que las sirven' })
  nearby(@Query() query: NearbyStopsQueryDto) {
    return this.stopsService.nearby(query);
  }

  @Get('search')
  @CacheTTL(CACHE_TTL_MS)
  @ApiOperation({ summary: 'Busqueda de paradas por nombre' })
  search(@Query() query: SearchStopsQueryDto) {
    return this.stopsService.search(query);
  }

  @Get(':id')
  @CacheTTL(CACHE_TTL_MS)
  @ApiOperation({ summary: 'Detalle de parada con rutas y localizacion' })
  detail(@Param('id') id: string) {
    return this.stopsService.detail(id);
  }
}
