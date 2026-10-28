import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { TripRepositoryPort } from '../domain/trip.repository.port';
import { TripDetailRecord } from '../domain/trip.model';

@Injectable()
export class TypeOrmTripRepository implements TripRepositoryPort {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async findById(id: string): Promise<TripDetailRecord | null> {
    const headerRows: Array<{
      id: string;
      routeId: string;
      routeShortName: string;
      routeColor: string | null;
      directionId: number;
      headsign: string | null;
      serviceId: string;
    }> = await this.dataSource.query(
      `SELECT t.trip_id AS id,
              t.route_id AS "routeId",
              r.route_short_name AS "routeShortName",
              r.route_color AS "routeColor",
              t.direction_id AS "directionId",
              t.trip_headsign AS headsign,
              t.service_id AS "serviceId"
       FROM trip t
       JOIN route r ON r.route_id = t.route_id
       WHERE t.trip_id = $1`,
      [id],
    );
    if (headerRows.length === 0) return null;

    const stopTimes: TripDetailRecord['stopTimes'] = await this.dataSource.query(
      `SELECT st.stop_id AS "stopId",
              s.stop_name AS name,
              st.stop_sequence AS sequence,
              st.arrival_time AS "arrivalTime",
              st.departure_time AS "departureTime",
              COALESCE(st.shape_dist_traveled, 0) AS "distanceMeters",
              st.pickup_type AS "pickupType",
              st.drop_off_type AS "dropOffType"
       FROM stop_time st
       LEFT JOIN stop s ON s.stop_id = st.stop_id
       WHERE st.trip_id = $1
       ORDER BY st.stop_sequence ASC`,
      [id],
    );

    return { ...headerRows[0], stopTimes };
  }
}
