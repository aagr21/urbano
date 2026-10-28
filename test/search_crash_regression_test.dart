import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/network/api_client.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/home/data/stats.dart';
import 'package:urbano/src/features/home/presentation/home_providers.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/routes/presentation/route_detail_screen.dart';
import 'package:urbano/src/features/routes/presentation/route_providers.dart';
import 'package:urbano/src/features/routes/presentation/widgets/route_list_tile.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/fake_route_repository.dart';

RouteSummary _route() => const RouteSummary(
  id: '101 ANGOSTURA',
  shortName: '101 ANGOSTURA',
  longName: 'Micro 101 ANGOSTURA',
  color: '7F8C8D',
  textColor: 'FFFFFF',
  description: 'Transporte publico urbano de micros',
  type: 3,
  directionsCount: 2,
  stopCount: 84,
  tripCount: 2,
);

RouteDetail _detail() => RouteDetail(
  id: _route().id,
  shortName: _route().shortName,
  longName: _route().longName,
  color: _route().color,
  textColor: _route().textColor,
  description: _route().description,
  type: _route().type,
  directionsCount: _route().directionsCount,
  stopCount: _route().stopCount,
  tripCount: _route().tripCount,
  bbox: const [],
  directions: const [
    RouteDirection(
      directionId: 0,
      headsign: 'Plan 400',
      tripId: 't0',
      firstDeparture: '06:00:00',
      lastDeparture: '22:00:00',
      headwaySeconds: 600,
      stopCount: 20,
    ),
    RouteDirection(
      directionId: 1,
      headsign: 'Monseñor Rivero',
      tripId: 't1',
      firstDeparture: '06:00:00',
      lastDeparture: '22:00:00',
      headwaySeconds: 600,
      stopCount: 20,
    ),
  ],
  shape: const RouteShape(
    id: 'shape',
    points: [LatLng(-17.78, -63.18), LatLng(-17.80, -63.16)],
  ),
);

void main() {
  testWidgets(
    'el tap en un resultado del buscador abre el detalle sin tumbar el layout',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          routeRepositoryProvider.overrideWithValue(
            FakeRouteRepository(
              [_route()],
              details: {'101 ANGOSTURA': _detail()},
              stops: const [
                RouteStop(
                  id: 'S1',
                  name: 'Avenida Brasil esquina Calle Bolivia',
                  lat: -17.788,
                  lon: -63.161,
                  sequence: 1,
                ),
                RouteStop(
                  id: 'S2',
                  name: 'Cuarto Anillo esquina Radial 24',
                  lat: -17.799,
                  lon: -63.171,
                  sequence: 2,
                ),
              ],
            ),
          ),
          statsProvider.overrideWith(
            (ref) async => const Stats(
              routes: 154,
              stops: 31461,
              trips: 308,
              shapes: 130105,
              service: ServiceWindow(
                start: '2026-10-06',
                end: '2027-10-06',
                days: 'diario',
              ),
              firstDeparture: '06:00:00',
              lastDeparture: '22:00:00',
              headwaySeconds: 300,
            ),
          ),
          myLocationProvider.overrideWith((ref) async => const LatLng(0, 0)),
          routesListProvider.overrideWith(
            (ref, query) async => Paged<RouteSummary>(
              items: [_route()],
              meta: const Meta(total: 1),
            ),
          ),
          globalSearchProvider.overrideWith(
            (ref, query) async => GlobalSearchResult(
              routes: Paged<RouteSummary>(
                items: [_route()],
                meta: const Meta(total: 1),
              ),
            ),
          ),
          featuredRouteShapeProvider.overrideWith((ref) async => null),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.enterText(find.byType(TextField), 'angostura');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Micro 101 ANGOSTURA'), findsOneWidget);

      // Tap sobre la tarjeta del resultado: la navegación real del router va
      // con `push`, que en esta configuración interrumpe los frames — el detalle
      // se abre. Lock de regresión: el layout de la fila (con [PhotoShine] en
      // la vitrina) tiene que sobrevivir contexto de altura no acotada.
      await tester.tap(find.byType(RouteListTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Señal directa (no la URL del delegate: bajo `flutter test`, `push`
      // es asíncrono y el `uri` del delegate puede rezagarse; el detalle ya
      // montado es la verdad observable del usuario).
      expect(find.byType(RouteDetailScreen), findsOneWidget);
    },
  );
}
