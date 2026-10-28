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
import { fullList } from '../../../core/common/models/paginated';
import { RoutesService } from '../application/routes.service';
import {
  ListRoutesQueryDto,
  RouteDeparturesQueryDto,
  RouteDetailQueryDto,
  RouteStopsQueryDto,
} from '../application/route.dto';

@ApiTags('routes')
@Controller('routes')
@UseInterceptors(CacheInterceptor)
export class RoutesController {
  constructor(private readonly routesService: RoutesService) {}

  @Get()
  @CacheTTL(CACHE_TTL_MS)
  @ApiOperation({ summary: 'Listado/busqueda de rutas' })
  list(@Query() query: ListRoutesQueryDto) {
    return this.routesService.list(query);
  }

  @Get(':id')
  @CacheTTL(CACHE_TTL_MS)
  @ApiOperation({ summary: 'Detalle de ruta con shape GeoJSON y direcciones' })
  detail(@Param('id') id: string, @Query() query: RouteDetailQueryDto) {
    return this.routesService.detail(id, query.directionId);
  }

  @Get(':id/stops')
  @CacheTTL(CACHE_TTL_MS)
  @ApiOperation({ summary: 'Paradas ordenadas de una dirección de la ruta' })
  async stops(@Param('id') id: string, @Query() query: RouteStopsQueryDto) {
    const stops = await this.routesService.stops(id, query.directionId ?? 0);
    return fullList(stops);
  }

  @Get(':id/departures')
  @CacheTTL(CACHE_TTL_MS)
  @ApiOperation({ summary: 'Próximas salidas en una parada de la ruta' })
  async departures(
    @Param('id') id: string,
    @Query() query: RouteDeparturesQueryDto,
  ) {
    const departures = await this.routesService.departures(
      id,
      query.stopId,
      query,
    );
    return fullList(departures);
  }
}
