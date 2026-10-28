import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { AppModule } from "./app.module";
import { configureApp } from "./app.setup";
import { AppConfigService } from "./core/config/app-config.service";
import { ensurePostgresExtensions } from "./core/infrastructure/postgres-extensions";

async function bootstrap(): Promise<void> {
    // Asegura extensiones PostGIS antes de que TypeORM sincronice el esquema
    await ensurePostgresExtensions().catch(error => {
        // eslint-disable-next-line no-console
        console.warn(
            "No se pudieron crear las extensiones PostGIS (¿corriendo el contenedor?):",
            error instanceof Error ? error.message : error,
        );
    });

    const app = await NestFactory.create(AppModule);
    const config = app.get(AppConfigService);

    configureApp(app, config);

    const swaggerConfig = new DocumentBuilder()
        .setTitle("Urbano API")
        .setDescription("API de transporte público (micros urbanos) de Santa Cruz de la Sierra")
        .setVersion("1.0.0")
        .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup("docs", app, document, {
        customSiteTitle: "Urbano API Docs",
    });

    await app.listen(config.port, "0.0.0.0");
    // eslint-disable-next-line no-console
    console.log(`Urbano API escuchando en http://localhost:${config.port}/api/v1 (docs en /docs)`);
}

void bootstrap();
