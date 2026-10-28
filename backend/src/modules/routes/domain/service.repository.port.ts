/** Registro crudo del calendario de servicio activo. */
export interface ServiceCalendarRecord {
  serviceId: string;
  monday: boolean;
  tuesday: boolean;
  wednesday: boolean;
  thursday: boolean;
  friday: boolean;
  saturday: boolean;
  sunday: boolean;
  /** YYYYMMDD */
  startDate: string;
  /** YYYYMMDD */
  endDate: string;
}

/** Puerto para consultar el calendario de servicio (calendar.txt). */
export abstract class ServiceRepositoryPort {
  abstract findActiveCalendar(): Promise<ServiceCalendarRecord | null>;
}
