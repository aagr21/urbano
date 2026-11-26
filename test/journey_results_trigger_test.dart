import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/journey/application/journey_planner_controller.dart';
import 'package:urbano/src/features/journey/data/journey_models.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';
import 'package:urbano/src/features/journey/presentation/map_picker_screen.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_loading_overlay.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_result_map.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_results_sheet.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';
import 'helpers/plan_trip.dart';

/// Viaje (`/journey`) NO tiene el globo `planner-trigger` («¿A dónde vas?» /
/// «Origen → Destino») ni el panel de origen/destino: ni sin viaje, ni
/// calculando, ni con resultados. El viaje se arma en la portada y aquí se
/// edita tocando o arrastrando los pines; «Quitar resultados» vuelve a Inicio.
void main() {
  const trigger = ValueKey('planner-trigger');

  /// Monta `/journey` con el viaje de fixtures. Por defecto a ancho de
  /// teléfono; los tests que recalculan usan `phone: false` (viewport de
  /// 800 px, como `journey_result_map_test.dart`) porque bajo `flutter test`
  /// el texto se mide con Ahem (~1,8× Inter) y el chip «Recalculando…»
  /// desbordaría la fila de chips de forma artificial.
  Future<ProviderContainer> pumpPlanner(
    WidgetTester tester, {
    bool phone = true,
    Future<List<JourneyOption>> Function()? journey,
  }) async {
    if (phone) {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
    }

    final container = ProviderContainer(
      overrides: [
        myLocationProvider.overrideWith(
          (ref) async => const LatLng(-17.7833, -63.1821),
        ),
        journeyProvider.overrideWith(
          (ref, query) =>
              journey?.call() ??
              Future.value([fixtureDirectOption(), fixtureTransferOption()]),
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

  /// Mueve la cámara del selector de punto y confirma (mismo flujo que el
  /// usuario: el pin fijo queda donde se ve).
  Future<void> confirmPickerAt(WidgetTester tester, LatLng point) async {
    tester
        .state<FakeMapEngineState>(
          find.descendant(
            of: find.byType(MapPickerScreen),
            matching: find.byType(FakeMapEngine),
          ),
        )
        .moveCamera(point, 15);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar este punto'));
    await tester.pumpAndSettle();
  }

  /// Planifica como la portada («¿A dónde vas?» → Planificar viaje).
  Future<void> planTrip(WidgetTester tester, ProviderContainer container) =>
      planTripFromHome(
        tester,
        container,
        origin: const LatLng(-17.78, -63.15),
        destination: const LatLng(-17.80, -63.17),
      );

  FakeMapEngineState plannerEngine(WidgetTester tester) =>
      tester.state<FakeMapEngineState>(find.byType(FakeMapEngine));

  group('con resultados (US1)', () {
    testWidgets('con resultados no hay globo y la ruta sigue trazada', (
      tester,
    ) async {
      final container = await pumpPlanner(tester);
      await planTrip(tester, container);

      expect(find.byType(JourneyResultsSheet), findsOneWidget);
      expect(find.byKey(trigger), findsNothing);
      // La ruta de la opción seleccionada sigue dibujada en el mapa.
      expect(find.byType(JourneyResultMap), findsOneWidget);
      expect(
        tester
            .widget<JourneyResultMap>(find.byType(JourneyResultMap))
            .option
            .legs,
        isNotEmpty,
      );
    });

    testWidgets('cambiar de opción o mover la hoja no trae el globo', (
      tester,
    ) async {
      final container = await pumpPlanner(tester);
      await planTrip(tester, container);
      final before = tester
          .widget<JourneyResultMap>(find.byType(JourneyResultMap))
          .option;

      // Misma acción que dispara tocar la segunda tarjeta de la hoja.
      container.read(journeyPlannerControllerProvider.notifier).selectOption(1);
      await tester.pumpAndSettle();

      expect(find.byKey(trigger), findsNothing);
      final after = tester
          .widget<JourneyResultMap>(find.byType(JourneyResultMap))
          .option;
      expect(identical(after, before), isFalse);

      // Bajar la hoja deja más mapa a la vista, pero el globo no vuelve.
      await tester.drag(find.byType(JourneyResultsSheet), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.byType(JourneyResultsSheet), findsOneWidget);
      expect(find.byKey(trigger), findsNothing);
    });
  });

  group('editar el viaje sin el globo (US2)', () {
    testWidgets('tocar el pin de destino abre el selector y no trae el globo', (
      tester,
    ) async {
      final container = await pumpPlanner(tester, phone: false);
      await planTrip(tester, container);

      plannerEngine(tester).debugFireMarkerTap('journey-map-destination');
      await tester.pumpAndSettle();
      expect(find.byType(MapPickerScreen), findsOneWidget);

      await confirmPickerAt(tester, const LatLng(-17.81, -63.18));

      expect(find.byType(MapPickerScreen), findsNothing);
      expect(find.byType(JourneyResultsSheet), findsOneWidget);
      expect(find.byKey(trigger), findsNothing);
    });

    testWidgets('arrastrar el origen recalcula sin globo', (tester) async {
      final container = await pumpPlanner(tester, phone: false);
      await planTrip(tester, container);

      plannerEngine(
        tester,
      ).debugFireMarkerDrag('journey-map-origin', const LatLng(-17.77, -63.14));
      // Durante la ventana del debounce y el recálculo el globo no aparece.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(trigger), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(JourneyResultsSheet), findsOneWidget);
      expect(find.byKey(trigger), findsNothing);
    });

    testWidgets('mientras se calcula el primer viaje no hay globo', (
      tester,
    ) async {
      final pending = Completer<List<JourneyOption>>();
      final container = await pumpPlanner(
        tester,
        journey: () => pending.future,
      );
      await planTrip(tester, container);

      // Todavía sin opciones: la carga es la protagonista y el globo
      // «Origen → Destino» no asoma encima.
      expect(find.byType(JourneyLoadingOverlay), findsOneWidget);
      expect(find.byKey(trigger), findsNothing);

      pending.complete([fixtureDirectOption()]);
      await tester.pumpAndSettle();
      expect(find.byType(JourneyResultsSheet), findsOneWidget);
      expect(find.byKey(trigger), findsNothing);
    });

    testWidgets('si el primer viaje falla, la carga se va y lo dice (sin '
        'globo)', (tester) async {
      final container = await pumpPlanner(
        tester,
        journey: () => Future.error(Exception('sin red')),
      );
      await planTrip(tester, container);

      expect(find.byType(JourneyLoadingOverlay), findsNothing);
      expect(find.byKey(trigger), findsNothing);
      expect(
        find.textContaining('No pudimos calcular el viaje'),
        findsOneWidget,
      );
    });

    testWidgets('la hoja no se cierra del todo y recogida se reabre con un '
        'toque', (tester) async {
      final container = await pumpPlanner(tester);
      await planTrip(tester, container);
      const grip = ValueKey('journey-sheet-grip');
      expect(find.byKey(const ValueKey('grip-open')), findsOneWidget);

      // Arrastre largo hacia abajo desde la cabecera: cae al mínimo, no fuera.
      await tester.drag(find.byKey(grip), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.byType(JourneyResultsSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('grip-collapsed')), findsOneWidget);
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getRect(find.byKey(grip)).bottom, lessThan(size.height));
      expect(find.byKey(trigger), findsNothing);

      await tester.tap(find.byKey(grip));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('grip-open')), findsOneWidget);
    });

    testWidgets('quitar los resultados vuelve a Inicio, sin globo', (
      tester,
    ) async {
      final container = await pumpPlanner(tester);
      await planTrip(tester, container);

      await tester.tap(find.byTooltip('Quitar resultados'));
      await tester.pumpAndSettle();

      final router = container.read(appRouterProvider);
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      expect(container.read(journeyPlannerControllerProvider).submitted, false);
      expect(find.byKey(trigger), findsNothing);
    });
  });

  group('sin viaje (US3)', () {
    testWidgets('Viaje no tiene globo «¿A dónde vas?» ni panel', (
      tester,
    ) async {
      await pumpPlanner(tester);

      expect(find.byKey(trigger), findsNothing);
      expect(find.text('¿A dónde vas?'), findsNothing);
      expect(find.text('Viajar'), findsNothing);
      expect(find.byType(JourneyResultMap), findsOneWidget);
    });
  });
}
