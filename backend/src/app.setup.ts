import { ValidationPipe } from '@nestjs/common';
import type { INestApplication } from '@nestjs/common';
import helmet from 'helmet';
import { AppConfigService } from './core/config/app-config.service';
import { AllExceptionsFilter } from './core/common/filters/all-exceptions.filter';
import { ResponseWrapperInterceptor } from './core/common/interceptors/response-wrapper.interceptor';
import { RequestLoggerInterceptor } from './core/common/interceptors/request-logger.interceptor';

/**
 * Configuración global de la aplicación (prefijo, CORS, helmet, pipes,
 * filtros e interceptores). Compartida entre `main.ts` y los tests e2e
 * para que corran con exactamente el mismo pipeline que producción.
 */
export function configureApp(app: INestApplication, config: AppConfigService): void {
  app.setGlobalPrefix('api/v1', { exclude: ['docs'] });

  const origins = config.corsOrigins;
  app.enableCors({
    origin: origins.includes('*') ? true : origins,
    methods: ['GET', 'HEAD', 'OPTIONS'],
  });

  app.use(helmet());
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: false,
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());
  app.useGlobalInterceptors(
    new ResponseWrapperInterceptor(),
    new RequestLoggerInterceptor(),
  );
}
