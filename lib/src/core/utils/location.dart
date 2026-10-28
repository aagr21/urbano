/// Compatibilidad: el módulo de ubicación vive ahora en `core/location/`.
///
/// - `location_service.dart`: [LocationService] testeable, [LocationFailure],
///   [locationServiceProvider], [myLocationProvider].
/// - `location_controller.dart`: [LocationStatus] + [LocationController] con
///   el flujo completo de permisos y el stream del sistema.
/// - `location_fab.dart`: [LocationFab] (widget).
library;

export '../location/location_controller.dart';
export '../location/location_service.dart';
