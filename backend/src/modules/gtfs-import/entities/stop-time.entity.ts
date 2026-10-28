import { Column, Entity, PrimaryColumn } from 'typeorm';

/** stop_times.txt — PK compuesta (trip_id, stop_sequence). */
@Entity('stop_time')
export class StopTime {
  @PrimaryColumn({ name: 'trip_id', type: 'varchar', length: 64 })
  tripId: string;

  @PrimaryColumn({ name: 'stop_sequence', type: 'int' })
  stopSequence: number;

  @Column({ name: 'stop_id', type: 'varchar', length: 64 })
  stopId: string;

  /** HH:mm:ss GTFS. */
  @Column({ name: 'arrival_time', type: 'varchar', length: 16 })
  arrivalTime: string;

  /** HH:mm:ss GTFS. */
  @Column({ name: 'departure_time', type: 'varchar', length: 16 })
  departureTime: string;

  @Column({ name: 'pickup_type', type: 'int', default: 0 })
  pickupType: number;

  @Column({ name: 'drop_off_type', type: 'int', default: 0 })
  dropOffType: number;

  /** Distancia acumulada desde el inicio del shape (metros). */
  @Column({ name: 'shape_dist_traveled', type: 'double precision', nullable: true })
  shapeDistTraveled: number | null;
}
