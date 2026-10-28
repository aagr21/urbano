import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:urbano/src/core/location/location_controller.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/location/startup_location_gate.dart';

import 'helpers/fake_location_service.dart';

void main() {
  group('StartupLocationGate', () {
    late FakeLocationService fake;

    setUp(() {
      fake = FakeLocationService();
      StartupLocationGate.debugReset();
    });

    Widget host() => UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(fake)],
      ),
      child: const StartupLocationGate(
        child: SizedBox(key: ValueKey('gate-child')),
      ),
    );

    /// Deja que el post-frame del gate y los microtasks del controller
    /// (checkPermission/requestPermission) terminen de resolver.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
      'permiso pendiente + GPS encendido → pide, concede y activa follow',
      (tester) async {
        // GPS encendido, permiso aún no concedido: el gate debe lanzar el
        // diálogo nativo y, al concederlo, activar el auto-follow del mapa.
        final container = ProviderContainer(
          overrides: [locationServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const StartupLocationGate(
              child: SizedBox(key: ValueKey('gate-child')),
            ),
          ),
        );
        await settle(tester);

        expect(fake.requestPermissionCalls, 1);
        expect(fake.checkPermissionCalls, greaterThanOrEqualTo(1));
        expect(container.read(followLocationProvider), isTrue);
        expect(
          container.read(locationControllerProvider).status,
          LocationStatus.ready,
        );
      },
    );

    testWidgets('permiso ya concedido → solo activa follow, sin diálogos', (
      tester,
    ) async {
      fake = FakeLocationService(initialPermission: LocationPermission.always);

      await tester.pumpWidget(host());
      await settle(tester);

      expect(fake.requestPermissionCalls, 0);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('gate-child'))),
      );
      expect(container.read(followLocationProvider), isTrue);
    });

    testWidgets('deniedForever → no insiste ni activa follow', (tester) async {
      fake = FakeLocationService(
        initialPermission: LocationPermission.deniedForever,
      );

      await tester.pumpWidget(host());
      await settle(tester);

      expect(fake.requestPermissionCalls, 0);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('gate-child'))),
      );
      expect(container.read(followLocationProvider), isFalse);
    });

    testWidgets('GPS apagado → no pide permiso ni activa follow', (
      tester,
    ) async {
      fake = FakeLocationService(enabled: false);

      await tester.pumpWidget(host());
      await settle(tester);

      expect(fake.requestPermissionCalls, 0);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('gate-child'))),
      );
      expect(container.read(followLocationProvider), isFalse);
      expect(
        container.read(locationControllerProvider).status,
        LocationStatus.serviceOff,
      );
    });

    testWidgets('solo se ejecuta una vez por sesión aunque rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await settle(tester);
      expect(fake.requestPermissionCalls, 1);

      // Recrear el árbol NO vuelve a pedir el permiso.
      await tester.pumpWidget(host());
      await settle(tester);
      expect(fake.requestPermissionCalls, 1);
    });
  });
}
