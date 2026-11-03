import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity('complaint')
export class Complaint {
  @PrimaryGeneratedColumn('uuid')
  declare id: string;

  @Column({ name: 'route_id', type: 'varchar', length: 128 })
  declare routeId: string;

  @Column({ name: 'category', type: 'varchar', length: 32 })
  declare category: string;

  @Column({ type: 'text' })
  declare description: string;

  @Column({ name: 'photo_urls', type: 'jsonb', default: () => "'[]'::jsonb" })
  declare photoUrls: string[];

  @Column({ type: 'varchar', length: 16, default: 'pending' })
  declare status: 'pending' | 'approved' | 'rejected';

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  declare createdAt: Date;
}
