import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/location/place_search.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/journey/application/saved_trips_controller.dart';
import 'package:urbano/src/features/journey/application/trip_history_controller.dart';
import 'package:urbano/src/features/journey/data/saved_trips.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_destination_sheet.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_plan_button.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/fake_place_search_service.dart';
import 'helpers/memory_trip_history_store.dart';

class _MemorySavedTripsStore implements SavedTripsStore {
  _MemorySavedTripsStore();
  List<SavedTrip> _trips = const [];

  @override
  Future<List<SavedTrip>> load() async => _trips;

  @override
  Future<void> save(List<SavedTrip> trips) async => _trips = trips;
}

class _FakeLastKnown extends LastKnownLocation {
  _FakeLastKnown(this._value);

  final LatLng? _value;

  @override
  LatLng? build() => _value;

  @override
  Future<void> refreshFromSystem() async {}
}

class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => showJourneyDestinationSheet(
            context: context,
            ref: ref,
            initialOrigin: null,
            initialDestination: null,
          ),
          child: const Text('Abrir'),
        ),
      ),
    );
  }
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  PlaceSearchService? places,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (places != null)
          placeSearchServiceProvider.overrideWithValue(places),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(initialPermission: LocationPermission.whileInUse),
        ),
        lastKnownLocationProvider.overrideWith(
          () => _FakeLastKnown(const LatLng(-17.7833, -63.1821)),
        ),
        myLocationProvider.overrideWith(
          (ref) async => const LatLng(-17.7833, -63.1821),
        ),
        tripHistoryControllerProvider.overrideWith(
          () => TripHistoryController(MemoryTripHistoryStore([])),
        ),
        savedTripsControllerProvider.overrideWith(
          () => SavedTripsController(_MemorySavedTripsStore()),
        ),
      ],
      // GoRouter real con el MISMO shell de ramas que la app (Inicio y un
      // `/journey` de mentira): la hoja vive en el navegador de la rama
      // Inicio, que sigue montada al cambiar a Viaje.
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: GoRouter(
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (_, _, shell) => shell,
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(path: '/', builder: (_, _) => const _Harness()),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/journey',
                      builder: (context, _) => Scaffold(
                        body: TextButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Volver a Inicio'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

/// Texto que hoy muestra el campo (el valor real del input, no la pista).
String _inputText(WidgetTester tester, String key) {
  final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
  return field.controller?.text ?? '';
}

void main() {
  group('JourneyDestinationSheet · campos editables', () {
    testWidgets('el origen arranca en «Mi ubicación» con píldora GPS', (
      tester,
    ) async {
      await _pumpSheet(tester);

      expect(_inputText(tester, 'journey-origin-input'), 'Mi ubicación');
      expect(find.text('GPS'), findsOneWidget);
      expect(find.textContaining('-17.'), findsNothing);
    });

    testWidgets('escribir en el destino sugiere hitos y elegir uno lo fija', (
      tester,
    ) async {
      await _pumpSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('journey-destination-input')),
        'plaza',
      );
      await tester.pumpAndSettle();

      // Sugerencias de lugares populares debajo del campo.
      expect(find.text('Plaza 24 de Septiembre'), findsOneWidget);
      expect(find.text('Elegir en el mapa'), findsOneWidget);

      await tester.ensureVisible(find.text('Plaza 24 de Septiembre'));
      await tester.tap(find.text('Plaza 24 de Septiembre'));
      await tester.pumpAndSettle();

      expect(
        _inputText(tester, 'journey-destination-input'),
        'Plaza 24 de Septiembre',
      );
      // Al elegir, la lista de sugerencias se cierra.
      expect(find.text('Elegir en el mapa'), findsNothing);
    });

    testWidgets('planificar cierra la hoja y abre Viaje (regresión: la hoja '
        'quedaba abierta y reaparecía al volver a Inicio)', (tester) async {
      await _pumpSheet(tester);

      // Ventura Mall queda a ~3,4 km de «Mi ubicación» (la plaza principal).
      await tester.enterText(
        find.byKey(const ValueKey('journey-destination-input')),
        'ventura',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ventura Mall'));
      await tester.tap(find.text('Ventura Mall'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(JourneyPlanButton));
      await tester.tap(find.byType(JourneyPlanButton));
      await tester.pumpAndSettle();

      expect(find.text('Volver a Inicio'), findsOneWidget);

      // De vuelta en la portada la hoja ya no está esperando.
      await tester.tap(find.text('Volver a Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir'), findsOneWidget);
      expect(find.byType(JourneyPlanButton), findsNothing);
    });

    testWidgets('con destino en el mismo punto que el origen no se planifica '
        'y el campo dice por qué', (tester) async {
      await _pumpSheet(tester);

      // La Plaza 24 de Septiembre está EXACTAMENTE en «Mi ubicación».
      await tester.enterText(
        find.byKey(const ValueKey('journey-destination-input')),
        'plaza',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Plaza 24 de Septiembre'));
      await tester.tap(find.text('Plaza 24 de Septiembre'));
      await tester.pumpAndSettle();

      expect(
        find.text('Es el mismo punto que el origen: elige otro destino'),
        findsOneWidget,
      );
      final button = tester.widget<JourneyPlanButton>(
        find.byType(JourneyPlanButton),
      );
      expect(button.enabled, isFalse);
      expect(button.onPressed, isNull);

      // Tocarlo igual no navega: la hoja sigue abierta.
      await tester.ensureVisible(find.byType(JourneyPlanButton));
      await tester.tap(find.byType(JourneyPlanButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Volver a Inicio'), findsNothing);
      expect(find.byType(JourneyPlanButton), findsOneWidget);
    });

    testWidgets('escribir en el origen quita el GPS y se puede recuperar', (
      tester,
    ) async {
      await _pumpSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('journey-origin-input')),
        'ventura',
      );
      await tester.pumpAndSettle();

      // Lo escrito reemplaza al origen GPS: la píldora GPS desaparece.
      expect(find.text('GPS'), findsNothing);
      expect(find.text('Ventura Mall'), findsOneWidget);

      await tester.ensureVisible(find.text('Mi ubicación').first);
      await tester.tap(find.text('Mi ubicación').first);
      await tester.pumpAndSettle();

      expect(_inputText(tester, 'journey-origin-input'), 'Mi ubicación');
      expect(find.text('GPS'), findsOneWidget);
    });

    testWidgets('sin destino el CTA está apagado y escribir no lo enciende', (
      tester,
    ) async {
      await _pumpSheet(tester);

      final button = tester.widget<JourneyPlanButton>(
        find.byType(JourneyPlanButton),
      );
      expect(button.enabled, isFalse);

      await tester.enterText(
        find.byKey(const ValueKey('journey-destination-input')),
        'plaza',
      );
      await tester.pumpAndSettle();

      final stillDisabled = tester.widget<JourneyPlanButton>(
        find.byType(JourneyPlanButton),
      );
      expect(
        stillDisabled.enabled,
        isFalse,
        reason: 'escribir no basta: hay que fijar un lugar concreto',
      );
    });

    testWidgets('sugiere calles de OSM y elegir una fija el destino', (
      tester,
    ) async {
      final places = FakePlaceSearchService(santaCruzSuggestions);
      await _pumpSheet(tester, places: places);

      await tester.enterText(
        find.byKey(const ValueKey('journey-destination-input')),
        'monseñor',
      );
      await tester.pumpAndSettle();

      final row = find.byKey(
        const ValueKey('place-suggestion-Avenida Monseñor Rivero'),
      );
      expect(row, findsOneWidget);
      expect(find.text('Centro'), findsOneWidget);
      expect(find.text(osmAttribution), findsOneWidget);
      expect(places.queries, ['monseñor']);

      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        _inputText(tester, 'journey-destination-input'),
        'Avenida Monseñor Rivero',
      );
      expect(find.text(osmAttribution), findsNothing);
    });

    testWidgets('un lugar popular no se repite entre las sugerencias de OSM', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        places: FakePlaceSearchService(santaCruzSuggestions),
      );
      await tester.enterText(
        find.byKey(const ValueKey('journey-destination-input')),
        'plaza 24',
      );
      await tester.pumpAndSettle();
      expect(find.text('Plaza 24 de Septiembre'), findsOneWidget);
    });

    testWidgets('Enter sin lugar popular toma la primera calle de OSM', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        places: FakePlaceSearchService(santaCruzSuggestions),
      );
      final input = find.byKey(const ValueKey('journey-destination-input'));
      await tester.enterText(input, 'ventura');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_inputText(tester, 'journey-destination-input'), 'Ventura Mall');
    });

    testWidgets('con menos de 3 letras no consulta OSM', (tester) async {
      final places = FakePlaceSearchService(santaCruzSuggestions);
      await _pumpSheet(tester, places: places);
      await tester.enterText(
        find.byKey(const ValueKey('journey-destination-input')),
        'av',
      );
      await tester.pumpAndSettle();
      expect(places.queries, isEmpty);
    });
  });
}
