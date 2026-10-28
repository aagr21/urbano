import { Type } from 'class-transformer';
import { IsIn, IsOptional, Matches } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../../core/common/dto/pagination.dto';

const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/;
const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

/** GET /routes?q=&page=&limit=&sort= */
export class ListRoutesQueryDto extends PaginationDto {
  @ApiPropertyOptional({ description: 'Búsqueda insensible a mayúsculas sobre shortName/longName' })
  @IsOptional()
  q?: string;

  @ApiPropertyOptional({ enum: ['name', 'shortName', 'longName', 'stopCount'], default: 'name' })
  @IsOptional()
  @IsIn(['name', 'shortName', 'longName', 'stopCount'])
  sort?: 'name' | 'shortName' | 'longName' | 'stopCount' = 'name';
}

/** GET /routes/:id?directionId= */
export class RouteDetailQueryDto {
  @ApiPropertyOptional({ enum: [0, 1] })
  @IsOptional()
  @Type(() => Number)
  @IsIn([0, 1])
  directionId?: 0 | 1;
}

/** GET /routes/:id/stops?directionId= */
export class RouteStopsQueryDto extends RouteDetailQueryDto {}

/** GET /routes/:id/departures?stopId=&directionId=&time=&date= */
export class RouteDeparturesQueryDto {
  @ApiPropertyOptional({
    description:
      'ID de la parada (stop_id). Si se omite, devuelve las salidas desde ' +
      'el inicio del recorrido de cada viaje de la ruta.',
  })
  @IsOptional()
  stopId?: string;

  @ApiPropertyOptional({ enum: [0, 1] })
  @IsOptional()
  @Type(() => Number)
  @IsIn([0, 1])
  directionId?: 0 | 1;

  @ApiPropertyOptional({ description: 'Hora de referencia HH:mm o HH:mm:ss (default: ahora America/La_Paz)' })
  @IsOptional()
  @Matches(TIME_REGEX, { message: 'time debe tener formato HH:mm o HH:mm:ss' })
  time?: string;

  @ApiPropertyOptional({ description: 'Fecha YYYY-MM-DD (default: hoy)' })
  @IsOptional()
  @Matches(DATE_REGEX, { message: 'date debe tener formato YYYY-MM-DD' })
  date?: string;
}
