import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';

import 'helpers/fake_location_service.dart';

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

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('planner-trigger')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'seleccionar un hito popular de Santa Cruz rellena el campo con su nombre',
    (tester) async {
      await pumpApp(tester);
      await openPanel(tester);

      // Tap en el campo origen
      await tester.tap(
        find.text('Marca un punto en el mapa o usa tu ubicación'),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿De dónde sales?'), findsOneWidget);
      expect(find.text('Lugares de Santa Cruz'), findsOneWidget);
      expect(find.text('El Cristo Redentor'), findsOneWidget);

      // Seleccionar El Cristo
      await tester.tap(find.text('El Cristo Redentor'));
      await tester.pumpAndSettle();

      // El campo origen ahora muestra el nombre del hito
      expect(find.text('El Cristo Redentor'), findsWidgets);
    },
  );

  testWidgets('el buscador de hitos filtra por nombre en tiempo real', (
    tester,
  ) async {
    await pumpApp(tester);
    await openPanel(tester);

    // Tap en el campo destino
    await tester.tap(find.text('Marca dónde quieres llegar'));
    await tester.pumpAndSettle();

    expect(find.text('¿A dónde vas?'), findsWidgets);

    // Buscar "Ventura"
    await tester.enterText(find.byType(TextField), 'Ventura');
    await tester.pumpAndSettle();

    expect(find.text('Ventura Mall'), findsOneWidget);
    expect(find.text('Terminal Bimodal'), findsNothing);

    // Elegir Ventura Mall
    await tester.tap(find.text('Ventura Mall'));
    await tester.pumpAndSettle();

    expect(find.text('Ventura Mall'), findsWidgets);
  });
}
