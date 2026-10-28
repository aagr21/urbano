import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:urbano/src/core/location/location_controller.dart';
import 'package:urbano/src/core/location/location_fab.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/theme/app_theme.dart';

import 'helpers/fake_location_service.dart';

Widget _fabApp(
  FakeLocationService service, {
  bool following = false,
  ValueChanged<bool>? onFollowChanged,
}) => ProviderScope(
  overrides: [locationServiceProvider.overrideWithValue(service)],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: LocationFab(
          following: following,
          onFollowChanged: onFollowChanged ?? (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  group('LocationFab · estados reales del sistema', () {
    testWidgets(
      'GPS apagado: icono off con punto rojo y al tocar ofrece "Abrir ajustes"',
      (tester) async {
        final service = FakeLocationService(
          enabled: false,
          initialPermission: LocationPermission.whileInUse,
        );
        addTearDown(service.dispose);

        var followed = false;
        await tester.pumpWidget(
          _fabApp(service, onFollowChanged: (value) => followed = value),
        );
        await tester.pumpAndSettle();

        // Estado: servicio apagado → icono off en color error + punto rojo.
        expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);
        expect(
          find.byTooltip(
            'La ubicación de tu teléfono está apagada · toca para activarla',
          ),
          findsOneWidget,
        );

        // Al tocar aparece el diálogo del flujo con "Abrir ajustes".
        await tester.tap(find.byType(LocationFab));
        await tester.pumpAndSettle();
        expect(
          find.text('La ubicación de tu teléfono está apagada'),
          findsOneWidget,
        );
        await tester.tap(find.text('Abrir ajustes'));
        await tester.pumpAndSettle();

        expect(service.openLocationSettingsCalls, 1);
        // Sigue apagado: no empieza a seguir la ubicación.
        expect(followed, isFalse);
        expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'permiso denied: activate() pide permiso y devuelve true al conceder',
      (tester) async {
        final service = FakeLocationService();
        addTearDown(service.dispose);

        bool? followed;
        await tester.pumpWidget(
          _fabApp(service, onFollowChanged: (value) => followed = value),
        );
        await tester.pumpAndSettle();

        // Permiso pendiente → icono normal (al tocar pide permisos).
        expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

        await tester.tap(find.byType(LocationFab));
        await tester.pumpAndSettle();

        expect(service.requestPermissionCalls, 1);
        expect(followed, isTrue);
        // El permiso quedó concedido: estado "listo". El FAB es constante
        // cuando la ubicación está disponible (mismo icono my_location).
        expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      },
    );

    testWidgets('permiso bloqueado: diálogo con "Abrir ajustes de la app"', (
      tester,
    ) async {
      final service = FakeLocationService(
        initialPermission: LocationPermission.deniedForever,
      );
      addTearDown(service.dispose);

      var followed = false;
      await tester.pumpWidget(
        _fabApp(service, onFollowChanged: (value) => followed = value),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.gps_off_rounded), findsOneWidget);

      await tester.tap(find.byType(LocationFab));
      await tester.pumpAndSettle();

      expect(find.text('Permiso de ubicación bloqueado'), findsOneWidget);
      await tester.tap(find.text('Abrir ajustes de la app'));
      await tester.pumpAndSettle();

      expect(service.openAppSettingsCalls, 1);
      // Bloqueado sigue bloqueado → no se empieza a seguir.
      expect(followed, isFalse);
      expect(service.requestPermissionCalls, 0);
    });

    testWidgets(
      'el botón cambia SOLO cuando el sistema apaga/enciende el GPS (stream)',
      (tester) async {
        final service = FakeLocationService(
          initialPermission: LocationPermission.whileInUse,
        );
        addTearDown(service.dispose);

        await tester.pumpWidget(_fabApp(service));
        await tester.pumpAndSettle();
        // Listo sin seguir: icono constante del FAB.
        expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

        // El usuario apaga el GPS en el sistema: sin tocar la app.
        service.emitServiceStatus(false);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);

        // Y lo vuelve a encender.
        service.emitServiceStatus(true);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'siguiendo: el FAB se mantiene constante y tocar deja de seguir',
      (tester) async {
        final service = FakeLocationService(
          initialPermission: LocationPermission.always,
        );
        addTearDown(service.dispose);

        var followed = true;
        await tester.pumpWidget(
          _fabApp(
            service,
            following: true,
            onFollowChanged: (value) => followed = value,
          ),
        );
        await tester.pumpAndSettle();

        // Diseño deliberado: el FAB no cambia con el follow (el feedback lo dan
        // el mapa y la cámara); lo que cambia es el tooltip.
        expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
        expect(find.byTooltip('Dejar de seguir mi ubicación'), findsOneWidget);

        // Tocar mientras sigue → deja de seguir.
        await tester.tap(find.byType(LocationFab));
        await tester.pumpAndSettle();
        expect(followed, isFalse);
      },
    );

    testWidgets('al reanudar la app re-consulta el permiso', (tester) async {
      final service = FakeLocationService();
      addTearDown(service.dispose);

      await tester.pumpWidget(_fabApp(service));
      await tester.pumpAndSettle();

      final callsBefore = service.checkPermissionCalls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(service.checkPermissionCalls, greaterThan(callsBefore));
    });
  });

  group('LocationController', () {
    test('estado derivado: servicio + permiso', () {
      expect(
        const LocationState(serviceEnabled: false).status,
        LocationStatus.serviceOff,
      );
      expect(const LocationState().status, LocationStatus.permissionPending);
      expect(
        const LocationState(permission: LocationPermission.deniedForever)
            .status,
        LocationStatus.permissionBlocked,
      );
      expect(
        const LocationState(permission: LocationPermission.whileInUse).status,
        LocationStatus.ready,
      );
      expect(
        const LocationState(permission: LocationPermission.always).status,
        LocationStatus.ready,
      );
    });
  });
}
