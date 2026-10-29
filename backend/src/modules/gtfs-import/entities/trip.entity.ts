import { Column, Entity, PrimaryColumn } from 'typeorm';

/** trips.txt */
@Entity('trip')
export class Trip {
  @PrimaryColumn({ name: 'trip_id', type: 'varchar', length: 64 })
  declare id: string;

  @Column({ name: 'route_id', type: 'varchar', length: 128 })
  declare routeId: string;

  @Column({ name: 'service_id', type: 'varchar', length: 64 })
  declare serviceId: string;

  @Column({ name: 'trip_headsign', type: 'varchar', length: 255, nullable: true })
  declare headsign: string | null;

  @Column({ name: 'direction_id', type: 'int', default: 0 })
  declare directionId: number;

  @Column({ name: 'shape_id', type: 'varchar', length: 64, nullable: true })
  declare shapeId: string | null;

  @Column({ name: 'wheelchair_boarding', type: 'int', default: 0 })
  declare wheelchairBoarding: number;
}
