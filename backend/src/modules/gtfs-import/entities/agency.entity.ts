import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity('agency')
export class Agency {
  @PrimaryColumn({ name: 'agency_id', type: 'varchar', length: 64 })
  declare id: string;

  @Column({ name: 'agency_name', type: 'varchar', length: 255 })
  declare name: string;

  @Column({ name: 'agency_url', type: 'varchar', length: 255, nullable: true })
  declare url: string | null;

  @Column({ name: 'agency_timezone', type: 'varchar', length: 64, nullable: true })
  declare timezone: string | null;

  @Column({ name: 'agency_lang', type: 'varchar', length: 16, nullable: true })
  declare lang: string | null;
}
