import { Module } from '@nestjs/common';
import { ROUTE_REPOSITORY, SERVICE_REPOSITORY } from '../../core/common/tokens';
import { RoutesService } from './application/routes.service';
import { TypeOrmRouteRepository } from './infrastructure/typeorm-route.repository';
import { TypeOrmServiceRepository } from './infrastructure/typeorm-service.repository';
import { RoutesController } from './presentation/routes.controller';

@Module({
  controllers: [RoutesController],
  providers: [
    RoutesService,
    { provide: ROUTE_REPOSITORY, useClass: TypeOrmRouteRepository },
    { provide: SERVICE_REPOSITORY, useClass: TypeOrmServiceRepository },
  ],
  exports: [RoutesService],
})
export class RoutesModule {}
