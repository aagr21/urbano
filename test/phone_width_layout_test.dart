import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/journey/presentation/journey_planner_screen.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';
import 'package:urbano/src/features/journey/presentation/map_picker_screen.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';

/// Regresión de layout a ancho real de móvil (393×851 lógicos).
///
/// A los 800px por defecto de flutter_test las tarjetas de opción caben y un
/// desbordamiento pasa desapercibido; a ancho de móvil la fila horaria de
/// [JourneyOptionCard] desbordaba 53px (franjas amarillas). Este test fija el
/// viewport al teléfono y planifica un viaje, de modo que cualquier overflow
/// lanza excepción y rompe la prueba.
void main() {
  Future<void> pumpPlanner(WidgetTester tester) async {
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
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('planner-trigger')));
    await tester.pumpAndSettle();
  }

  /// Marca un punto en el mapa como origen/destino (mismo flujo que el
  /// usuario: hoja de selección → "Punto en el mapa" → confirmar).
  Future<void> pickPoint(
    WidgetTester tester,
    String hint, {
    required LatLng point,
  }) async {
    await tester.tap(find.text(hint));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punto en el mapa'));
    await tester.pumpAndSettle();
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

  testWidgets('el panel arranca cerrado y se abre con la píldora', (
    tester,
  ) async {
    await pumpPlanner(tester);

    // Cerrado por defecto: los campos no están y el mapa manda.
    expect(
      find.text('Marca un punto en el mapa o usa tu ubicación'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('planner-trigger')), findsOneWidget);

    await openPanel(tester);

    // Abierto: aparecen los campos origen/destino y el botón planificar.
    expect(
      find.text('Marca un punto en el mapa o usa tu ubicación'),
      findsOneWidget,
    );
    expect(find.text('Viajar'), findsOneWidget);
  });

  testWidgets('la "X" bajo la tarjeta cierra el panel de origen/destino', (
    tester,
  ) async {
    await pumpPlanner(tester);
    await openPanel(tester);

    // Con el panel abierto aparece el cerrador centrado debajo de la tarjeta.
    final close = find.byKey(const ValueKey('planner-close'));
    expect(close, findsOneWidget);

    // Está CENTRADO horizontalmente y DEBAJO del botón "Viajar" de la tarjeta.
    final closeRect = tester.getRect(close);
    final cardRect = tester.getRect(find.text('Viajar'));
    expect(
      closeRect.center.dx,
      closeTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
        12,
      ),
      reason: 'el cerrador debe quedar en el centro horizontal',
    );
    expect(
      closeRect.top,
      greaterThanOrEqualTo(cardRect.bottom),
      reason: 'el cerrador cuelga debajo de la tarjeta',
    );

    // Tocarlo repliega el panel: desaparecen los campos y el propio cerrador.
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(close, findsNothing);
    expect(
      find.text('Marca un punto en el mapa o usa tu ubicación'),
      findsNothing,
    );
    // La píldora sigue ahí para volver a abrir.
    expect(find.byKey(const ValueKey('planner-trigger')), findsOneWidget);
  });

  testWidgets('no desborda a ancho de móvil en exploración', (tester) async {
    await pumpPlanner(tester);
    expect(find.byType(JourneyPlannerScreen), findsOneWidget);
  });

  testWidgets('con el panel abierto los controles del mapa no lo tapan', (
    tester,
  ) async {
    await pumpPlanner(tester);
    await openPanel(tester);

    // Botón de zoom (el primer control de la columna derecha).
    final zoom = tester.getRect(find.byTooltip('Acercar'));
    // Tarjeta del panel con origen/destino: ocupa la franja alta.
    final panelBottom = tester.getRect(find.text('Viajar')).bottom;

    expect(
      zoom.top,
      greaterThanOrEqualTo(panelBottom),
      reason: 'el control de zoom no debe solaparse con el panel desplegado',
    );
  });

  testWidgets('abrir el panel NO mueve los controles del mapa (quedan abajo)', (
    tester,
  ) async {
    await pumpPlanner(tester);

    // Sin resultados: los controles viajan anclados abajo, tanto con el panel
    // cerrado (píldora visible) como abierto (campos visibles).
    expect(find.byKey(const ValueKey('planner-trigger')), findsOneWidget);
    final closed = tester.getRect(find.byTooltip('Acercar'));

    await openPanel(tester);
    final opened = tester.getRect(find.byTooltip('Acercar'));

    expect(
      opened,
      closed,
      reason:
          'los botones de zoom/ubicación/micros no deben subir al desplegar '
          'el panel de origen/destino',
    );
  });

  testWidgets('no desborda a ancho de móvil en resultados', (tester) async {
    await pumpPlanner(tester);

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
