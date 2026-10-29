import { Column, Entity, PrimaryGeneratedColumn } from 'typeorm';

/** frequencies.txt — frecuencias por trip (headways). */
@Entity('frequency')
export class Frequency {
  @PrimaryGeneratedColumn({ name: 'id', type: 'int' })
  declare id: number;

  @Column({ name: 'trip_id', type: 'varchar', length: 64 })
  declare tripId: string;

  /** HH:mm:ss GTFS. */
  @Column({ name: 'start_time', type: 'varchar', length: 16 })
  declare startTime: string;

  /** HH:mm:ss GTFS. */
  @Column({ name: 'end_time', type: 'varchar', length: 16 })
  declare endTime: string;

  @Column({ name: 'headway_secs', type: 'int' })
  headwaySeconds: number;

  /** 0 = aproximado, 1 = exacto (GTFS: exact_times). */
  @Column({ name: 'exact_times', type: 'int', default: 0 })
  exactTimes: number;
}
