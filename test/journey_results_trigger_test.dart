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
import 'package:urbano/src/features/journey/presentation/widgets/journey_planner_card.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_result_map.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_results_sheet.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';

/// El globo `planner-trigger` (la píldora que abre el panel de origen y
/// destino) solo existe SIN resultados: con la hoja de resultados en pantalla
/// el mapa queda libre para leer la ruta, y el viaje se edita desde los pines
/// o con «Quitar resultados». Contrato completo en
/// `specs/003-hide-results-trigger/contracts/ui-planner-trigger.md`.
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

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(trigger));
    await tester.pumpAndSettle();
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

  /// Marca un punto en el mapa como origen/destino desde el panel.
  Future<void> pickPoint(
    WidgetTester tester,
    String hint, {
    required LatLng point,
  }) async {
    await tester.tap(find.text(hint));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punto en el mapa'));
    await tester.pumpAndSettle();
    await confirmPickerAt(tester, point);
  }

  /// Planifica un viaje completo con el globo (la única entrada sin
  /// resultados) y deja la hoja de resultados en pantalla.
  Future<void> planTrip(WidgetTester tester) async {
    await openPanel(tester);
    await pickPoint(
      tester,
      'Marca un punto en el mapa o usa tu ubicación',
      point: const LatLng(-17.78, -63.15),
    );
    await pickPoint(
      tester,
      'Marca dónde quieres llegar',
      point: const LatLng(-17.80, -63.17),
    );
    await tester.tap(find.text('Viajar'));
    await tester.pumpAndSettle();
  }

  FakeMapEngineState plannerEngine(WidgetTester tester) =>
      tester.state<FakeMapEngineState>(find.byType(FakeMapEngine));

  group('con resultados (US1)', () {
    testWidgets('con resultados no hay globo y la ruta sigue trazada', (
      tester,
    ) async {
      await pumpPlanner(tester);
      await planTrip(tester);

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
      await planTrip(tester);
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
      await pumpPlanner(tester, phone: false);
      await planTrip(tester);

      plannerEngine(tester).debugFireMarkerTap('journey-map-destination');
      await tester.pumpAndSettle();
      expect(find.byType(MapPickerScreen), findsOneWidget);

      await confirmPickerAt(tester, const LatLng(-17.81, -63.18));

      expect(find.byType(MapPickerScreen), findsNothing);
      expect(find.byType(JourneyResultsSheet), findsOneWidget);
      expect(find.byKey(trigger), findsNothing);
    });

    testWidgets('arrastrar el origen recalcula sin globo', (tester) async {
      await pumpPlanner(tester, phone: false);
      await planTrip(tester);

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

    testWidgets(
      'con resultados el panel abierto desde el home se cierra con la '
      'X',
      (tester) async {
        final container = await pumpPlanner(tester);
        await planTrip(tester);
        expect(find.byType(JourneyPlannerCard), findsNothing);

        // Acceso «Viajes» del home: abre el panel aunque haya resultados.
        container.read(pendingPlannerPanelProvider.notifier).state = true;
        await tester.pumpAndSettle();
        expect(find.byType(JourneyPlannerCard), findsOneWidget);
        expect(find.byKey(trigger), findsNothing);

        await tester.tap(find.byKey(const ValueKey('planner-close')));
        await tester.pumpAndSettle();
        expect(find.byType(JourneyPlannerCard), findsNothing);
        expect(find.byType(JourneyResultsSheet), findsOneWidget);
      },
    );

    testWidgets('quitar los resultados devuelve el globo', (tester) async {
      await pumpPlanner(tester);
      await planTrip(tester);
      expect(find.byKey(trigger), findsNothing);

      await tester.tap(find.byTooltip('Quitar resultados'));
      await tester.pumpAndSettle();

      expect(find.byType(JourneyResultsSheet), findsNothing);
      expect(find.byKey(trigger), findsOneWidget);
    });
  });

  group('sin resultados (US3)', () {
    testWidgets('sin viaje el globo está y abre el panel', (tester) async {
      await pumpPlanner(tester);

      expect(find.byKey(trigger), findsOneWidget);
      expect(find.text('¿A dónde vas?'), findsOneWidget);

      await openPanel(tester);
      expect(find.byType(JourneyPlannerCard), findsOneWidget);
    });

    testWidgets('con un solo extremo el globo invita a completar', (
      tester,
    ) async {
      await pumpPlanner(tester);
      await openPanel(tester);
      await pickPoint(
        tester,
        'Marca un punto en el mapa o usa tu ubicación',
        point: const LatLng(-17.78, -63.15),
      );
      await tester.tap(find.byKey(const ValueKey('planner-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(trigger), findsOneWidget);
      expect(find.text('Toca para completar el viaje'), findsOneWidget);
    });
  });
}
