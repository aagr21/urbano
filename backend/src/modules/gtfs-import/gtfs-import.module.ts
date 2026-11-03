import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Agency } from './entities/agency.entity';
import { FeedInfo } from './entities/feed-info.entity';
import { Frequency } from './entities/frequency.entity';
import { Route } from './entities/route.entity';
import { Service } from './entities/service.entity';
import { Shape } from './entities/shape.entity';
import { StopTime } from './entities/stop-time.entity';
import { Stop } from './entities/stop.entity';
import { Trip } from './entities/trip.entity';
import { GtfsImportRepository } from './gtfs-import.repository';
import { GtfsImportService } from './gtfs-import.service';
import { MicrosImagesService } from './micros-images.service';

export const GTFS_ENTITIES = [
  Agency,
  Service,
  FeedInfo,
  Route,
  Stop,
  Trip,
  StopTime,
  Shape,
  Frequency,
];

@Module({
  imports: [TypeOrmModule.forFeature(GTFS_ENTITIES)],
  providers: [GtfsImportService, GtfsImportRepository, MicrosImagesService],
  exports: [GtfsImportService, MicrosImagesService, TypeOrmModule],
})
export class GtfsImportModule {}
