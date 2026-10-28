import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/network/api_client.dart';
import 'package:urbano/src/core/network/api_exception.dart';
import 'package:urbano/src/features/home/data/stats_repository.dart';
import 'package:urbano/src/features/journey/data/journey_repository.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';

/// Integración de extremo a extremo: los repositorios REALES de la app
/// contra el backend NestJS en ejecución (Postgres+PostGIS + GTFS importado).
///
/// Si el backend no está levantado, los tests se marcan como skip en vez de
/// fallar. El check y el cliente se crean DENTRO del test: en `flutter test`
/// la conexión falla si se abre fuera de la zona del test.
///
/// ```sh
/// cd backend && docker compose up -d && npm run import:gtfs && npm run start:dev
/// cd .. && flutter test test/api_integration_test.dart
/// ```
Future<void> main() async {
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  Future<bool>? onlineFuture;
  Future<bool> backendUp() => onlineFuture ??= _isBackendUp('$baseUrl/health');

  // Envuelve el cuerpo: salta con mensaje claro si el backend está caído.
  Future<void> guard(Future<void> Function() body) async {
    if (!await backendUp()) {
      markTestSkipped(
        'Backend no disponible en $baseUrl '
        '(arráncalo: cd backend && npm run start:dev)',
      );
      return;
    }
    await body();
  }

  late ApiClient api;
  late RemoteRouteRepository routes;
  late RemoteJourneyRepository journey;
  late RemoteStatsRepository stats;

  setUp(() {
    api = ApiClient(baseUrl: baseUrl, maxRetries: 0);
    routes = RemoteRouteRepository(api);
    journey = RemoteJourneyRepository(api);
    stats = RemoteStatsRepository(api);
  });

  tearDown(() => api.close());

  group('integración API real ($baseUrl)', () {
    test(
      'stats refleja el feed GTFS importado',
      () => guard(() async {
        final s = await stats.stats();
        expect(s.routes, 154);
        expect(s.stops, 31461);
        expect(s.trips, 308);
        expect(s.headwaySeconds, 300);
        expect(s.firstDeparture, '06:00:00');
        expect(s.lastDeparture, '22:00:00');
      }),
    );

    test(
      'listado de rutas con colores y meta',
      () => guard(() async {
        final page = await routes.list(q: '101', limit: 10);
        expect(page.items, isNotEmpty);
        expect(page.meta.total, greaterThan(0));
        final first = page.items.first;
        expect(first.color, matches(RegExp(r'^[0-9A-Fa-f]{6}$')));
        expect(first.stopCount, greaterThan(0));
      }),
    );

    test(
      'detalle de ruta: direcciones, bbox y shape GeoJSON válido',
      () => guard(() async {
        final page = await routes.list(limit: 1);
        final detail = await routes.detail(page.items.first.id);

        expect(detail.directions, hasLength(2));
        expect(detail.bbox, hasLength(4));

        final shape = detail.shape;
        expect(shape, isNotNull);
        expect(shape!.points.length, greaterThan(10));
        // Coordenadas de Santa Cruz.
        expect(shape.points.first.longitude, inInclusiveRange(-64, -62));
        expect(shape.points.first.latitude, inInclusiveRange(-19, -17));
      }),
    );

    test(
      'próximas salidas con horario GTFS',
      () => guard(() async {
        final page = await routes.list(limit: 1);
        final list = await routes.departures(
          page.items.first.id,
          time: '08:00',
        );
        expect(list, isNotEmpty);
        expect(list, hasLength(lessThanOrEqualTo(20)));
        expect(list.first.time, matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
        expect(list.first.headwaySeconds, 300);
      }),
    );

    test(
      'planeador de viaje: opciones con legs ordenadas por duración',
      () => guard(() async {
        final options = await journey.plan(
          origin: (lat: -17.78, lon: -63.15),
          destination: (lat: -17.79, lon: -63.16),
          time: '08:00',
        );
        expect(options, isNotEmpty);
        expect(options.first.legs, isNotEmpty);
        expect(options.first.durationMinutes, greaterThan(0));
        final durations = options.map((o) => o.durationMinutes).toList();
        expect(durations, List<int>.of(durations)..sort());
      }),
    );

    test(
      'journey enriquecido: geometría de mapa y paradas con coordenadas',
      () => guard(() async {
        final options = await journey.plan(
          origin: (lat: -17.78, lon: -63.15),
          destination: (lat: -17.79, lon: -63.16),
          time: '08:00',
        );
        expect(options, isNotEmpty);

        final option = options.first;
        // El origen/destino es un punto libre: la caminata va del punto
        // exacto hasta la parada, que el backend envía con coordenadas.
        expect(option.walkToStop?.lat, isNotNull);
        expect(option.walkToStop?.lon, isNotNull);
        expect(option.walkFromStop?.lat, isNotNull);

        final busLegs = option.legs.where((l) => l.isBus);
        expect(busLegs, isNotEmpty);
        for (final leg in busLegs) {
          expect(leg.fromStop?.lat, isNotNull);
          expect(leg.toStop?.lon, isNotNull);

          // Tramo del shape recortado entre paradas (null si no hay).
          final geometry = leg.geometry;
          if (geometry != null) {
            expect(geometry.length, greaterThanOrEqualTo(2));
            for (final point in geometry) {
              expect(point.longitude, inInclusiveRange(-64, -62));
              expect(point.latitude, inInclusiveRange(-19, -17));
            }
          }
        }
      }),
    );

    test(
      'error 404 con envoltorio {error}',
      () => guard(() async {
        await expectLater(
          routes.detail('RUTA-QUE-NO-EXISTE'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
          ),
        );
      }),
    );
  });
}

Future<bool> _isBackendUp(String url) async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final req = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 2));
    final res = await req.close().timeout(const Duration(seconds: 2));
    await res.drain<void>();
    client.close(force: true);
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}
