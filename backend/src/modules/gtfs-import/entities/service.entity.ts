import { Column, Entity, PrimaryColumn } from 'typeorm';

/** calendar.txt — calendario de servicio. */
@Entity('service')
export class Service {
  @PrimaryColumn({ name: 'service_id', type: 'varchar', length: 64 })
  declare id: string;

  @Column({ name: 'monday', type: 'boolean' })
  declare monday: boolean;

  @Column({ name: 'tuesday', type: 'boolean' })
  declare tuesday: boolean;

  @Column({ name: 'wednesday', type: 'boolean' })
  declare wednesday: boolean;

  @Column({ name: 'thursday', type: 'boolean' })
  declare thursday: boolean;

  @Column({ name: 'friday', type: 'boolean' })
  declare friday: boolean;

  @Column({ name: 'saturday', type: 'boolean' })
  declare saturday: boolean;

  @Column({ name: 'sunday', type: 'boolean' })
  declare sunday: boolean;

  /** Formato GTFS YYYYMMDD. */
  @Column({ name: 'start_date', type: 'varchar', length: 8 })
  declare startDate: string;

  /** Formato GTFS YYYYMMDD. */
  @Column({ name: 'end_date', type: 'varchar', length: 8 })
  declare endDate: string;
}
