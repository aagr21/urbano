import { CallHandler, ExecutionContext, Injectable, Logger, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';
import { finalize } from 'rxjs/operators';

/** Log estructurado de peticiones HTTP (método, ruta, status, duración). */
@Injectable()
export class RequestLoggerInterceptor implements NestInterceptor {
  private readonly logger = new Logger('http');

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') {
      return next.handle();
    }
    const started = Date.now();
    const request = context.switchToHttp().getRequest<{ method: string; url: string }>();
    const response = context.switchToHttp().getResponse<{ statusCode: number }>();

    return next.handle().pipe(
      finalize(() => {
        const durationMs = Date.now() - started;
        this.logger.log(
          `${request.method} ${request.url} ${response.statusCode} ${durationMs}ms`,
        );
      }),
    );
  }
}
