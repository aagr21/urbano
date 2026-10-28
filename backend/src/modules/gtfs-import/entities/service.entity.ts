import { Column, Entity, PrimaryColumn } from 'typeorm';

/** calendar.txt — calendario de servicio. */
@Entity('service')
export class Service {
  @PrimaryColumn({ name: 'service_id', type: 'varchar', length: 64 })
  id: string;

  @Column({ name: 'monday', type: 'boolean' })
  monday: boolean;

  @Column({ name: 'tuesday', type: 'boolean' })
  tuesday: boolean;

  @Column({ name: 'wednesday', type: 'boolean' })
  wednesday: boolean;

  @Column({ name: 'thursday', type: 'boolean' })
  thursday: boolean;

  @Column({ name: 'friday', type: 'boolean' })
  friday: boolean;

  @Column({ name: 'saturday', type: 'boolean' })
  saturday: boolean;

  @Column({ name: 'sunday', type: 'boolean' })
  sunday: boolean;

  /** Formato GTFS YYYYMMDD. */
  @Column({ name: 'start_date', type: 'varchar', length: 8 })
  startDate: string;

  /** Formato GTFS YYYYMMDD. */
  @Column({ name: 'end_date', type: 'varchar', length: 8 })
  endDate: string;
}
