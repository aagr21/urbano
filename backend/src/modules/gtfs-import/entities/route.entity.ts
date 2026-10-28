import { Column, Entity, PrimaryColumn } from 'typeorm';

/** routes.txt + campos derivados (stopCount/directions/tripCount). */
@Entity('route')
export class Route {
  @PrimaryColumn({ name: 'route_id', type: 'varchar', length: 128 })
  id: string;

  @Column({ name: 'agency_id', type: 'varchar', length: 64, nullable: true })
  agencyId: string | null;

  @Column({ name: 'route_short_name', type: 'varchar', length: 128 })
  shortName: string;

  @Column({ name: 'route_long_name', type: 'varchar', length: 255, nullable: true })
  longName: string | null;

  @Column({ name: 'route_desc', type: 'text', nullable: true })
  description: string | null;

  @Column({ name: 'route_type', type: 'int' })
  type: number;

  /** Hex GTFS sin '#'. */
  @Column({ name: 'route_color', type: 'varchar', length: 8, nullable: true })
  color: string | null;

  /** Hex GTFS sin '#'. */
  @Column({ name: 'route_text_color', type: 'varchar', length: 8, nullable: true })
  textColor: string | null;

  /** Imagen del itinerario (de micros.csv; URL externa tipo Google). */
  @Column({ name: 'image_url', type: 'text', nullable: true })
  imageUrl: string | null;

  // ---- Derivados en la importación ----

  /** Paradas distintas servidas por la ruta (todas las direcciones). */
  @Column({ name: 'stop_count', type: 'int', default: 0 })
  stopCount: number;

  /** Cantidad de direction_id distintos (0/1). */
  @Column({ name: 'directions', type: 'int', default: 0 })
  directions: number;

  @Column({ name: 'trip_count', type: 'int', default: 0 })
  tripCount: number;
}
