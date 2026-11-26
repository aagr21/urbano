import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/location/place_search.dart';
import 'package:urbano/src/features/journey/application/endpoint_submit.dart';
import 'package:urbano/src/features/journey/application/journey_place_factory.dart';
import 'package:urbano/src/features/journey/application/journey_planner_controller.dart';
import 'package:urbano/src/features/journey/application/recent_destinations.dart';
import 'package:urbano/src/features/journey/application/saved_trips_controller.dart';
import 'package:urbano/src/features/journey/application/trip_history_controller.dart';
import 'package:urbano/src/features/journey/application/trip_launcher.dart';
import 'package:urbano/src/features/journey/data/popular_places.dart';
import 'package:urbano/src/features/journey/data/saved_trips.dart';
import 'package:urbano/src/features/journey/data/trip_history.dart';
import 'package:urbano/src/features/journey/domain/journey_place.dart';

import 'helpers/memory_trip_history_store.dart';

class _MemorySavedTripsStore implements SavedTripsStore {
  List<SavedTrip> trips = const [];

  @override
  Future<List<SavedTrip>> load() async => trips;

  @override
  Future<void> save(List<SavedTrip> value) async => trips = value;
}

/// Piezas puras y casos de uso que salieron de la hoja «¿A dónde vas?».
void main() {
  const poi = SantaCruzPoi(
    name: 'Ventura Mall',
    category: 'Centro comercial',
    lat: -17.76,
    lon: -63.19,
    icon: Icons.store_rounded,
  );
  const hit = PlaceSuggestion(
    name: 'Calle Libertad',
    lat: -17.78,
    lon: -63.18,
    kind: PlaceKind.street,
  );

  group('resolveEndpointSubmit (Enter en un campo)', () {
    test('un hito popular gana a todo', () {
      final r = resolveEndpointSubmit(
        popular: const [poi],
        wantsGps: true,
        firstOnline: hit,
      );
      expect(r, isA<SubmitPoi>());
    });

    test('sin hito, «Mi ubicación» gana a OSM', () {
      expect(
        resolveEndpointSubmit(
          popular: const [],
          wantsGps: true,
          firstOnline: hit,
        ),
        isA<SubmitGps>(),
      );
    });

    test('sin hito ni GPS, la primera calle de OSM', () {
      final r = resolveEndpointSubmit(
        popular: const [],
        wantsGps: false,
        firstOnline: hit,
      );
      expect((r as SubmitSuggestion).hit, same(hit));
    });

    test('sin nada, no elige', () {
      expect(
        resolveEndpointSubmit(
          popular: const [],
          wantsGps: false,
          firstOnline: null,
        ),
        isA<SubmitNothing>(),
      );
    });
  });

  group('JourneyPlaceFactory', () {
    test('un hito sin zona usa su categoría como contexto', () {
      expect(JourneyPlaceFactory.fromPoi(poi).subtitle, 'Centro comercial');
    });

    test('una calle de OSM lleva su tipo como contexto', () {
      expect(JourneyPlaceFactory.fromSuggestion(hit).subtitle, 'Calle');
    });

    test('un viaje guardado da origen «ubicación» y destino hito', () {
      final trip = SavedTrip(
        originLabel: 'Casa',
        originLat: 1,
        originLon: 2,
        destinationLabel: 'Ventura Mall',
        destinationSubtitle: 'Equipetrol',
        destinationLat: 3,
        destinationLon: 4,
        lastUsed: DateTime(2026),
      );
      final origin = JourneyPlaceFactory.originOf(trip);
      final destination = JourneyPlaceFactory.destinationOf(trip);
      expect(origin.address, 'Casa');
      expect(destination.pointOrNull, (lat: 3.0, lon: 4.0));
      expect(destination.subtitle, 'Equipetrol');
    });
  });

  group('popular places', () {
    test('sin texto: búsqueda = catálogo entero, sugerencias = ninguna', () {
      expect(searchPopularPlaces(' '), kSantaCruzPopularPlaces);
      expect(matchPopularPlaces(' '), isEmpty);
    });

    test('las sugerencias se cortan al tope', () {
      expect(
        matchPopularPlaces('a').length,
        lessThanOrEqualTo(maxPopularSuggestions),
      );
    });

    test('busca por nombre sin distinguir mayúsculas', () {
      final name = kSantaCruzPopularPlaces.first.name;
      expect(
        searchPopularPlaces(name.toUpperCase()),
        contains(kSantaCruzPopularPlaces.first),
      );
    });
  });

  group('recientes', () {
    SavedTrip trip(double lat, DateTime at) => SavedTrip(
      originLabel: 'o',
      originLat: 0,
      originLon: 0,
      destinationLabel: 'd$lat',
      destinationSubtitle: null,
      destinationLat: lat,
      destinationLon: 0,
      lastUsed: at,
    );
    TripHistoryEntry entry(double lat, DateTime at) =>
        TripHistoryEntry(label: 'h$lat', lat: lat, lon: 0, lastUsed: at);

    test(
      'un destino por punto; el viaje guardado gana; más reciente arriba',
      () {
        final items = buildUnifiedRecentList(
          savedTrips: [trip(1, DateTime(2026, 1, 2))],
          history: [
            entry(1.00001, DateTime(2026, 1, 9)), // mismo punto (4 decimales)
            entry(2, DateTime(2026, 1, 5)),
          ],
        );
        expect(items, hasLength(2));
        expect(items.first, isA<RecentDestinationHistoryEntry>());
        expect(items.last, isA<RecentDestinationSavedTrip>());
      },
    );

    test('pageOf recorta y acota una página fuera de rango', () {
      final list = List.generate(7, (i) => i);
      expect(pageOf(list, page: 1, pageSize: 5).items, [5, 6]);
      final past = pageOf(list, page: 9, pageSize: 5);
      expect(past.page, 1);
      expect(past.items, [5, 6]);
      expect(pageOf(<int>[], page: 0, pageSize: 5).totalPages, 0);
    });
  });

  group('TripLauncher', () {
    test('planifica y anota el viaje en guardados e historial', () async {
      final saved = _MemorySavedTripsStore();
      final container = ProviderContainer(
        overrides: [
          savedTripsControllerProvider.overrideWith(
            () => SavedTripsController(saved),
          ),
          tripHistoryControllerProvider.overrideWith(
            () => TripHistoryController(MemoryTripHistoryStore([])),
          ),
        ],
      );
      addTearDown(container.dispose);
      const origin = JourneyPlaceLocation(lat: -17.78, lon: -63.18);
      const destination = JourneyPlacePoi(
        name: 'Ventura Mall',
        lat: -17.76,
        lon: -63.19,
      );

      await container
          .read(tripLauncherProvider)
          .launch(origin: origin, destination: destination);

      final planner = container.read(journeyPlannerControllerProvider);
      expect(planner.submitted, isTrue);
      expect(planner.origin, same(origin));
      expect(planner.destination, same(destination));
      expect(saved.trips, hasLength(1));
      final history = await container.read(
        tripHistoryControllerProvider.future,
      );
      expect(history.single.label, 'Ventura Mall');
    });
  });
}
