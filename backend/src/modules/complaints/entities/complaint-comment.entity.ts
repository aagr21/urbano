import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

/**
 * Comentario de una queja, estilo red social. La autoría va denormalizada
 * (nombre + color) porque la app es dueña de su identidad por dispositivo:
 * así el feed no necesita una tabla de usuarios ni un lookup por comentario.
 */
@Entity('complaint_comment')
export class ComplaintComment {
  @PrimaryGeneratedColumn('uuid')
  declare id: string;

  @Index('idx_comment_complaint')
  @Column({ name: 'complaint_id', type: 'uuid' })
  declare complaintId: string;

  @Column({ name: 'device_key', type: 'varchar', length: 64 })
  declare deviceKey: string;

  @Column({ name: 'author_name', type: 'varchar', length: 40 })
  declare authorName: string;

  @Column({ name: 'author_color', type: 'varchar', length: 6 })
  declare authorColor: string;

  @Column({ type: 'text' })
  declare body: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  declare createdAt: Date;
}
