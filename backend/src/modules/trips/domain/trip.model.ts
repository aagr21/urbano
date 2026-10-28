/** Modelos de dominio de viajes (trips + stop_times). */

export interface TripStopTime {
  stopId: string;
  name: string;
  sequence: number;
  arrivalTime: string;
  departureTime: string;
  distanceMeters: number;
  pickupAllowed: boolean;
  dropOffAllowed: boolean;
}

export interface TripDetail {
  id: string;
  routeId: string;
  routeShortName: string;
  routeColor: string | null;
  directionId: number;
  headsign: string | null;
  serviceId: string;
  stopTimes: TripStopTime[];
}

export interface TripStopTimeRecord {
  stopId: string;
  name: string | null;
  sequence: number;
  arrivalTime: string;
  departureTime: string;
  distanceMeters: number;
  pickupType: number;
  dropOffType: number;
}

export interface TripDetailRecord {
  id: string;
  routeId: string;
  routeShortName: string;
  routeColor: string | null;
  directionId: number;
  headsign: string | null;
  serviceId: string;
  stopTimes: TripStopTimeRecord[];
}

/** Puerto del repositorio de viajes. */
export abstract class TripRepositoryPort {
  abstract findById(id: string): Promise<TripDetailRecord | null>;
}
