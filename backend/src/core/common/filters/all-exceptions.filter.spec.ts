import { ArgumentsHost, BadRequestException, HttpException, HttpStatus } from '@nestjs/common';
import { AllExceptionsFilter } from './all-exceptions.filter';

/** El filtro emite SIEMPRE el envoltorio de error del contrato. */
describe('AllExceptionsFilter (contrato de errores { error: { statusCode, message, details } })', () => {
  type Captured = { status: number; body: Record<string, unknown> | null };

  /** Host falso con response espía: captura status + json emitido. */
  const runWith = (exception: unknown): Captured => {
    const captured: Captured = { status: 0, body: null };
    const response = {
      status: (code: number) => {
        captured.status = code;
        return response;
      },
      json: (body: Record<string, unknown>) => {
        captured.body = body;
      },
    };
    const host = {
      switchToHttp: () => ({
        getResponse: () => response,
        getRequest: () => ({ method: 'GET', url: '/api/v1/journey' }),
      }),
    } as unknown as ArgumentsHost;

    new AllExceptionsFilter().catch(exception, host);
    return captured;
  };

  it('un HttpException conservan su status y su mensaje', () => {
    const { status, body } = runWith(
      new HttpException({ message: 'Route 999 not found' }, HttpStatus.NOT_FOUND),
    );
    expect(status).toBe(404);
    expect(body).toEqual({
      error: { statusCode: 404, message: 'Route 999 not found', details: null },
    });
  });

  it('un BadRequest con messages array (validación) queda "Validation failed" + details', () => {
    const { status, body } = runWith(
      new BadRequestException({ message: ['time debe ser HH:mm', 'origin requerido'] }),
    );
    expect(status).toBe(400);
    expect(body).toEqual({
      error: {
        statusCode: 400,
        message: 'Validation failed',
        details: ['time debe ser HH:mm', 'origin requerido'],
      },
    });
  });

  it('una excepción HttpException con mensaje string sale íntegra', () => {
    const { status, body } = runWith(new HttpException('Planeta crowd', 429));
    expect(status).toBe(429);
    expect(body).toEqual({
      error: { statusCode: 429, message: 'Planeta crowd', details: null },
    });
  });

  it('un Error 500 (desconocido) sale como 500 genérico sin filtrar detalles', () => {
    const { status, body } = runWith(new Error('boom de base'));
    expect(status).toBe(500);
    expect(body).toEqual({
      error: { statusCode: 500, message: 'Internal server error', details: null },
    });
  });
});
