import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { JourneyService } from '../application/journey.service';
import { JourneyQueryDto } from '../application/journey.dto';

@ApiTags('journey')
@Controller('journey')
export class JourneyController {
  constructor(private readonly journeyService: JourneyService) {}

  @Get()
  @ApiOperation({ summary: 'Planeador de viaje (directo + 1 transbordo)' })
  plan(@Query() query: JourneyQueryDto) {
    return this.journeyService.plan(query);
  }
}
