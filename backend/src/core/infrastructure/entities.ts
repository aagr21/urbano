import { Agency } from '../../modules/gtfs-import/entities/agency.entity';
import { FeedInfo } from '../../modules/gtfs-import/entities/feed-info.entity';
import { Frequency } from '../../modules/gtfs-import/entities/frequency.entity';
import { Route } from '../../modules/gtfs-import/entities/route.entity';
import { Service } from '../../modules/gtfs-import/entities/service.entity';
import { Shape } from '../../modules/gtfs-import/entities/shape.entity';
import { StopTime } from '../../modules/gtfs-import/entities/stop-time.entity';
import { Stop } from '../../modules/gtfs-import/entities/stop.entity';
import { Trip } from '../../modules/gtfs-import/entities/trip.entity';

/** Registro central de entidades TypeORM (fuente única de verdad). */
export const ALL_ENTITIES = [
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
