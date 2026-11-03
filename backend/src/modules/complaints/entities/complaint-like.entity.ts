import { CreateDateColumn, Entity, PrimaryColumn } from 'typeorm';

/**
 * Un «apoyo» (like) de una queja hecho por un dispositivo concreto.
 * La PK compuesta (queja, dispositivo) es lo que garantiza que la misma
 * instalación no pueda contar dos veces en el mismo post.
 */
@Entity('complaint_like')
export class ComplaintLike {
  @PrimaryColumn({ name: 'complaint_id', type: 'uuid' })
  declare complaintId: string;

  @PrimaryColumn({ name: 'device_key', type: 'varchar', length: 64 })
  declare deviceKey: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  declare createdAt: Date;
}
