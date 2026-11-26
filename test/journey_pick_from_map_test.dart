import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/journey/application/journey_planner_controller.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';
import 'package:urbano/src/features/journey/presentation/map_picker_screen.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';
import 'helpers/plan_trip.dart';

/// Regresión del selector de punto en el mapa (hoy se abre tocando el pin de
/// origen/destino en `/journey`: la pantalla ya no tiene panel de campos).
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
  const origin = LatLng(-17.79, -63.17);
  const destination = LatLng(-17.80, -63.15);

  // Viewport por defecto (800 px): el recálculo muestra «Recalculando…» y,
  // medido con Ahem (~1,8× Inter), desbordaría la fila de chips a ancho de
  // teléfono de forma artificial.
  Future<ProviderContainer> pumpTrip(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        myLocationProvider.overrideWith(
          (ref) async => const LatLng(-17.7833, -63.1821),
        ),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        journeyProvider.overrideWith(
          (ref, query) async => [fixtureDirectOption()],
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
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    router.go('/journey');
    await tester.pumpAndSettle();
    await planTripFromHome(
      tester,
      container,
      origin: origin,
      destination: destination,
    );
    return container;
  }

  FakeMapEngineState plannerEngine(WidgetTester tester) =>
      tester.state<FakeMapEngineState>(find.byType(FakeMapEngine).first);

  FakeMapEngineState pickerEngine(WidgetTester tester) =>
      tester.state<FakeMapEngineState>(
        find.descendant(
          of: find.byType(MapPickerScreen),
          matching: find.byType(FakeMapEngine),
        ),
      );

  Future<void> tapPin(WidgetTester tester, String id) async {
    plannerEngine(tester).debugFireMarkerTap(id);
    await tester.pumpAndSettle();
  }

  testWidgets('tocar el pin de origen abre el selector en ese punto y con '
      'su título', (tester) async {
    await pumpTrip(tester);
    await tapPin(tester, 'journey-map-origin');

    final picker = tester.widget<MapPickerScreen>(find.byType(MapPickerScreen));
    expect(picker.title, 'Origen');
    expect(picker.initial, (lat: origin.latitude, lon: origin.longitude));
  });

  testWidgets('el destino también abre el selector con su título', (
    tester,
  ) async {
    await pumpTrip(tester);
    await tapPin(tester, 'journey-map-destination');

    final picker = tester.widget<MapPickerScreen>(find.byType(MapPickerScreen));
    expect(picker.title, 'Destino');
    expect(picker.initial, (
      lat: destination.latitude,
      lon: destination.longitude,
    ));
  });

  testWidgets('confirmar en el selector mueve el extremo al punto marcado', (
    tester,
  ) async {
    final container = await pumpTrip(tester);
    await tapPin(tester, 'journey-map-origin');

    pickerEngine(tester).moveCamera(const LatLng(-17.77, -63.16), 15);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar este punto'));
    await tester.pumpAndSettle();

    expect(find.byType(MapPickerScreen), findsNothing);
    final picked = container.read(journeyPlannerControllerProvider).origin;
    expect(picked?.pointOrNull, (lat: -17.77, lon: -63.16));
  });
}
