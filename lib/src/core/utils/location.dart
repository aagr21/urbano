/// Compatibilidad: el módulo de ubicación vive ahora en `core/location/`.
///
/// - `location_service.dart`: [LocationService] testeable, [LocationFailure],
///   [locationServiceProvider], [myLocationProvider].
/// - `location_controller.dart`: [LocationStatus] + [LocationController] con
///   el flujo completo de permisos y el stream del sistema; además la demanda de
///   GPS ([locationDemandProvider]) y el stream continuo que enciende.
/// - `app_foreground.dart`: [appForegroundProvider] (ciclo de vida de la app).
/// - `gps_budget.dart`: presupuesto puro del sensor (umbrales, ajustes, filtro de
///   movimiento real).
/// - `location_fab.dart`: [LocationFab] (widget).
library;

export '../location/app_foreground.dart';
export '../location/location_controller.dart';
export '../location/location_service.dart';
