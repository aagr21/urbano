import { Type } from 'class-transformer';
import { IsIn, IsOptional } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

/** ?directionId=0|1 (Ida / Vuelta) */
export class DirectionQueryDto {
  @ApiPropertyOptional({ description: '0 = Ida, 1 = Vuelta', enum: [0, 1] })
  @IsOptional()
  @Type(() => Number)
  @IsIn([0, 1])
  directionId?: 0 | 1;
}
