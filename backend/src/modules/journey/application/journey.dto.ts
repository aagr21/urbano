import { Type } from 'class-transformer';
import {
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  Matches,
  Max,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

const TIME_REGEX = /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/;

/** GET /journey?originLat=&originLon=&destLat=&destLon=&time=&maxResults= */
export class JourneyQueryDto {
  @ApiProperty({ example: -17.78 })
  @IsNumber()
  @IsLatitude()
  @Type(() => Number)
  originLat: number;

  @ApiProperty({ example: -63.15 })
  @IsNumber()
  @IsLongitude()
  @Type(() => Number)
  originLon: number;

  @ApiProperty({ example: -17.79 })
  @IsNumber()
  @IsLatitude()
  @Type(() => Number)
  destLat: number;

  @ApiProperty({ example: -63.16 })
  @IsNumber()
  @IsLongitude()
  @Type(() => Number)
  destLon: number;

  @ApiPropertyOptional({ description: 'Hora de referencia HH:mm o HH:mm:ss (default: ahora America/La_Paz)' })
  @IsOptional()
  @Matches(TIME_REGEX, { message: 'time debe tener formato HH:mm o HH:mm:ss' })
  time?: string;

  @ApiPropertyOptional({ default: 3, maximum: 10 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(10)
  maxResults = 3;
}
