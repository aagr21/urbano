import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { FeedStats, StatsRepositoryPort } from '../domain/stats.model';

const WEEKDAY_KEYS = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
] as const;

@Injectable()
export class TypeOrmStatsRepository implements StatsRepositoryPort {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async getStats(): Promise<FeedStats> {
    const [counters] = await this.dataSource.query(
      `SELECT (SELECT COUNT(*)::int FROM route) AS routes,
              (SELECT COUNT(*)::int FROM stop) AS stops,
              (SELECT COUNT(*)::int FROM trip) AS trips,
              -- "shapes" del contrato = total de puntos del feed (filas de shapes.txt)
              (SELECT COALESCE(SUM(point_count), 0)::int FROM shape) AS shapes`,
    );

    const [service] = await this.dataSource.query(
      `SELECT service_id AS "serviceId",
              monday, tuesday, wednesday, thursday, friday, saturday, sunday,
              start_date AS "startDate",
              end_date AS "endDate"
       FROM service
       ORDER BY service_id ASC
       LIMIT 1`,
    );

    const [frequency] = await this.dataSource.query(
      `SELECT MIN(start_time) AS "firstDeparture",
              MAX(end_time) AS "lastDeparture",
              MIN(headway_secs) AS "headwaySeconds"
       FROM frequency`,
    );

    const days = service
      ? describeDays(
          WEEKDAY_KEYS.map((k) => service[k] === true || service[k] === '1'),
        )
      : 'desconocido';

    return {
      routes: counters?.routes ?? 0,
      stops: counters?.stops ?? 0,
      trips: counters?.trips ?? 0,
      shapes: counters?.shapes ?? 0,
      service: {
        start: formatDate(service?.startDate),
        end: formatDate(service?.endDate),
        days,
      },
      firstDeparture: frequency?.firstDeparture ?? '00:00:00',
      lastDeparture: frequency?.lastDeparture ?? '00:00:00',
      headwaySeconds: frequency?.headwaySeconds ?? null,
    };
  }
}

/** YYYYMMDD → YYYY-MM-DD */
function formatDate(raw: string | undefined): string {
  if (!raw || raw.length !== 8) return '';
  return `${raw.slice(0, 4)}-${raw.slice(4, 6)}-${raw.slice(6, 8)}`;
}

/** [lun..dom] → "diario" | "lunes a viernes" | "lunes, martes..." */
function describeDays(active: boolean[]): string {
  const all = active.every(Boolean);
  if (all) return 'diario';
  const weekdays = [0, 1, 2, 3, 4]; // lunes..viernes (índice 0 = lunes)
  if (
    weekdays.every((i) => active[i]) &&
    !active[5] &&
    !active[6]
  ) {
    return 'lunes a viernes';
  }
  const names = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  const activeNames = active
    .map((on, i) => (on ? names[i] : null))
    .filter((n): n is string => n !== null);
  return activeNames.length > 0 ? activeNames.join(', ') : 'sin servicio';
}
