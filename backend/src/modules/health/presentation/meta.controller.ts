import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { MetaService } from '../application/meta.service';

/** Contrato de dataset + límites (`GET /api/v1/meta`, envuelto en data). */
@ApiTags('health')
@Controller('meta')
export class MetaController {
  constructor(private readonly metaService: MetaService) {}

  @Get()
  @ApiOperation({
    summary:
      'Identidad del feed importado (feed_info) + invariantes del contrato',
  })
  get() {
    return this.metaService.get();
  }
}
