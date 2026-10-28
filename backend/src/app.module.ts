import { CacheModule } from '@nestjs/cache-manager';
import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppConfigModule } from './core/config/config.module';
import { CACHE_TTL_MS } from './core/common/tokens';
import { buildTypeOrmOptions } from './core/infrastructure/typeorm-config';
import { AppConfigService } from './core/config/app-config.service';
import { DatabaseSetupService } from './core/infrastructure/database-setup.service';
import { GtfsImportModule } from './modules/gtfs-import/gtfs-import.module';
import { HealthModule } from './modules/health/health.module';
import { JourneyModule } from './modules/journey/journey.module';
import { RoutesModule } from './modules/routes/routes.module';
import { StatsModule } from './modules/stats/stats.module';
import { StopsModule } from './modules/stops/stops.module';
import { TripsModule } from './modules/trips/trips.module';

@Module({
  imports: [
    AppConfigModule,
    TypeOrmModule.forRootAsync({
      inject: [AppConfigService],
      useFactory: (config: AppConfigService) => buildTypeOrmOptions(config),
    }),
    // Caché en memoria global (endpoints de lectura la usan vía CacheInterceptor)
    CacheModule.register({ ttl: CACHE_TTL_MS, isGlobal: true }),
    ThrottlerModule.forRoot({ throttlers: [{ ttl: 60_000, limit: 600 }] }),
    GtfsImportModule,
    RoutesModule,
    StopsModule,
    TripsModule,
    JourneyModule,
    StatsModule,
    HealthModule,
  ],
  providers: [
    DatabaseSetupService,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule {}
