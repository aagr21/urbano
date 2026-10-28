import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { TRIP_REPOSITORY } from '../../../core/common/tokens';
import { TripDetail, TripRepositoryPort } from '../domain/trip.model';

@Injectable()
export class TripsService {
  constructor(
    @Inject(TRIP_REPOSITORY) private readonly tripRepository: TripRepositoryPort,
  ) {}

  async detail(id: string): Promise<TripDetail> {
    const record = await this.tripRepository.findById(id);
    if (!record) {
      throw new NotFoundException(`Trip ${id} not found`);
    }
    return {
      id: record.id,
      routeId: record.routeId,
      routeShortName: record.routeShortName,
      routeColor: record.routeColor,
      directionId: record.directionId,
      headsign: record.headsign,
      serviceId: record.serviceId,
      stopTimes: record.stopTimes.map((st) => ({
        stopId: st.stopId,
        name: st.name ?? '',
        sequence: st.sequence,
        arrivalTime: st.arrivalTime,
        departureTime: st.departureTime,
        distanceMeters: st.distanceMeters,
        pickupAllowed: st.pickupType === 0,
        dropOffAllowed: st.dropOffType === 0,
      })),
    };
  }
}
