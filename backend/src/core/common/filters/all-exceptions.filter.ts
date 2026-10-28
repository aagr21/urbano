import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/**
 * Filtro global de excepciones. Emite SIEMPRE el envoltorio de error del contrato:
 * `{ "error": { "statusCode": 404, "message": "Route 999 not found", "details": null } }`
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string = 'Internal server error';
    let details: unknown = null;

    if (exception instanceof HttpException) {
      statusCode = exception.getStatus();
      const payload = exception.getResponse();
      if (typeof payload === 'string') {
        message = payload;
      } else if (typeof payload === 'object' && payload !== null) {
        const body = payload as { message?: unknown; error?: unknown };
        if (Array.isArray(body.message)) {
          message = 'Validation failed';
          details = body.message;
        } else if (typeof body.message === 'string') {
          message = body.message;
        }
      }
    } else if (exception instanceof Error) {
      this.logger.error(
        `500 ${request.method} ${request.url}: ${exception.message}`,
        exception.stack,
      );
    }

    response.status(statusCode).json({ error: { statusCode, message, details } });
  }
}
