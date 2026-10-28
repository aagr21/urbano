import { Type } from 'class-transformer';
import {
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/** GET /stops/nearby?lat=&lon=&radius=400&limit=10 */
export class NearbyStopsQueryDto {
  @ApiProperty({ description: 'Latitud', example: -17.78 })
  @IsNumber()
  @IsLatitude()
  @Type(() => Number)
  lat: number;

  @ApiProperty({ description: 'Longitud', example: -63.15 })
  @IsNumber()
  @IsLongitude()
  @Type(() => Number)
  lon: number;

  @ApiPropertyOptional({ description: 'Radio en metros (máx 2000)', default: 400 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(2000)
  radius = 400;

  @ApiPropertyOptional({ default: 10, maximum: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(50)
  limit = 10;
}

/** GET /stops/search?q=&limit=10 */
export class SearchStopsQueryDto {
  @ApiProperty({ description: 'Texto de búsqueda' })
  @IsNotEmpty()
  q: string;

  @ApiPropertyOptional({ default: 10, maximum: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(50)
  limit = 10;
}
