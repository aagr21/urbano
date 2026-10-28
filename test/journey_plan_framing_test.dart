import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/map/map_projection.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';

/// Encuadre del viaje tras planificar: los puntos marcados deben quedar en
/// el MAPA VISIBLE, no tapados por la hoja de resultados.
///
/// Regresión real: el encuadre reservaba un fondo FIJO de 260 px, pero la
/// hoja `DraggableScrollableSheet` cubre el 45% de la altura del mapa (≈352 px
/// en un móvil) y hasta el 85% si se arrastra. En un viaje largo el destino
/// se proyectaba DETRÁS de la hoja (medido: y≈523 vs hoja en y≈431): el
/// usuario veía el punto marcado tapado por la hoja de resultados.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        myLocationProvider.overrideWith(
          (ref) async => const LatLng(-17.7833, -63.1821),
        ),
        journeyProvider.overrideWith(
          (ref, query) async => [fixtureDirectOption()],
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
  }

  testWidgets(
    'tras planificar, origen y destino proyectados quedan ARRIBA de la '
    'hoja de resultados (regresión: el destino quedaba tapado)',
    (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const ValueKey('planner-trigger')));
      await tester.pumpAndSettle();

      // Origen marcado al norte con el selector del mapa.
      await tester.tap(find.byTooltip('Elegir en el mapa').at(0));
      await tester.pumpAndSettle();
      const origin = LatLng(-17.7600, -63.1821);
      tester
          .state<FakeMapEngineState>(find.byType(FakeMapEngine))
          .moveCamera(origin, 15);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este punto'));
      await tester.pumpAndSettle();

      // Destino marcado al sur (viaje largo de ~5 km).
      await tester.tap(find.byTooltip('Elegir en el mapa').at(1));
      await tester.pumpAndSettle();
      const destination = LatLng(-17.8000, -63.1500);
      tester
          .state<FakeMapEngineState>(find.byType(FakeMapEngine))
          .moveCamera(destination, 15);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este punto'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Viajar'));
      await tester.pumpAndSettle();

      final engine = tester.state<FakeMapEngineState>(
        find.byType(FakeMapEngine),
      );
      final camera = engine.camera;
      final viewport =
          engine.viewportSize ?? tester.getSize(find.byType(MaterialApp));

      // La hoja de resultados cubre el porcentaje inferior del MISMO contenedor
      // lleno que el mapa: su línea superior es donde empieza lo tapado.
      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      final sheetTop = viewport.height * (1 - sheet.initialChildSize);

      Offset project(LatLng point) => MapProjection.project(
        point,
        center: camera.center,
        zoom: camera.zoom,
        viewport: viewport,
      );

      final originScreen = project(origin);
      final destinationScreen = project(destination);

      // Con la reserva fija de 260 px el destino caía en y≈523 (hoja en
      // y≈431); con la reserva real de la hoja debe quedar por encima.
      expect(
        originScreen.dy,
        lessThan(sheetTop),
        reason: 'el origen marcado queda tras la hoja de resultados',
      );
      expect(
        destinationScreen.dy,
        lessThan(sheetTop),
        reason: 'el destino marcado queda tras la hoja de resultados',
      );
      expect(originScreen.dy, greaterThanOrEqualTo(0));
      expect(destinationScreen.dy, greaterThanOrEqualTo(0));
    },
  );
}
