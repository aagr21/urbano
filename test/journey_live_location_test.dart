import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/location/location_controller.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/map/map.dart';
import 'package:urbano/src/core/map/map_tile.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/theme/map_theme_controller.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_live_map.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_result_map.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';

/// Store en memoria: `flutter test` no toca plugins.
class _MemoryMapThemeStore implements MapThemeStore {
  @override
  Future<MapTile?> load() async => null;

  @override
  Future<void> save(MapTile? tile) async {}
}

/// Fix "fino" que NUNCA llega: es lo que pasa de verdad al soltar el
/// seguimiento, el GPS tarda segundos en fijar otra vez.
class _SlowFixLocationService extends FakeLocationService {
  _SlowFixLocationService()
    : super(initialPermission: LocationPermission.whileInUse);

  static const cached = LatLng(-17.70, -63.10);

  final _fix = Completer<LatLng>();

  @override
  Future<LatLng> currentPosition() => _fix.future;
}

/// Id del punto Dart de «mi ubicación» (ver `LiveMapLayer`).
const _lastMarkerId = 'my-location-last';

MapMarker? _lastKnownMarker(WidgetTester tester) {
  final map = tester.widget<JourneyResultMap>(find.byType(JourneyResultMap));
  for (final marker in map.extraMarkers) {
    if (marker.id == _lastMarkerId) return marker;
  }
  return null;
}

Future<ProviderContainer> _pumpLayer(
  WidgetTester tester, {
  required FakeLocationService service,
}) async {
  final container = ProviderContainer(
    overrides: [
      locationServiceProvider.overrideWithValue(service),
      mapThemeStoreProvider.overrideWithValue(_MemoryMapThemeStore()),
      mapThemeControllerProvider.overrideWith(
        () => MapThemeController.preloaded(null),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LiveMapLayer(
            mapKey: GlobalKey<JourneyResultMapState>(),
            option: fixtureDirectOption(),
            origin: null,
            destination: null,
            hasResults: false,
            fitPadding: EdgeInsets.zero,
            extraPolylines: const [],
            extraMarkers: const [],
            onEndpointMoved: (_, _) {},
            onEndpointTapped: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'al soltar el seguimiento el punto sale de la caché del sistema, sin '
    'esperar el fix nuevo (regresión: tu ubicación desaparecía unos segundos)',
    (tester) async {
      final service = _SlowFixLocationService()
        ..cachedPosition = _SlowFixLocationService.cached;
      final container = await _pumpLayer(tester, service: service);

      // Seguimiento activo: manda el puck nativo y el punto Dart no se dibuja.
      container.read(followLocationProvider.notifier).state = true;
      await tester.pumpAndSettle();
      expect(_lastKnownMarker(tester), isNull);

      // El usuario mueve el mapa: se suelta el seguimiento.
      service.lastKnownCalls = 0;
      container.read(followLocationProvider.notifier).state = false;
      await tester.pumpAndSettle();

      expect(
        service.lastKnownCalls,
        greaterThan(0),
        reason: 'soltar el seguimiento debe leer la caché (instantánea)',
      );
      final marker = _lastKnownMarker(tester);
      expect(
        marker,
        isNotNull,
        reason: 'el punto no puede desaparecer esperando el fix nuevo',
      );
      expect(marker!.point, _SlowFixLocationService.cached);
    },
  );

  testWidgets('sin caché del sistema se conserva la última posición conocida', (
    tester,
  ) async {
    final service = FakeLocationService(
      initialPermission: LocationPermission.whileInUse,
    )..cachedPosition = null;
    final container = await _pumpLayer(tester, service: service);

    final before = _lastKnownMarker(tester);
    expect(before, isNotNull, reason: 'sembrado por la lectura puntual');

    // Se sigue y se suelta de nuevo, pero el sistema no tiene caché.
    container.read(followLocationProvider.notifier).state = true;
    await tester.pumpAndSettle();
    container.read(followLocationProvider.notifier).state = false;
    await tester.pumpAndSettle();

    final after = _lastKnownMarker(tester);
    expect(
      after,
      isNotNull,
      reason: 'mejor la última posición que ningún punto',
    );
    expect(after!.point, before!.point);
  });
}
