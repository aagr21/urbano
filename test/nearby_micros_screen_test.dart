import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/map/map.dart';
import 'package:urbano/src/core/network/api_client.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/core/widgets/urbano_map.dart';
import 'package:urbano/src/features/home/data/stats.dart';
import 'package:urbano/src/features/home/presentation/home_providers.dart';
import 'package:urbano/src/features/journey/application/trip_history_controller.dart';
import 'package:urbano/src/features/journey/presentation/journey_markers.dart';
import 'package:urbano/src/features/nearby/domain/nearby_micros.dart';
import 'package:urbano/src/features/nearby/presentation/nearby_micros_screen.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/routes/presentation/route_providers.dart';
import 'package:urbano/src/features/stops/data/stop_search_models.dart';
import 'package:urbano/src/features/stops/data/stop_search_repository.dart';

import 'helpers/contrast.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/fake_route_repository.dart';
import 'helpers/memory_trip_history_store.dart';

/// Repositorio de paradas sin red que registra el radio pedido.
class _FakeStops implements StopSearchRepository {
  _FakeStops(this.hits);

  final List<StopHit> hits;
  final List<String> calls = [];

  @override
  Future<List<StopHit>> search(String q) async => hits;

  @override
  Future<List<StopHit>> nearby({
    required double lat,
    required double lon,
    int? radiusMeters,
    int limit = 30,
  }) async {
    calls.add('nearby r=$radiusMeters limit=$limit');
    return hits;
  }
}

RouteSummary _summary(String id, String color) => RouteSummary(
  id: id,
  shortName: id,
  longName: 'Línea $id · Centro',
  color: color,
  textColor: 'FFFFFF',
  description: '',
  type: 3,
  directionsCount: 2,
  stopCount: 30,
  tripCount: 2,
);

/// Recorrido de ~2,2 km: da varias flechas de sentido.
const _shape = RouteShape(
  id: 'shape-41',
  points: [
    LatLng(-17.770, -63.190),
    LatLng(-17.780, -63.184),
    LatLng(-17.790, -63.178),
  ],
);

const _plaza = NearbyQuery(
  lat: -17.7833,
  lon: -63.1821,
  label: 'Plaza 24 de Septiembre',
);

/// La 41 pasa por las dos aceras (ida en A, vuelta en B); la 60 solo de
/// vuelta, más lejos.
final _hits = [
  const StopHit(
    id: 'A',
    name: 'Calle Ayacucho',
    lat: -17.7836,
    lon: -63.1819,
    distanceMeters: 60,
    routes: [
      StopRouteRef(
        id: '41',
        shortName: '41',
        color: 'D35400',
        longName: 'Plan 3000 ↔ Centro',
        directionIds: [0],
      ),
    ],
  ),
  const StopHit(
    id: 'B',
    name: 'Calle Junín',
    lat: -17.7828,
    lon: -63.1826,
    distanceMeters: 140,
    routes: [
      StopRouteRef(
        id: '41',
        shortName: '41',
        color: 'D35400',
        directionIds: [1],
      ),
      StopRouteRef(
        id: '60',
        shortName: '60',
        color: '27AE60',
        directionIds: [1],
      ),
    ],
  ),
];

