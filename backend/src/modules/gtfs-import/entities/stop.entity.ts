import { Column, Entity, PrimaryColumn } from 'typeorm';

/** stops.txt + columna geoespacial para nearby con PostGIS. */
@Entity('stop')
export class Stop {
  @PrimaryColumn({ name: 'stop_id', type: 'varchar', length: 64 })
  id: string;

  @Column({ name: 'stop_code', type: 'varchar', length: 64, nullable: true })
  code: string | null;

  @Column({ name: 'stop_name', type: 'varchar', length: 255 })
  name: string;

  @Column({ name: 'stop_desc', type: 'text', nullable: true })
  description: string | null;

  @Column({ name: 'stop_lat', type: 'double precision' })
  lat: number;

  @Column({ name: 'stop_lon', type: 'double precision' })
  lon: number;

  /** Punto PostGIS (lon, lat) usado por ST_DWithin/ST_Distance en metros. */
  @Column({
    name: 'geom',
    type: 'geography',
    spatialFeatureType: 'Point',
    srid: 4326,
    nullable: true,
  })
  geom: string | null;
}
