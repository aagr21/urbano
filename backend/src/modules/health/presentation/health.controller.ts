import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { SkipWrapper } from '../../../core/common/decorators/skip-wrapper.decorator';
import { HealthService } from '../application/health.service';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  @SkipWrapper()
  @ApiOperation({ summary: 'Health check (sin envoltorio data/meta)' })
  check() {
    return this.healthService.check();
  }
}
