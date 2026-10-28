import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity('agency')
export class Agency {
  @PrimaryColumn({ name: 'agency_id', type: 'varchar', length: 64 })
  id: string;

  @Column({ name: 'agency_name', type: 'varchar', length: 255 })
  name: string;

  @Column({ name: 'agency_url', type: 'varchar', length: 255, nullable: true })
  url: string | null;

  @Column({ name: 'agency_timezone', type: 'varchar', length: 64, nullable: true })
  timezone: string | null;

  @Column({ name: 'agency_lang', type: 'varchar', length: 16, nullable: true })
  lang: string | null;
}
