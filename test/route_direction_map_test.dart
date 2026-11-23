import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/routes/presentation/route_providers.dart';
import 'package:urbano/src/features/routes/presentation/widgets/micro_bus_art.dart';
import 'package:urbano/src/features/routes/presentation/widgets/route_map_chrome.dart';

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

/// Abre el detalle de la línea falsa con el router real de la app.
Future<ProviderContainer> _pumpDetail(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      routeRepositoryProvider.overrideWithValue(
        FakeRouteRepository([_route()]),
      ),
      // Overpass no se toca en tests: la sección de calles recibe datos fijos.
      routeStreetsProvider.overrideWith(
        (ref, key) async => const [
          'Av. Monseñor Rivero',
          'Av. Cristo Redentor',
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(appRouterProvider);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  router.go(UrbanoRoutes.routeDetail('101 ANGOSTURA'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return container;
}

void main() {
  testWidgets(
    'el detalle tiene un solo control de sentido y muestra las calles',
    (tester) async {
      await _pumpDetail(tester);

      // Una única cápsula con las dos pestañas: nada de botones por sentido ni
      // chip «Ida y vuelta» repitiendo la misma decisión.
      expect(
        find.byKey(const ValueKey('route-direction-tab-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('route-direction-tab-1')),
        findsOneWidget,
      );
      expect(find.text('Ver ruta de ida'), findsNothing);
      expect(find.text('Ver ruta de vuelta'), findsNothing);
      expect(find.text('Ida y vuelta'), findsNothing);

      // «Por dónde pasa» vive más abajo en el scroll del detalle.
      await tester.scrollUntilVisible(
        find.text('Por dónde pasa'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Por dónde pasa'), findsOneWidget);
      expect(find.text('Av. Monseñor Rivero'), findsOneWidget);
      expect(find.text('Av. Cristo Redentor'), findsOneWidget);
    },
  );

  testWidgets('«Recorrido completo» abre el mapa del sentido 0 sin header', (
    tester,
  ) async {
    final container = await _pumpDetail(tester);
    final router = container.read(appRouterProvider);

    await tester.tap(find.text('Recorrido completo'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/routes/101%20ANGOSTURA/map');
    expect(router.state.uri.queryParameters['direction'], '0');
    // Sin AppBar: la flecha de vuelta flota sobre el trazado.
    expect(find.byType(AppBar), findsNothing);
    // La placa flotante conserva el nombre y el micro ilustrado de la línea.
    expect(find.byType(RouteMapPlate), findsOneWidget);
    expect(find.byType(MicroBusArt), findsOneWidget);
    expect(find.text('Micro 101 ANGOSTURA'), findsOneWidget);
    expect(find.text('Ida'), findsOneWidget);

    // La flecha vuelve al detalle, no a Inicio.
    await tester.tap(find.byTooltip('Volver').last);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/routes/101%20ANGOSTURA');
    expect(find.text('Recorrido completo'), findsOneWidget);
  });

  testWidgets('el mapa a sangre cabe en un móvil angosto', (tester) async {
    // 320 lógicos: la placa flotante (micro + numeral + sentido + nombre)
    // tiene que partirse o elidirse, nunca desbordar.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpDetail(tester);
    expect(tester.takeException(), isNull, reason: 'detalle a 320');
    await tester.tap(find.text('Recorrido completo'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(RouteMapPlate), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('cambiar a vuelta abre el mapa del sentido 1', (tester) async {
    final container = await _pumpDetail(tester);
    final router = container.read(appRouterProvider);

    await tester.tap(find.byKey(const ValueKey('route-direction-tab-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recorrido completo'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/routes/101%20ANGOSTURA/map');
    expect(router.state.uri.queryParameters['direction'], '1');
    // La placa del mapa a sangre rotula el sentido activo.
    expect(find.text('Vuelta'), findsOneWidget);
    // El detalle del sentido pedido se cargó de verdad.
    expect(
      (container.read(routeRepositoryProvider) as FakeRouteRepository)
          .detailCalls
          .where((call) => call.endsWith('#1')),
      isNotEmpty,
    );
  });
}
