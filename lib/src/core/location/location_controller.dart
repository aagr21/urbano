import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// Estado de la ubicación del usuario, derivado del servicio del sistema y
/// del permiso concedido.
enum LocationStatus {
  /// El GPS del teléfono está apagado.
  serviceOff,

  /// Permiso sin conceder todavía (se puede pedir).
  permissionPending,

  /// Permiso bloqueado ("denied forever"): solo se resuelve desde ajustes.
  permissionBlocked,

  /// Servicio activo y permiso concedido.
  ready,
}

/// Snapshot del servicio + permiso de ubicación.
@immutable
class LocationState {
  const LocationState({
    this.serviceEnabled = true,
    this.permission = LocationPermission.denied,
  });

  /// `false` si el usuario apagó el GPS del sistema.
  final bool serviceEnabled;

  final LocationPermission permission;

  /// `true` si el permiso permite obtener posición.
  bool get hasPermission => isPermissionGranted(permission);

  LocationStatus get status {
    if (!serviceEnabled) return LocationStatus.serviceOff;
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationStatus.ready,
      LocationPermission.deniedForever => LocationStatus.permissionBlocked,
      _ => LocationStatus.permissionPending,
    };
  }

  LocationState copyWith({
    bool? serviceEnabled,
    LocationPermission? permission,
  }) => LocationState(
    serviceEnabled: serviceEnabled ?? this.serviceEnabled,
    permission: permission ?? this.permission,
  );
}

/// Controller Riverpod del flujo de ubicación.
///
/// - Revisa servicio + permiso al crearlo y tras cada petición.
/// - Se suscribe al stream del sistema: si el usuario apaga/enciende el GPS
///   el estado (y por lo tanto el botón) **cambia solo**.
/// - [activate] resuelve el flujo completo con diálogos de ajustes.
class LocationController extends Notifier<LocationState> {
  /// Evita que callbacks asíncronos de una generación anterior (provider
  /// recreado con otro servicio en tests) toquen el estado nuevo.
  int _generation = 0;

  StreamSubscription<bool>? _serviceSubscription;

  @override
  LocationState build() {
    final service = ref.watch(locationServiceProvider);
    final generation = ++_generation;

    _serviceSubscription?.cancel();
    _serviceSubscription = service
        .serviceEnabledStream()
        // Sin plataforma no hay eventos (ni errores que rompan el flujo).
        .handleError((_) {})
        .listen((enabled) {
          if (generation != _generation) return;
          if (state.serviceEnabled == enabled) return;
          state = state.copyWith(serviceEnabled: enabled);
          // Al encender el GPS re-consultamos el permiso (pudo cambiar en ajustes).
          if (enabled) unawaited(checkPermission());
        });
    // Invalida callbacks asíncronos de ESTA pasada al reconstruir/disponer
    // (Riverpod reutiliza la instancia del Notifier entre rebuilds; los
    // callbacks de una pasada anterior no deben tocar el estado nuevo).
    ref.onDispose(() {
      if (generation == _generation) _generation++;
      _serviceSubscription?.cancel();
    });

    // Estado inicial: servicio + permiso, sin diálogos.
    unawaited(checkPermission());
    return const LocationState();
  }

  /// Revisa servicio + permiso y actualiza el estado (sin mostrar diálogos).
  Future<void> checkPermission() async {
    final service = ref.read(locationServiceProvider);
    final generation = _generation;
    final enabled = await service.isServiceEnabled();
    final permission = await service.checkPermission();
    if (generation != _generation) return;
    state = LocationState(serviceEnabled: enabled, permission: permission);
  }

  /// Pide permisos (diálogo del sistema; en iOS además escala a "siempre").
  /// Devuelve `true` si quedó concedido y refresca [myLocationProvider].
  Future<bool> requestPermission() async {
    final service = ref.read(locationServiceProvider);
    final generation = _generation;
    final permission = await service.requestPermission();
    final enabled = await service.isServiceEnabled();
    if (generation != _generation) {
      return isPermissionGranted(permission);
    }
    state = LocationState(serviceEnabled: enabled, permission: permission);
    if (isPermissionGranted(permission)) {
      ref.invalidate(myLocationProvider);
      ref.invalidate(myLocationRealtimeProvider);
      return true;
    }
    return false;
  }

  /// Flujo completo al tocar el botón de ubicación, con diálogos de ajustes:
  ///
  /// 1. Servicio apagado → diálogo "La ubicación de tu teléfono está apagada"
  ///    con "Abrir ajustes" ([LocationService.openLocationSettings]) o
  ///    "Continuar de todos modos" (sigue solo con el permiso).
  /// 2. Permiso `denied` → pide permisos ([requestPermission]).
  /// 3. Permiso bloqueado → diálogo "Permiso bloqueado" con
  ///    "Abrir ajustes de la app" ([LocationService.openAppSettings]).
  /// 4. Concedido → refresca [myLocationProvider] y devuelve `true`.
  Future<bool> activate(BuildContext context) async {
    final service = ref.read(locationServiceProvider);
    await checkPermission();
    if (!context.mounted) return false;

    if (!state.serviceEnabled) {
      final openSettings = await _showServiceOffDialog(context);
      if (openSettings) {
        await service.openLocationSettings();
        await checkPermission();
        if (!state.serviceEnabled) return false; // siguió apagado.
      }
      // "Continuar de todos modos": se sigue solo con el permiso.
    }

    if (state.permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      final openSettings = await _showPermissionBlockedDialog(context);
      if (openSettings) {
        await service.openAppSettings();
        await checkPermission();
      }
      return state.hasPermission;
    }

    if (!state.hasPermission) {
      final granted = await requestPermission();
      if (!granted) await checkPermission();
      return granted;
    }

    return true;
  }

  Future<bool> _showServiceOffDialog(BuildContext context) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('La ubicación de tu teléfono está apagada'),
        content: const Text(
          'Activa el GPS para que Urbano pueda mostrarte dónde estás '
          'y trazar tu viaje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar de todos modos'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
    return openSettings ?? false;
  }

  Future<bool> _showPermissionBlockedDialog(BuildContext context) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso de ubicación bloqueado'),
        content: const Text(
          'El permiso está bloqueado. Actívalo desde los ajustes de la app '
          'para que Urbano pueda usar tu ubicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abrir ajustes de la app'),
          ),
        ],
      ),
    );
    return openSettings ?? false;
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);

/// Intención del usuario (o del arranque) de seguir la ubicación en el mapa.
///
/// Es independiente del estado del sistema: el seguimiento REAL del mapa es
/// `followLocationProvider && status == ready` (ver el planner), de modo que
/// si el GPS se apaga la cámara deja de seguir y vuelve sola al encenderse.
final followLocationProvider = StateProvider<bool>((ref) => false);
