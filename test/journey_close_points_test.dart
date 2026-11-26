import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/journey/data/journey_models.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';
import 'helpers/plan_trip.dart';

/// Origen y destino en el MISMO sitio (o casi): no hay viaje de bus posible.
///
/// Regresión real del reporte: al arrastrar los puntos hasta casi el mismo
/// lugar, el backend seguía devolviendo opciones "sube en S_X / baja en S_Y"
/// con las paradas a ~100 m (un viaje de una parada a la de al lado) y el
/// resultado mostraba origen y destino en la misma ubicación.
///
/// Defensa: el backend responde `[]` sin tocar la base (umbral 150 m) y la
/// hoja explica que están muy cerca (aquí se simula el guard del backend en
/// el override). La guarda del cliente vivía en el panel de origen/destino
/// de `/journey`, que se retiró: el viaje se arma en la portada.
void main() {
  group('resultado vacío tras arrastrar los puntos juntos', () {
    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
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
      return container;
    }

    testWidgets(
      'la hoja explica que están muy cerca en vez de devolver un viaje de '
      'punto a punto pegados',
      (tester) async {
        final container = await pumpApp(tester);
        await planTripFromHome(
          tester,
          container,
          origin: const LatLng(-17.78, -63.15),
          destination: const LatLng(-17.80, -63.17),
        );

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
