import { Column, Entity, PrimaryColumn } from 'typeorm';

/** stops.txt + columna geoespacial para nearby con PostGIS. */
@Entity('stop')
export class Stop {
  @PrimaryColumn({ name: 'stop_id', type: 'varchar', length: 64 })
  declare id: string;

  @Column({ name: 'stop_code', type: 'varchar', length: 64, nullable: true })
  declare code: string | null;

  @Column({ name: 'stop_name', type: 'varchar', length: 255 })
  declare name: string;

  @Column({ name: 'stop_desc', type: 'text', nullable: true })
  declare description: string | null;

  @Column({ name: 'stop_lat', type: 'double precision' })
  declare lat: number;

  @Column({ name: 'stop_lon', type: 'double precision' })
  declare lon: number;

  /** Punto PostGIS (lon, lat) usado por ST_DWithin/ST_Distance en metros. */
  @Column({
    name: 'geom',
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  declare geom: string | null;
}
