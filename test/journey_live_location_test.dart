import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/location/location_controller.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
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

/// Fix "fino" que NUNCA llega: es lo que pasa de verdad cuando el GPS tarda
/// en fijar (frío, interiores, el móvil venía de dormir).
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

/// Centro de la cámara del motor (fake) — prueba de que la APP la mueve.
LatLng _engineCameraCenter(WidgetTester tester) =>
    tester.state<FakeMapEngineState>(find.byType(FakeMapEngine)).camera.center;

Future<ProviderContainer> _pumpLayer(
  WidgetTester tester, {
  required FakeLocationService service,
  ThemeData? theme,
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
        theme: theme ?? AppTheme.light(),
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
    'GPS de un solo dueño: con seguimiento el stream propio mueve el punto y '
    'la CÁMARA de la app; al soltar, el punto sale de la caché del sistema '
    '(regresiones: la ubicación desaparecía unos segundos y el puck nativo '
    'de MapLibre pedía su propio GPS sin control nuestro)',
    (tester) async {
      final service = _SlowFixLocationService()
        ..cachedPosition = _SlowFixLocationService.cached;
      final container = await _pumpLayer(tester, service: service);

      // El fix fino nunca llega, así que antes de activar el seguimiento no
      // hay posición: el punto todavía no existe.
      expect(_lastKnownMarker(tester), isNull);

      // Seguimiento activo: el stream propio emite un nuevo punto.
      container.read(followLocationProvider.notifier).state = true;
      await tester.pumpAndSettle();
      service.emitPosition(const LatLng(-17.68, -63.08));
      await tester.pumpAndSettle();

      // El tick del stream mueve el punto propio (no hay puck nativo: la
      // posición pintada SIEMPRE es la del dueño propio).
      final liveMarker = _lastKnownMarker(tester);
      expect(
        liveMarker,
        isNotNull,
        reason: 'con seguimiento el punto propio es EL punto',
      );
      expect(liveMarker!.point, const LatLng(-17.68, -63.08));

      // La cámara la mueve LA APP con cada tick (follow propio, no nativo).
      expect(
        _engineCameraCenter(tester),
        const LatLng(-17.68, -63.08),
        reason:
            'la cámara camina con el usuario: cada tick recentra a su punto',
      );

      // Soltar el seguimiento (gesto/botón) NUNCA borra el punto: sale de la
      // caché del sistema sin esperar el fix nuevo.
      service.lastKnownCalls = 0;
      container.read(followLocationProvider.notifier).state = false;
      await tester.pumpAndSettle();

      expect(
        service.lastKnownCalls,
        greaterThan(0),
        reason: 'soltar el seguimiento debe leer la caché (instantánea)',
      );
      expect(
        _lastKnownMarker(tester)!.point,
        _SlowFixLocationService.cached,
        reason: 'el punto no puede desaparecer esperando el fix nuevo',
      );
    },
  );

  testWidgets(
    'un pan del usuario suelta el seguimiento: el tick siguiente NO devuelve '
    'la cámara a «mi ubicación» (regresión: volvía sola y con zoom)',
    (tester) async {
      final service = FakeLocationService(
        initialPermission: LocationPermission.whileInUse,
      );
      final container = await _pumpLayer(tester, service: service);

      container.read(followLocationProvider.notifier).state = true;
      await tester.pumpAndSettle();
      service.emitPosition(const LatLng(-17.68, -63.08));
      await tester.pumpAndSettle();
      expect(_engineCameraCenter(tester), const LatLng(-17.68, -63.08));

      // El usuario arrastra el mapa a la nada, lejos de su ubicación.
      const nowhere = LatLng(-17.60, -63.30);
      tester
          .state<FakeMapEngineState>(find.byType(FakeMapEngine))
          .debugFireCameraGesture(nowhere, zoom: 12);
      await tester.pump();
      expect(
        container.read(followLocationProvider),
        isFalse,
        reason: 'un gesto del usuario suelta el seguimiento',
      );

      // Aunque llegue un tick nuevo, la cámara se queda donde la dejó el dedo
      // (antes volvía sola al GPS y de paso saltaba a zoom de calle).
      service.emitPosition(const LatLng(-17.681, -63.079));
      await tester.pumpAndSettle();
      expect(_engineCameraCenter(tester), nowhere);
    },
  );

  testWidgets(
    'tocar el mapa suelta el seguimiento (señal temprana: no depende de que '
    'el motor acierte con `hasGesture`)',
    (tester) async {
      final service = FakeLocationService(
        initialPermission: LocationPermission.whileInUse,
      );
      final container = await _pumpLayer(tester, service: service);
      container.read(followLocationProvider.notifier).state = true;
      await tester.pumpAndSettle();
      expect(container.read(followLocationProvider), isTrue);

      // Lejos del punto propio: un toque cualquiera sobre el mapa.
      await tester.tapAt(const Offset(120, 160));
      await tester.pump();

      expect(
        container.read(followLocationProvider),
        isFalse,
        reason: 'el mapa es del dedo en cuanto se toca',
      );
    },
  );

  testWidgets(
    'sin seguimiento NO se abre el sensor; con él se abre UNA vez y se suelta al '
    'ir a segundo plano (regresión: la escucha era permanente y el teléfono se '
    'calentaba)',
    (tester) async {
      final service = FakeLocationService(
        initialPermission: LocationPermission.whileInUse,
      );
      final container = await _pumpLayer(tester, service: service);

      // El planeador está montado desde el arranque (el shell no desmonta la
      // pestaña Viaje) y el permiso está concedido: aun así, sin intención de
      // seguimiento no se llama al plugin NI un solo vez.
      expect(service.positionStreamCalls, 0);
      expect(service.positionEvents.hasListener, isFalse);

      container.read(followLocationProvider.notifier).state = true;
      await tester.pumpAndSettle();
      expect(
        service.positionStreamCalls,
        1,
        reason: 'la demanda abre la escucha, una vez',
      );
      expect(service.positionEvents.hasListener, isTrue);

      // Segundo plano: nadie mira el mapa → se LIBERA el listener del GPS.
      // Se recorre la secuencia REAL del sistema (`resumed → inactive → hidden
      // → paused`): `AppLifecycleListener` asserts si se salta un estado.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(container.read(locationDemandProvider), isFalse);
      expect(
        service.positionEvents.hasListener,
        isFalse,
        reason: 'en segundo plano el sensor no sigue escuchando',
      );

      // De vuelta, con la intención todavía puesta: se reabre (una vez más, no
      // dos streams simultáneos).
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(service.positionStreamCalls, 2);
      expect(service.positionEvents.hasListener, isTrue);

      // Soltar el seguimiento lo apaga y no vuelve "por si acaso".
      container.read(followLocationProvider.notifier).state = false;
      await tester.pumpAndSettle();
      expect(service.positionEvents.hasListener, isFalse);
      expect(service.positionStreamCalls, 2);
    },
  );

  testWidgets(
    'con seguimiento la cámara se mueve SOLO con desplazamiento real: 3 m de '
    'ruido del GNSS no despiertan el mapa (móvil quieto = menos CPU y menos calor)',
    (tester) async {
      final service = FakeLocationService(
        initialPermission: LocationPermission.whileInUse,
      );
      final container = await _pumpLayer(tester, service: service);
      container.read(followLocationProvider.notifier).state = true;
      await tester.pumpAndSettle();

      const here = LatLng(-17.68, -63.08);
      service.emitPosition(here);
      await tester.pumpAndSettle();
      expect(_engineCameraCenter(tester), here);

      // 3 m al norte: jitter típico con el dispositivo parado.
      service.emitPosition(LatLng(here.latitude + 0.000027, here.longitude));
      await tester.pumpAndSettle();
      expect(
        _engineCameraCenter(tester),
        here,
        reason: 'por debajo de gpsMinMovementMeters no se mueve la cámara',
      );
      expect(
        _lastKnownMarker(tester)!.point,
        here,
        reason: 'ni siquiera se reconstruye el punto pintado',
      );

      // 12 m: desplazamiento de verdad → la cámara camina con el usuario.
      const moved = LatLng(-17.679892, -63.08);
      service.emitPosition(moved);
      await tester.pumpAndSettle();
      expect(_engineCameraCenter(tester), moved);

      expect(container.read(locationDemandProvider), isTrue);
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
    service.emitPosition(const LatLng(-17.68, -63.08));
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

  testWidgets(
    'el punto de «mi ubicación» lleva anillo SIEMPRE blanco y relleno '
    'del primario (también de noche)',
    (tester) async {
      final service = FakeLocationService(
        initialPermission: LocationPermission.whileInUse,
      );
      await _pumpLayer(tester, service: service, theme: AppTheme.dark());

      final marker = _lastKnownMarker(tester);
      expect(marker, isNotNull);

      final dot = marker!.child as DecoratedBox;
      final decoration = dot.decoration as BoxDecoration;
      final ring = decoration.border! as Border;
      final primary = AppTheme.dark().colorScheme.primary;
      expect(
        ring.top.color,
        Colors.white,
        reason:
            'el punto se pinta sobre el MAPA, no sobre una superficie de la '
            'app: con `colors.surface` el borde salía negro en modo oscuro',
      );
      expect(
        decoration.color,
        primary,
        reason: 'el punto GPS es del primario de la app, como su botón',
      );

      final map = tester.widget<JourneyResultMap>(
        find.byType(JourneyResultMap),
      );
      expect(
        map.extraPulses.single.color,
        primary,
        reason:
            'el aura es del mismo color: punto y halo son un solo «estás aquí»',
      );
    },
  );
}
