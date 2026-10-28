import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { isSkipWrapper } from '../decorators/skip-wrapper.decorator';
import { isPaginatedResult } from '../models/paginated';

/**
 * Envoltorio de respuestas exitosas del contrato:
 * `{ "data": <payload>, "meta": { "page": 1, "limit": 20, "total": 154 } }`
 *
 * - Handlers con @SkipWrapper() pasan sin envolver (ej: /health)
 * - `PaginatedResult` → data = items, meta = {page, limit, total}
 * - cualquier otro payload → data = payload, meta = null
 */
@Injectable()
export class ResponseWrapperInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const handler = context.getHandler();
    if (isSkipWrapper(handler)) {
      return next.handle();
    }
    return next.handle().pipe(
      map((result) => {
        if (result === undefined) {
          return { data: null, meta: null };
        }
        if (isPaginatedResult(result)) {
          return { data: result.items, meta: result.meta };
        }
        return { data: result, meta: null };
      }),
    );
  }
}
