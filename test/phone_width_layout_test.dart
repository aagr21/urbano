import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/journey/presentation/journey_planner_screen.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';
import 'helpers/plan_trip.dart';

/// Regresión de layout a ancho real de móvil (393×851 lógicos).
///
/// A los 800px por defecto de flutter_test las tarjetas de opción caben y un
/// desbordamiento pasa desapercibido; a ancho de móvil la fila horaria de
/// [JourneyOptionCard] desbordaba 53px (franjas amarillas). Este test fija el
/// viewport al teléfono y planifica un viaje, de modo que cualquier overflow
/// lanza excepción y rompe la prueba.
void main() {
  Future<ProviderContainer> pumpPlanner(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        myLocationProvider.overrideWith(
          (ref) async => const LatLng(-17.7833, -63.1821),
        ),
        journeyProvider.overrideWith(
          (ref, query) async => [
            fixtureDirectOption(),
            fixtureTransferOption(),
          ],
        ),
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
    router.go('/journey');
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Viaje no tiene globo «¿A dónde vas?» ni panel de '
      'origen/destino', (tester) async {
    await pumpPlanner(tester);

    // El viaje se arma en la portada: aquí solo mandan el mapa y sus
    // controles.
    expect(find.byKey(const ValueKey('planner-trigger')), findsNothing);
    expect(find.text('¿A dónde vas?'), findsNothing);
    expect(find.text('Viajar'), findsNothing);
    expect(
      find.text('Marca un punto en el mapa o usa tu ubicación'),
      findsNothing,
    );
    expect(find.byTooltip('Acercar'), findsOneWidget);
  });

  testWidgets('no desborda a ancho de móvil en exploración', (tester) async {
    await pumpPlanner(tester);
    expect(find.byType(JourneyPlannerScreen), findsOneWidget);
  });

  testWidgets('no desborda a ancho de móvil en resultados', (tester) async {
    final container = await pumpPlanner(tester);
    await planTripFromHome(
      tester,
      container,
      origin: const LatLng(-17.78, -63.15),
      destination: const LatLng(-17.80, -63.17),
    );
    expect(find.text('¿A dónde vas?'), findsNothing);

    // Las tarjetas de opción deben existir y caber sin overflow (que lanzaría).
    expect(find.textContaining('38 min'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('55 min'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('55 min'), findsWidgets);
  });
}
