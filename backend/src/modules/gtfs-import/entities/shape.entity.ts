import { Column, Entity, PrimaryColumn } from 'typeorm';

/**
 * shapes.txt agrupado por shape_id: una fila por shape (línea).
 * - coordinates: jsonb [[lon, lat], ...] para las respuestas GeoJSON (lectura rápida).
 * - geom: LineString PostGIS con índice GIST.
 * - bbox_*: bounding box derivado.
 */
@Entity('shape')
export class Shape {
  @PrimaryColumn({ name: 'shape_id', type: 'varchar', length: 64 })
  id: string;

  @Column({ name: 'point_count', type: 'int', default: 0 })
  pointCount: number;

  @Column({ name: 'bbox_min_lon', type: 'double precision', default: 0 })
  bboxMinLon: number;

  @Column({ name: 'bbox_min_lat', type: 'double precision', default: 0 })
  bboxMinLat: number;

  @Column({ name: 'bbox_max_lon', type: 'double precision', default: 0 })
  bboxMaxLon: number;

  @Column({ name: 'bbox_max_lat', type: 'double precision', default: 0 })
  bboxMaxLat: number;

  @Column({ name: 'coordinates', type: 'jsonb', nullable: true })
  coordinates: Array<[number, number]>;

  @Column({
    name: 'geom',
    type: 'geometry',
    spatialFeatureType: 'LineString',
    srid: 4326,
    nullable: true,
  })
  geom: string | null;
}
