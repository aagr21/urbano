import { Column, Entity, PrimaryColumn } from 'typeorm';

/** feed_info.txt (una sola fila). */
@Entity('feed_info')
export class FeedInfo {
  @PrimaryColumn({ name: 'id', type: 'int' })
  id: number;

  @Column({ name: 'feed_publisher_name', type: 'varchar', length: 255, nullable: true })
  publisherName: string | null;

  @Column({ name: 'feed_publisher_url', type: 'varchar', length: 255, nullable: true })
  publisherUrl: string | null;

  @Column({ name: 'feed_lang', type: 'varchar', length: 16, nullable: true })
  lang: string | null;

  @Column({ name: 'feed_start_date', type: 'varchar', length: 8, nullable: true })
  startDate: string | null;

  @Column({ name: 'feed_end_date', type: 'varchar', length: 8, nullable: true })
  endDate: string | null;

  @Column({ name: 'feed_version', type: 'varchar', length: 64, nullable: true })
  version: string | null;
}
