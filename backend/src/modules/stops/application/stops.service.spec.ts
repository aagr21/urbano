import { NotFoundException } from '@nestjs/common';
import { StopsService } from './stops.service';
import type { StopNearbyPage, StopSearchPage, StopDetail, StopRepositoryPort } from '../domain/stop.model';

/** Puerto LED de parada cerca: responde lo configurado y registra los args. */
class RecordingPort implements Partial<StopRepositoryPort> {
  calls: Array<Record<string, unknown>> = [];

  constructor(
    private readonly nearbyPage: StopNearbyPage = { items: [], total: 0 },
    private readonly searchPage: StopSearchPage = { items: [], total: 0 },
    private readonly detail: StopDetail | null = null,
  ) {}

  async findNearby(query: {
    lat: number;
    lon: number;
    radiusMeters: number;
    limit: number;
    offset?: number;
  }): Promise<StopNearbyPage> {
    this.calls.push({ op: 'nearby', ...query });
    return this.nearbyPage;
  }

  async search(q: string, limit: number): Promise<StopSearchPage> {
    this.calls.push({ op: 'search', q, limit });
    return this.searchPage;
  }

  async findById(id: string): Promise<StopDetail | null> {
    this.calls.push({ op: 'detail', id });
    return this.detail;
  }
}

describe('StopsService', () => {
  it('nearby pasa lat/lon y valores por defecto del DTO (radio 400, límite 10) al puerto', async () => {
    const port = new RecordingPort({ items: [], total: 0 });
    const service = new StopsService(port as unknown as StopRepositoryPort);

    const result = await service.nearby({ lat: -17.78, lon: -63.15, radius: 400, limit: 10 });

    expect(port.calls[0]).toEqual({
      op: 'nearby',
      lat: -17.78,
      lon: -63.15,
      radiusMeters: 400,
      limit: 10,
    });
    // La página VUELVE SIN PAGINACIÓN REAL: siempre page 1, límita = limit.
    expect(result.meta).toEqual({ page: 1, limit: 10, total: 0 });
  });

  it('search hace TRIM del texto antes de pedir al puerto', async () => {
    const port = new RecordingPort({ items: [], total: 0 }, { items: [], total: 7 });
    const service = new StopsService(port as unknown as StopRepositoryPort);

    const result = await service.search({ q: '  cuatro anillo  ', limit: 10 });

    expect(port.calls[0]).toEqual({ op: 'search', q: 'cuatro anillo', limit: 10 });
    expect(result.meta).toEqual({ page: 1, limit: 10, total: 7 });
  });

  it('detail existe: devuelve StopDetail tal cual', async () => {
    const stop: StopDetail = {
      id: 'S1',
      code: null,
      name: 'Parada 1',
      lat: 0,
      lon: 0,
      routes: [],
      location: { type: 'Point', coordinates: [0, 0] },
    };
    const service = new StopsService(
      new RecordingPort({ items: [], total: 0 }, { items: [], total: 0 }, stop) as unknown as StopRepositoryPort,
    );
    await expect(service.detail('S1')).resolves.toBe(stop);
  });

  it('detail inexistente: NotFoundException con el id del mensaje (contrato 404)', async () => {
    const service = new StopsService(
      new RecordingPort() as unknown as StopRepositoryPort,
    );
    await expect(service.detail('S-x')).rejects.toThrowError(new NotFoundException('Stop S-x not found'));
  });
});
