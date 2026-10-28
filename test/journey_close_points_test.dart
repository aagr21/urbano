import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/journey/data/journey_models.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';
import 'package:urbano/src/features/journey/presentation/map_picker_screen.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';

/// Origen y destino en el MISMO sitio (o casi): no hay viaje de bus posible.
///
/// Regresión real del reporte: al arrastrar los puntos hasta casi el mismo
/// lugar, el backend seguía devolviendo opciones "sube en S_X / baja en S_Y"
/// con las paradas a ~100 m (un viaje de una parada a la de al lado) y el
/// resultado mostraba origen y destino en la misma ubicación.
///
/// Ahora hay dos defensas coordinadas (mismo umbral 150 m en ambos lados):
/// - el cliente no envía la consulta y avisa con un snack;
/// - el backend responde `[]` sin tocar la base y la hoja explica que están
///   muy cerca (aquí se simula el guard del backend en el override).
void main() {
  group('guarda de envío (mismo punto)', () {
    Future<void> pumpApp(
      WidgetTester tester,
      List<Override> extraOverrides,
    ) async {
      final container = ProviderContainer(overrides: extraOverrides);
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
      'planificar con el MISMO punto en origen y destino avisa con un '
      'snack y NO consulta el backend',
      (tester) async {
        final calls = <Object>[];
        await pumpApp(tester, [
          myLocationProvider.overrideWith(
            (ref) async => const LatLng(-17.7833, -63.1821),
          ),
          journeyProvider.overrideWith((ref, query) async {
            calls.add(query);
            return [fixtureDirectOption()];
          }),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
        ]);

        await tester.tap(find.byKey(const ValueKey('planner-trigger')));
        await tester.pumpAndSettle();

        // Origen marcado en el mapa.
        await tester.tap(find.byTooltip('Elegir en el mapa').at(0));
        await tester.pumpAndSettle();
        tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .moveCamera(const LatLng(-17.78, -63.15), 15);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Usar este punto'));
        await tester.pumpAndSettle();

        // Destino: EXACTAMENTE el mismo punto.
        await tester.tap(find.byTooltip('Elegir en el mapa').at(1));
        await tester.pumpAndSettle();
        tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .moveCamera(const LatLng(-17.78, -63.15), 15);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Usar este punto'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Viajar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          find.textContaining('mismo punto'),
          findsOneWidget,
          reason: 'debe avisar de que origen y destino son el mismo sitio',
        );
        expect(
          calls,
          isEmpty,
          reason: 'no debe consultar el backend con origen == destino',
        );
        expect(find.textContaining('38 min'), findsNothing);
      },
    );
  });

  group('resultado vacío tras arrastrar los puntos juntos', () {
    Future<void> pumpApp(WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          myLocationProvider.overrideWith(
            (ref) async => const LatLng(-17.7833, -63.1821),
          ),
          // Espejo del guard del backend (MIN_TRANSIT_DISTANCE_M = 150).
          journeyProvider.overrideWith((ref, query) async {
            final origin = query.originPoint;
            final destination = query.destinationPoint;
            final meters = const Distance().as(
              LengthUnit.Meter,
              LatLng(origin.lat, origin.lon),
              LatLng(destination.lat, destination.lon),
            );
            return meters >= 150
                ? [fixtureDirectOption()]
                : const <JourneyOption>[];
          }),
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

    testWidgets(
      'la hoja explica que están muy cerca en vez de devolver un viaje de '
      'punto a punto pegados',
      (tester) async {
        await pumpApp(tester);

        await tester.tap(find.byKey(const ValueKey('planner-trigger')));
        await tester.pumpAndSettle();
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

        // Con los extremos a ~3 km sí hay viaje.
        expect(find.textContaining('38 min'), findsWidgets);

        // Drop de origen… sin esperar los 600 ms del debounce…
        tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .debugFireMarkerDrag(
              'journey-map-origin',
              const LatLng(-17.8005, -63.1704),
            );
        await tester.pump();

        // …y drop de destino en la MISMA ventana: los DOS se aplican y los
        // extremos quedan a ~55 m (el usuario los arrastró juntos).
        tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .debugFireMarkerDrag(
              'journey-map-destination',
              const LatLng(-17.8001, -63.1701),
            );
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        expect(
          find.text('Están muy cerca'),
          findsOneWidget,
          reason: 'el estado vacío debe nombrar el problema real',
        );
        expect(
          find.textContaining('camina hasta allí'),
          findsOneWidget,
          reason: 'debe orientar: caminar en vez de inventar un viaje',
        );
        expect(
          find.textContaining('38 min'),
          findsNothing,
          reason: 'no debe seguir ahí un viaje calculado con puntos lejanos',
        );
      },
    );
  });
}
