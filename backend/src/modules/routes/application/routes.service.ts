import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { nowSecondsInTimeZone, timeToSeconds } from '../../../core/common/utils/gtfs-time';
import { ROUTE_REPOSITORY, SERVICE_REPOSITORY } from '../../../core/common/tokens';
import { PaginatedResult } from '../../../core/common/models/paginated';
import { RouteRepositoryPort } from '../domain/route.repository.port';
import { ServiceRepositoryPort } from '../domain/service.repository.port';
import {
  RouteDeparture,
  RouteDetail,
  RouteStop,
  RouteSummary,
} from '../domain/route.model';
import { computeUpcomingDepartures } from './departures';
import { ListRoutesQueryDto, RouteDeparturesQueryDto } from './route.dto';

/** Fecha YYYY-MM-DD → día de la semana (0 = domingo, estilo Date UTC). */
function dayOfWeekIso(dateStr: string): number {
  return new Date(`${dateStr}T12:00:00Z`).getUTCDay();
}

@Injectable()
export class RoutesService {
  constructor(
    @Inject(ROUTE_REPOSITORY) private readonly routeRepository: RouteRepositoryPort,
    @Inject(SERVICE_REPOSITORY) private readonly serviceRepository: ServiceRepositoryPort,
  ) {}

  async list(query: ListRoutesQueryDto): Promise<PaginatedResult<RouteSummary>> {
    const { items, total } = await this.routeRepository.findAll({
      q: query.q,
      page: query.page,
      limit: query.limit,
      sort: query.sort ?? 'name',
    });
    return new PaginatedResult(items, {
      page: query.page,
      limit: query.limit,
      total,
    });
  }

  async detail(id: string, directionId?: number): Promise<RouteDetail> {
    const record = await this.routeRepository.findById(id);
    if (!record) {
      throw new NotFoundException(`Route ${id} not found`);
    }

    const directions = record.directions.map((d) => ({
      directionId: d.directionId,
      headsign: d.headsign,
      tripId: d.tripId,
      firstDeparture: d.firstDeparture,
      lastDeparture: d.lastDeparture,
      headwaySeconds: d.headwaySeconds,
      stopCount: d.stopCount,
    }));

    // shape = dirección pedida; si no se pidió, directionId 0 si existe.
    const wanted =
      directionId !== undefined
        ? record.directions.find((d) => d.directionId === directionId)
        : undefined;
    const fallback =
      record.directions.find((d) => d.directionId === 0) ?? record.directions[0];
    const selected = wanted ?? fallback;

    const shapeId = selected?.shapeId;
    const shapeData = shapeId ? record.shapes[shapeId] : undefined;

    const { directions: _directions, shapes: _shapes, ...summary } = record;

    return {
      ...summary,
      bbox: shapeData?.bbox ?? null,
      directions,
      shape:
        shapeData && shapeId
          ? {
              type: 'Feature',
              properties: { id: shapeId },
              geometry: { type: 'LineString', coordinates: shapeData.coordinates },
            }
          : null,
    };
  }

  async stops(id: string, directionId = 0): Promise<RouteStop[]> {
    const exists = await this.routeRepository.findById(id);
    if (!exists) {
      throw new NotFoundException(`Route ${id} not found`);
    }
    const stops = await this.routeRepository.findStops(id, directionId);
    return stops.map((s) => ({
      id: s.id,
      code: s.code,
      name: s.name,
      lat: s.lat,
      lon: s.lon,
      sequence: s.sequence,
      arrivalTime: s.arrivalTime,
      departureTime: s.departureTime,
      distanceMeters: s.distanceMeters,
    }));
  }

  async departures(
    id: string,
    stopId: string | undefined,
    query: RouteDeparturesQueryDto,
  ): Promise<RouteDeparture[]> {
    const exists = await this.routeRepository.findById(id);
    if (!exists) {
      throw new NotFoundException(`Route ${id} not found`);
    }

    // Ventana de referencia: hora pedida o ahora en America/La_Paz
    const fromSeconds = query.time
      ? timeToSeconds(query.time)
      : nowSecondsInTimeZone('America/La_Paz');

    // Si el feed no sirve ese día, no hay salidas
    if (query.date && !(await this.isServiceDay(query.date))) {
      return [];
    }

    // Sin stopId ⇒ salidas desde la primera parada de cada viaje.
    const sources = await this.routeRepository.findDepartureSources(
      id,
      stopId ?? null,
      query.directionId,
    );
    if (sources.length === 0) {
      return [];
    }
    return computeUpcomingDepartures(sources, fromSeconds, 20);
  }

  private async isServiceDay(dateStr: string): Promise<boolean> {
    const calendar = await this.serviceRepository.findActiveCalendar();
    if (!calendar) return true;
    const start = Number.parseInt(calendar.startDate, 10);
    const end = Number.parseInt(calendar.endDate, 10);
    const date = Number.parseInt(dateStr.replace(/-/g, ''), 10);
    if (date < start || date > end) return false;
    const dow = dayOfWeekIso(dateStr);
    const days = [
      calendar.sunday,
      calendar.monday,
      calendar.tuesday,
      calendar.wednesday,
      calendar.thursday,
      calendar.friday,
      calendar.saturday,
    ];
    return days[dow] === true;
  }
}
