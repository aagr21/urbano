import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/deep_link/incoming_link_source.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/journey/application/saved_trips_controller.dart';
import 'package:urbano/src/features/journey/application/trip_history_controller.dart';
import 'package:urbano/src/features/journey/data/saved_trips.dart';
import 'package:urbano/src/features/journey/presentation/widgets/incoming_destination_gate.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_plan_button.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/memory_trip_history_store.dart';

/// Buzón como el de Android: entrega el enlace una sola vez.
class _QueuedLinks implements IncomingLinkSource {
  _QueuedLinks(this._pending);

  String? _pending;

  @override
  Future<String?> takePending() async {
    final link = _pending;
    _pending = null;
    return link;
  }
}

class _MemorySavedTripsStore implements SavedTripsStore {
  List<SavedTrip> _trips = const [];

  @override
  Future<List<SavedTrip>> load() async => _trips;

  @override
  Future<void> save(List<SavedTrip> trips) async => _trips = trips;
}

class _FakeLastKnown extends LastKnownLocation {
  @override
  LatLng? build() => const LatLng(-17.7833, -63.1821);

  @override
  Future<void> refreshFromSystem() async {}
}

Future<void> _pumpApp(WidgetTester tester, String? link) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Inicio')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appRouterProvider.overrideWithValue(router),
        incomingLinkSourceProvider.overrideWithValue(_QueuedLinks(link)),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(initialPermission: LocationPermission.whileInUse),
        ),
        lastKnownLocationProvider.overrideWith(_FakeLastKnown.new),
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
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (_, child) => IncomingDestinationGate(child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _inputText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).controller?.text ?? '';

void main() {
  testWidgets('una ubicación de WhatsApp abre la hoja con el destino puesto', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      'geo:-17.7712,-63.1955?q=-17.7712,-63.1955(Ventura Mall)',
    );

    expect(_inputText(tester, 'journey-destination-input'), 'Ventura Mall');
    expect(_inputText(tester, 'journey-origin-input'), 'Mi ubicación');
    // Listo para un toque: origen (GPS) y destino resueltos.
    expect(
      tester.widget<JourneyPlanButton>(find.byType(JourneyPlanButton)).enabled,
      isTrue,
    );
  });

  testWidgets('volver a primer plano lee el enlace nuevo una sola vez', (
    tester,
  ) async {
    await _pumpApp(tester, null);
    expect(
      find.byKey(const ValueKey('journey-destination-input')),
      findsNothing,
    );

    // Ningún enlace pendiente: reanudar no abre nada.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('journey-destination-input')),
      findsNothing,
    );
  });

  testWidgets('fuera de Santa Cruz avisa y no abre la hoja', (tester) async {
    await _pumpApp(tester, 'geo:-16.5,-68.15');

    expect(
      find.byKey(const ValueKey('journey-destination-input')),
      findsNothing,
    );
    expect(find.textContaining('fuera de Santa Cruz'), findsOneWidget);
  });

  testWidgets('un texto sin ubicación avisa y no abre la hoja', (tester) async {
    await _pumpApp(tester, 'hola, ¿nos vemos mañana?');

    expect(
      find.byKey(const ValueKey('journey-destination-input')),
      findsNothing,
    );
    expect(find.textContaining('No encontré una ubicación'), findsOneWidget);
  });
}
