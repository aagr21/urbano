import { Column, Entity, PrimaryColumn } from "typeorm";

/** stop_times.txt — PK compuesta (trip_id, stop_sequence). */
@Entity("stop_time")
export class StopTime {
    @PrimaryColumn({ name: "trip_id", type: "varchar", length: 64 })
    declare tripId: string;

    @PrimaryColumn({ name: "stop_sequence", type: "int" })
    declare stopSequence: number;

    @Column({ name: "stop_id", type: "varchar", length: 64 })
    declare stopId: string;

    /** HH:mm:ss GTFS. */
    @Column({ name: "arrival_time", type: "varchar", length: 16 })
    declare arrivalTime: string;

    /** HH:mm:ss GTFS. */
    @Column({ name: "departure_time", type: "varchar", length: 16 })
    declare departureTime: string;

    @Column({ name: "pickup_type", type: "int", default: 0 })
    declare pickupType: number;

    @Column({ name: "drop_off_type", type: "int", default: 0 })
    declare dropOffType: number;

    /** Distancia acumulada desde el inicio del shape (metros). */
    @Column({ name: "shape_dist_traveled", type: "double precision", nullable: true })
    declare shapeDistTraveled: number | null;
}
