import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Fallo de ubicación con mensaje amigable.
enum LocationFailureKind {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unavailable,
}

class LocationFailure implements Exception {
  const LocationFailure(this.kind);

  final LocationFailureKind kind;

  String get friendlyMessage => switch (kind) {
    LocationFailureKind.permissionDenied =>
      'Activa el permiso de ubicación para viajar.',
    LocationFailureKind.permissionDeniedForever =>
      'El permiso de ubicación está bloqueado. Actívalo desde ajustes.',
    LocationFailureKind.serviceDisabled =>
      'El servicio de ubicación está apagado. Actívalo para continuar.',
    LocationFailureKind.unavailable =>
      'No pudimos obtener tu ubicación. Intenta de nuevo.',
  };
}

/// Resultado de solicitar permiso al usuario.
enum PermissionOutcome { granted, denied, deniedForever }

/// `true` si el permiso permite obtener posición (`whileInUse` o `always`).
bool isPermissionGranted(LocationPermission permission) =>
    permission == LocationPermission.whileInUse ||
    permission == LocationPermission.always;

/// Acceso a GPS con una interfaz **testeable**: toda llamada a `geolocator`
/// pasa por aquí, así los tests inyectan un fake y nunca tocan el plugin.
///
/// Todas las llamadas degradan sin lanzar cuando la plataforma no está
/// disponible (p. ej. `flutter test` sin plugin): se asume servicio activo y
/// permiso "pendiente" para que el usuario pueda pedirlo a mano.
class LocationService {
  /// `true` si el servicio de ubicación (GPS del sistema) está activado.
  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      // Plataforma no disponible: asumimos activo (el permiso se pide a mano).
      return true;
    }
  }

  /// Stream con el estado del servicio: `true` = activado.
  ///
  /// Es el que permite que el botón de ubicación **cambie solo** cuando el
  /// usuario apaga o enciende el GPS, sin tocar la app.
  Stream<bool> serviceEnabledStream() {
    try {
      return Geolocator.getServiceStatusStream().map(
        (status) => status == ServiceStatus.enabled,
      );
    } catch (_) {
      return const Stream<bool>.empty();
    }
  }

  /// Permiso actual (sin mostrar diálogo). `denied` si no se pudo consultar.
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  /// Pide permiso (diálogo del sistema la primera vez).
  ///
  /// En iOS el plugin ya pide el nivel más alto declarado en el `Info.plist`:
  /// si la app incluye `NSLocationAlwaysAndWhenInUseUsageDescription`,
  /// `Geolocator.requestPermission()` escala a "siempre" (permisos
  /// completos). En Android el diálogo del sistema ofrece los niveles del
  /// manifest.
  Future<LocationPermission> requestPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission;
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  /// `true` si ya hay permiso (sin mostrar diálogo).
  /// Lanza [LocationFailure] si el servicio está apagado o bloqueado.
  Future<bool> hasGrantedPermission() async {
    if (!await isServiceEnabled()) {
      throw const LocationFailure(LocationFailureKind.serviceDisabled);
    }
    final permission = await checkPermission();
    if (permission == LocationPermission.denied) return false;
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(LocationFailureKind.permissionDeniedForever);
    }
    return true;
  }

  /// Posición actual de UN SOLO uso («cerca de mí», centrado inicial).
  ///
  /// `medium` en vez de `high`: para nivel calle sobra, la fijación llega
  /// antes y el radio GNSS trabaja menos posición por punto (batería y
  /// calor). Los tracks continuos no usan [LocationService] sino la capa
  /// nativa del mapa (ver LiveMapLayer, solo con seguimiento activo).
  Future<LatLng> currentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      throw const LocationFailure(LocationFailureKind.unavailable);
    }
  }

  /// Última posición que el SISTEMA ya tiene para esta app, **sin pedir un
  /// fix nuevo**: la caché del proveedor (Fused en Android, CoreLocation en
  /// iOS).
  ///
  /// Es instantánea y, mientras el mapa está siguiendo la ubicación, está muy
  /// fresca (la capa nativa acaba de mantener el GPS activo). Con eso el punto
  /// de «mi ubicación» toma el relevo del puck nativo sin el hueco de varios
  /// segundos que deja [currentPosition] al soltar el seguimiento.
  Future<LatLng?> lastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      // Sin plataforma / sin caché: no hay nada que sembrar.
      return null;
    }
  }

  /// Stream con la posición en tiempo real del GPS.
  Stream<LatLng> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 2,
  }) {
    try {
      return Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
        ),
      ).map((pos) => LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      return const Stream<LatLng>.empty();
    }
  }

  /// Abre los ajustes del sistema para encender el GPS.
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {
      // Sin plataforma (tests): no hay ajustes que abrir.
    }
  }

  /// Abre los ajustes de la app (permisos) para desbloquear el permiso.
  Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {
      // Sin plataforma (tests): no hay ajustes que abrir.
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (_) => LocationService(),
);

