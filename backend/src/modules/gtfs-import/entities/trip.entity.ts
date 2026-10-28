import { Column, Entity, PrimaryColumn } from 'typeorm';

/** trips.txt */
@Entity('trip')
export class Trip {
  @PrimaryColumn({ name: 'trip_id', type: 'varchar', length: 64 })
  id: string;

  @Column({ name: 'route_id', type: 'varchar', length: 128 })
  routeId: string;

  @Column({ name: 'service_id', type: 'varchar', length: 64 })
  serviceId: string;

  @Column({ name: 'trip_headsign', type: 'varchar', length: 255, nullable: true })
  headsign: string | null;

  @Column({ name: 'direction_id', type: 'int', default: 0 })
  directionId: number;

  @Column({ name: 'shape_id', type: 'varchar', length: 64, nullable: true })
  shapeId: string | null;

  @Column({ name: 'wheelchair_boarding', type: 'int', default: 0 })
  wheelchairBoarding: number;
}
