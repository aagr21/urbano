import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import type { INestApplication } from '@nestjs/common';
import { AppModule } from './app.module';
import { configureApp } from './app.setup';
import { AppConfigService } from './core/config/app-config.service';
import { ensurePostgresExtensions } from './core/infrastructure/postgres-extensions';

export async function createApp(): Promise<INestApplication> {
  await ensurePostgresExtensions().catch((error: unknown) => {
    // eslint-disable-next-line no-console
    console.warn(
      'No se pudieron crear las extensiones PostGIS:',
      error instanceof Error ? error.message : error,
    );
  });

  const app = await NestFactory.create(AppModule);
  const config = app.get(AppConfigService);

  configureApp(app, config);

  const swaggerConfig = new DocumentBuilder()
    .setTitle('Urbano API')
    .setDescription(
      'API de transporte público (micros urbanos) de Santa Cruz de la Sierra',
    )
    .setVersion('1.0.0')
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('docs', app, document, {
    customSiteTitle: 'Urbano API Docs',
  });

  await app.init();
  return app;
}
