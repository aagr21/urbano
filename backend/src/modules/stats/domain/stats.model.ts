/** Modelo de dominio de estadísticas del feed. */
export interface FeedStats {
  routes: number;
  stops: number;
  trips: number;
  shapes: number;
  service: {
    start: string;
    end: string;
    days: string;
  };
  firstDeparture: string;
  lastDeparture: string;
  headwaySeconds: number | null;
}

export abstract class StatsRepositoryPort {
  abstract getStats(): Promise<FeedStats>;
}