void main() {
  late _FakeStops stops;
  late FakeRouteRepository routes;

  Future<void> pumpApp(
    WidgetTester tester, {
    List<StopHit>? hits,
    String initial = '/',
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    stops = _FakeStops(hits ?? _hits);
    routes = FakeRouteRepository(
      [_summary('41', 'D35400'), _summary('60', '27AE60')],
      headsigns: ('Plan 3000', 'Centro'),
      shape: _shape,
    );
    final container = ProviderContainer(
      overrides: [
        stopSearchRepositoryProvider.overrideWithValue(stops),
        routeRepositoryProvider.overrideWithValue(routes),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        myLocationProvider.overrideWith(
          (ref) async => const LatLng(-17.7833, -63.1821),
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
        routesListProvider.overrideWith(
          (ref, query) async =>
              const Paged<RouteSummary>(items: [], meta: Meta(total: 0)),
        ),
        featuredRouteShapeProvider.overrideWith((ref) async => null),
        tripHistoryControllerProvider.overrideWith(
          () => TripHistoryController(MemoryTripHistoryStore()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    router.go(initial);
    await tester.pumpAndSettle();
  }

  /// Sube la hoja de resultados hasta arriba (a la altura inicial solo se
  /// construye la primera tarjeta: el mapa es el protagonista).
  Future<void> expandSheet(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const ValueKey('nearby-title')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
  }

  UrbanoMap nearbyMap(WidgetTester tester) =>
      tester.widget<UrbanoMap>(find.byKey(const ValueKey('nearby-map')));

  MapMarker? marker(WidgetTester tester, String id) =>
      nearbyMap(tester).markers.where((m) => m.id == id).firstOrNull;

  group('hoja de Lugares', () {
    testWidgets('elegir un lugar habilita «Buscar cerca» y abre la vista', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const ValueKey('home-tile-places')));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué micro pasa cerca?'), findsOneWidget);

      final submit = find.byKey(const ValueKey('nearby-submit'));
      expect(tester.widget<ButtonStyleButton>(submit).onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('nearby-poi-Plaza 24 de Septiembre')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<ButtonStyleButton>(submit).onPressed, isNotNull);

      // Radio de 1 km antes de buscar: viaja hasta el backend.
      await tester.tap(find.byKey(const ValueKey('nearby-sheet-radius-1000')));
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.byType(NearbyMicrosScreen), findsOneWidget);
      expect(find.text('2 líneas pasan cerca'), findsOneWidget);
      expect(stops.calls, contains('nearby r=1000 limit=50'));
    });

    testWidgets('«Mi ubicación» usa el GPS como punto', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('home-tile-places')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nearby-use-location')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('nearby-picked-Mi ubicación')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('nearby-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(NearbyMicrosScreen), findsOneWidget);
    });
  });

  group('vista Micros cerca', () {
    testWidgets('lista por cercanía, con Ida/Vuelta según lo que pasa', (
      tester,
    ) async {
      await pumpApp(tester, initial: UrbanoRoutes.nearby(_plaza));

      expect(find.text('2 líneas pasan cerca'), findsOneWidget);
      expect(find.text('Plaza 24 de Septiembre'), findsOneWidget);
      await expandSheet(tester);
      // La 41 (60 m) va antes que la 60 (140 m).
      final y41 = tester
          .getTopLeft(find.byKey(const ValueKey('nearby-micro-41')))
          .dy;
      final y60 = tester
          .getTopLeft(find.byKey(const ValueKey('nearby-micro-60')))
          .dy;
      expect(y41, lessThan(y60));

      // La 60 solo pasa de vuelta: su Ida queda apagada.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('nearby-dir-60-0')),
          matching: find.text('No pasa cerca'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('nearby-dir-41-1')),
          matching: find.text('a 140 m'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('elige sola la más cercana y la dibuja con flechas', (
      tester,
    ) async {
      await pumpApp(tester, initial: UrbanoRoutes.nearby(_plaza));

      expect(routes.detailCalls, contains('detail=41#0'));
      final map = nearbyMap(tester);
      // Recorrido en el color de la línea + zona punteada + tramo a pie.
      expect(
        map.polylines.where(
          (p) => p.color == const Color(0xFFD35400) && p.outline,
        ),
        hasLength(1),
      );
      expect(map.polylines.where((p) => p.dashed), hasLength(2));
      // Flechas de sentido sobre el recorrido, girando con el mapa.
      final arrows = map.markers
          .where((m) => m.id.startsWith('nearby-arrow-41-'))
          .toList();
      expect(arrows.length, greaterThanOrEqualTo(5));
      expect(arrows.every((m) => m.rotateWithMap), isTrue);
      expect(arrows.first.child, isA<RouteArrowMarker>());
      // Sube en la parada de ida (A), y el lugar está marcado.
      expect(
        marker(tester, 'nearby-boarding')!.point,
        const LatLng(-17.7836, -63.1819),
      );
      expect(marker(tester, 'nearby-place'), isNotNull);
      // El destino del sentido aparece en la tarjeta elegida.
      expect(find.text('Hacia Plan 3000'), findsOneWidget);
    });

    testWidgets('cambiar a Vuelta sube en la otra acera y cambia el destino', (
      tester,
    ) async {
      await pumpApp(tester, initial: UrbanoRoutes.nearby(_plaza));

      await tester.tap(find.byKey(const ValueKey('nearby-dir-41-1')));
      await tester.pumpAndSettle();

      expect(routes.detailCalls, contains('detail=41#1'));
      expect(
        marker(tester, 'nearby-boarding')!.point,
        const LatLng(-17.7828, -63.1826),
      );
      expect(find.text('Hacia Centro'), findsOneWidget);
    });

    testWidgets('tocar otra tarjeta la elige por su sentido cercano', (
      tester,
    ) async {
      await pumpApp(tester, initial: UrbanoRoutes.nearby(_plaza));
      await expandSheet(tester);

      await tester.tap(find.byKey(const ValueKey('nearby-micro-60')));
      await tester.pumpAndSettle();

      expect(routes.detailCalls, contains('detail=60#1'));
      expect(
        nearbyMap(tester).markers
            .any((m) => m.id.startsWith('nearby-arrow-60-')),
        isTrue,
      );
      expect(
        nearbyMap(tester).markers
            .any((m) => m.id.startsWith('nearby-arrow-41-')),
        isFalse,
      );
    });

    testWidgets('tema oscuro: Ida/Vuelta legibles elegidos y sin elegir', (
      tester,
    ) async {
      await pumpApp(tester, initial: UrbanoRoutes.nearby(_plaza), dark: true);

      void expectLegible(String key, String label) {
        final pill = find.byKey(ValueKey(key));
        final box = tester.widget<AnimatedContainer>(
          find.descendant(of: pill, matching: find.byType(AnimatedContainer)),
        );
        final fill = (box.decoration! as BoxDecoration).color!;
        final ink = tester
            .widget<Text>(find.descendant(of: pill, matching: find.text(label)))
            .style!
            .color!;
        expect(
          colorContrast(ink, fill),
          greaterThanOrEqualTo(4.5),
          reason: '$key: $ink sobre $fill',
        );
      }

      expectLegible('nearby-dir-41-0', 'Ida'); // elegida (relleno de línea)
      expectLegible('nearby-dir-41-1', 'Vuelta'); // sin elegir (tinte)
    });

    testWidgets('zona vacía: lo dice y amplía el radio', (tester) async {
      await pumpApp(
        tester,
        hits: const [],
        initial: UrbanoRoutes.nearby(_plaza),
      );

      expect(find.text('Ninguna línea a menos de 500 m'), findsOneWidget);
      await tester.tap(find.text('Ampliar a 1 km'));
      await tester.pumpAndSettle();

      expect(stops.calls.last, 'nearby r=1000 limit=50');
      expect(find.text('Ninguna línea a menos de 1 km'), findsOneWidget);
    });
  });
}
