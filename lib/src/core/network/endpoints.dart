/// Rutas del API (relativas a `Env.apiBaseUrl`).
///
/// Ver `docs/api-contract.md`. Los ids de ruta contienen espacios
/// ("101 ANGOSTURA"), por eso se codifican con [Uri.encodeComponent].
///
/// Nota: los endpoints de paradas del backend (`/stops`, `/stops/*`) NO se
/// usan desde la app; `/routes/:id/stops` SÍ: alimenta la sección «Pasa por»
/// del detalle (lugares principales del recorrido).
class Endpoints {
  Endpoints._();

  static const String health = '/health';

  /// Contrato de dataset + invariantes del planner (`GET /meta`).
  static const String meta = '/meta';
  static const String stats = '/stats';
  static const String routes = '/routes';
  static const String trips = '/trips';
  static const String journey = '/journey';

  static String route(String id) => '$routes/${Uri.encodeComponent(id)}';
  static String routeStops(String id) => '${route(id)}/stops';
  static String routeDepartures(String id) => '${route(id)}/departures';

  /// Paradas: búsqueda por nombre y cercanas a un punto. La app las consume
  /// para el modo «Lugares» del panel de micros («¿qué línea pasa por aquí?»)
  /// y el cardinal «cerca de mí».
  static const String stopSearch = '/stops/search';
  static const String stopsNearby = '/stops/nearby';
  static String trip(String id) => '$trips/${Uri.encodeComponent(id)}';
}
