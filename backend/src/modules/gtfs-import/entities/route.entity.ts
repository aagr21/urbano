import { Column, Entity, PrimaryColumn } from 'typeorm';

/** routes.txt + campos derivados (stopCount/directions/tripCount). */
@Entity('route')
export class Route {
  @PrimaryColumn({ name: 'route_id', type: 'varchar', length: 128 })
  declare id: string;

  @Column({ name: 'agency_id', type: 'varchar', length: 64, nullable: true })
  declare agencyId: string | null;

  @Column({ name: 'route_short_name', type: 'varchar', length: 128 })
  declare shortName: string;

  @Column({ name: 'route_long_name', type: 'varchar', length: 255, nullable: true })
  declare longName: string | null;

  @Column({ name: 'route_desc', type: 'text', nullable: true })
  declare description: string | null;

  @Column({ name: 'route_type', type: 'int' })
  declare type: number;

  /** Hex GTFS sin '#'. */
  @Column({ name: 'route_color', type: 'varchar', length: 8, nullable: true })
  declare color: string | null;

  /** Hex GTFS sin '#'. */
  @Column({ name: 'route_text_color', type: 'varchar', length: 8, nullable: true })
  declare textColor: string | null;

  /** Imagen del itinerario (de micros.csv; URL externa tipo Google). */
  @Column({ name: 'image_url', type: 'text', nullable: true })
  declare imageUrl: string | null;

  // ---- Derivados en la importación ----

  /** Paradas distintas servidas por la ruta (todas las direcciones). */
  @Column({ name: 'stop_count', type: 'int', default: 0 })
  declare stopCount: number;

  /** Cantidad de direction_id distintos (0/1). */
  @Column({ name: 'directions', type: 'int', default: 0 })
  declare directions: number;

  @Column({ name: 'trip_count', type: 'int', default: 0 })
  declare tripCount: number;
}
