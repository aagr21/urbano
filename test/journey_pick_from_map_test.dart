import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/journey/presentation/map_picker_screen.dart';

import 'helpers/fake_location_service.dart';

/// Regresión del botón "Elegir en el mapa" de los campos origen/destino.
///
/// Un fallo real hacía que el punto elegido "saliera en otra ubicación" al
/// planificar: la URL se construía como
/// `'/journey/pick?${Uri(queryParameters: ...)}'`, y
/// `Uri(queryParameters: ...)` YA empieza por `?`: resultaba
/// `/journey/pick??title=Origen&lat=...`. El router leía la primera clave
/// como `?title`, así que el selector perdía el título (y el punto inicial).
///
/// Los tests montan el GoRouter REAL para que la URL construida por la
/// pantalla se parsee de verdad.
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

  /// Icono del mapa del campo indicado (los dos campos origen/destino lo
  /// muestran; el orden del panel es origen, destino).
  Future<void> openMapPicker(WidgetTester tester, {required int field}) async {
    await tester.tap(find.byTooltip('Elegir en el mapa').at(field));
    await tester.pumpAndSettle();
  }

  FakeMapEngineState pickerEngine(WidgetTester tester) =>
      tester.state<FakeMapEngineState>(
        find.descendant(
          of: find.byType(MapPickerScreen),
          matching: find.byType(FakeMapEngine),
        ),
      );

  testWidgets(
    'elegir "Punto en el mapa" abre el selector con su título y confirma '
    'el punto marcado',
    (tester) async {
      await pumpApp(tester);
      await openPanel(tester);

      // Flujo del campo: tap en el hint → hoja → "Punto en el mapa".
      await tester.tap(
        find.text('Marca un punto en el mapa o usa tu ubicación'),
      );
      await tester.pumpAndSettle();
      expect(find.text('¿De dónde sales?'), findsOneWidget);
      await tester.tap(find.text('Punto en el mapa'));
      await tester.pumpAndSettle();

      // Mover el mapa (pin fijo al centro) y confirmar.
      pickerEngine(tester).moveCamera(const LatLng(-17.79, -63.17), 15);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este punto'));
      await tester.pumpAndSettle();

      expect(find.byType(MapPickerScreen), findsNothing);
      expect(
        find.text('Punto en el mapa · -17.79000, -63.17000'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'un punto marcado a mano reabre el selector en ese punto y con el '
    'título',
    (tester) async {
      await pumpApp(tester);
      await openPanel(tester);

      // Marca un punto a mano: mueve el mapa por debajo del pin y confirma.
      await openMapPicker(tester, field: 0);
      pickerEngine(tester).moveCamera(const LatLng(-17.79, -63.17), 15);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este punto'));
      await tester.pumpAndSettle();

      // Reabrir: el selector conserva el punto elegido (y su título).
      await openMapPicker(tester, field: 0);

      final picker = tester.widget<MapPickerScreen>(
        find.byType(MapPickerScreen),
      );
      expect(picker.title, 'Origen');
      expect(picker.initial, const (lat: -17.79, lon: -63.17));
    },
  );

  testWidgets('el destino también abre el selector con su título', (
    tester,
  ) async {
    await pumpApp(tester);
    await openPanel(tester);

    await openMapPicker(tester, field: 1);

    final picker = tester.widget<MapPickerScreen>(find.byType(MapPickerScreen));
    expect(picker.title, 'Destino');
    // Sin punto aún: el selector abre en la ubicación del usuario.
    expect(picker.initial, isNull);
  });
}
