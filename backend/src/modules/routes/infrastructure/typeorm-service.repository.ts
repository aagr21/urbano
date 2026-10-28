import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import {
  ServiceCalendarRecord,
  ServiceRepositoryPort,
} from '../domain/service.repository.port';

@Injectable()
export class TypeOrmServiceRepository implements ServiceRepositoryPort {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async findActiveCalendar(): Promise<ServiceCalendarRecord | null> {
    const rows: ServiceCalendarRecord[] = await this.dataSource.query(
      `SELECT service_id AS "serviceId",
              monday, tuesday, wednesday, thursday, friday, saturday, sunday,
              start_date AS "startDate",
              end_date AS "endDate"
       FROM service
       ORDER BY service_id ASC
       LIMIT 1`,
    );
    return rows[0] ?? null;
  }
}