/// Posición actual si el permiso ya fue concedido; `null` si aún no.
///
/// No muestra el diálogo del sistema: para eso usa [MyLocationRef.requestMyLocation].
final myLocationProvider = FutureProvider.autoDispose<LatLng?>((ref) async {
  final service = ref.watch(locationServiceProvider);
  if (!await service.hasGrantedPermission()) return null;
  return service.currentPosition();
});

/// Última posición conocida del usuario: **nunca vuelve a `null`** una vez
/// fijada.
///
/// Se alimenta de [myLocationProvider] (lecturas puntuales) y, al empezar o
/// soltar el seguimiento del mapa, de la caché del sistema
/// ([LocationService.lastKnownPosition]). El punto de «mi ubicación» se dibuja
/// desde aquí en cuanto el puck nativo se apaga: sin desaparecer mientras
/// llega un fix nuevo y sin saltar a la posición de hace minutos.
final lastKnownLocationProvider = NotifierProvider<LastKnownLocation, LatLng?>(
  LastKnownLocation.new,
);

class LastKnownLocation extends Notifier<LatLng?> {
  @override
  LatLng? build() {
    ref.listen(myLocationProvider, (_, next) {
      final point = next.valueOrNull;
      if (point != null) state = point;
    });
    // Semilla: si la lectura puntual ya había resuelto, arrancamos con ella.
    return ref.read(myLocationProvider).valueOrNull;
  }

  /// Re-siembra desde la caché del sistema (instantánea, sin pedir fix).
  ///
  /// Si no hay caché (plataforma sin soporte) no toca el valor: mejor la
  /// última posición conocida que ningún punto.
  Future<void> refreshFromSystem() async {
    final point = await ref.read(locationServiceProvider).lastKnownPosition();
    if (point != null) state = point;
  }
}

/// Stream continuo de la ubicación del usuario en tiempo real.
///
/// Dueño ÚNICO del GPS junto con las lecturas puntuales: el puck nativo de
/// MapLibre ya no pide su propia señal (ver `LiveMapLayer`). Arranca con la
/// caché del sistema (instantánea) para pintar el punto sin esperar el fix
/// y de ahí SIGUE con el stream puro — nunca bloquea con `currentPosition()`
/// porque un primer fix lento dejaría sin eventos el seguimiento completo.
final myLocationRealtimeProvider = StreamProvider.autoDispose<LatLng?>((
  ref,
) async* {
  final service = ref.watch(locationServiceProvider);
  if (!await service.hasGrantedPermission()) {
    yield null;
    return;
  }
  final cached = await service.lastKnownPosition();
  if (cached != null) yield cached;

  yield* service.positionStream();
});

/// Solicita permiso (diálogo) y, si sale concedido, refresca
/// [myLocationProvider] y [myLocationRealtimeProvider].
extension MyLocationRef on WidgetRef {
  Future<PermissionOutcome> requestMyLocation() async {
    final permission = await read(locationServiceProvider).requestPermission();
    if (isPermissionGranted(permission)) {
      invalidate(myLocationProvider);
      invalidate(myLocationRealtimeProvider);
      return PermissionOutcome.granted;
    }
    return switch (permission) {
      LocationPermission.deniedForever => PermissionOutcome.deniedForever,
      _ => PermissionOutcome.denied,
    };
  }
}
