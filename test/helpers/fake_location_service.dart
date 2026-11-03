import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/location/gps_budget.dart';
import 'package:urbano/src/core/location/location_service.dart';

/// Implementación falsa de [LocationService] para tests de widgets: nunca
/// toca el plugin `geolocator` y permite simular el stream del sistema
/// (usuario apaga/enciende el GPS) y los contadores de ajustes.
class FakeLocationService implements LocationService {
  FakeLocationService({
    bool enabled = true,
    LocationPermission initialPermission = LocationPermission.denied,
  }) : _serviceEnabled = enabled,
       _permission = initialPermission;

  bool _serviceEnabled;
  LocationPermission _permission;

  /// Eventos del "sistema": el usuario apaga (`false`) o enciende (`true`)
  /// el GPS. Se usan con [emitServiceStatus].
  final serviceEvents = StreamController<bool>.broadcast();

  /// Eventos de posición en tiempo real. Se usan con [emitPosition].
  /// Es un stream de múltiples oyentes: los tests pueden mirar [hasListener] para
  /// saber si la app tiene el sensor ABIERTO (deber de la demanda de GPS) y
  /// [positionStreamCalls] para cuántas veces se pidió abrirlo.
  final positionEvents = StreamController<LatLng>.broadcast();

  /// Veces que la app pidió la escucha continua (`positionStream`).
  ///
  /// Con `hasListener` es la prueba de que sin demanda NO se llama al plugin: un
  /// provider escuchado pero sin demanda devuelve un stream vacío aquí mismo.
  int positionStreamCalls = 0;

  /// Permiso que concede `requestPermission` (por defecto `whileInUse`).
  LocationPermission grantOnRequest = LocationPermission.whileInUse;

  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int openLocationSettingsCalls = 0;
  int openAppSettingsCalls = 0;

  /// Apaga/enciende el GPS y emite el evento como haría el sistema.
  void emitServiceStatus(bool enabled) {
    _serviceEnabled = enabled;
    serviceEvents.add(enabled);
  }

  /// Emite una nueva coordenada GPS en tiempo real.
  void emitPosition(LatLng position) {
    positionEvents.add(position);
  }

  void dispose() {
    serviceEvents.close();
    positionEvents.close();
  }

  @override
  Future<bool> isServiceEnabled() async => _serviceEnabled;

  @override
  Stream<bool> serviceEnabledStream() => serviceEvents.stream;

  @override
  Stream<LatLng> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = gpsMinMovementMeters,
  }) {
    positionStreamCalls++;
    // Se emite SIN filtrar: el filtro de movimiento real vive más arriba, en
    // `myLocationRealtimeProvider`, y los tests tienen que poder verlo.
    return positionEvents.stream;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    checkPermissionCalls++;
    return _permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    _permission = grantOnRequest;
    return _permission;
  }

  @override
  Future<bool> hasGrantedPermission() async => isPermissionGranted(_permission);

  @override
  Future<LatLng> currentPosition() async => const LatLng(-17.7833, -63.1821);

  /// Caché del «sistema». Por defecto la misma posición que
  /// [currentPosition]; ponla a `null` para simular una plataforma sin caché.
  LatLng? cachedPosition = const LatLng(-17.7833, -63.1821);
  int lastKnownCalls = 0;

  @override
  Future<LatLng?> lastKnownPosition() async {
    lastKnownCalls++;
    return cachedPosition;
  }

  @override
  Future<void> openLocationSettings() async => openLocationSettingsCalls++;

  @override
  Future<void> openAppSettings() async => openAppSettingsCalls++;
}
