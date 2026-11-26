/// Rutas del API (relativas a `Env.apiBaseUrl`).
///
/// Ver `docs/api-contract.md`. Los ids de ruta contienen espacios
/// ("101 ANGOSTURA"), por eso se codifican con [Uri.encodeComponent].
///
/// Solo están las rutas que la app llama. El backend expone además `/health`,
/// `/meta`, `/stats`, `/trips/:id` y `/routes/:id/departures`, que usan el
/// smoke de producción y las herramientas, no la app.
class Endpoints {
  Endpoints._();

  static const String routes = '/routes';
  static const String journey = '/journey';
  static const String complaints = '/complaints';

  /// Interacciones sociales sobre una queja (like + comentarios).
  static String complaintLike(String id) =>
      '$complaints/${Uri.encodeComponent(id)}/like';
  static String complaintComments(String id) =>
      '$complaints/${Uri.encodeComponent(id)}/comments';

  static String route(String id) => '$routes/${Uri.encodeComponent(id)}';
  static String routeStops(String id) => '${route(id)}/stops';

  /// Paradas: búsqueda por nombre y cercanas a un punto. La app las consume
  /// para el modo «Lugares» del panel de micros («¿qué línea pasa por aquí?»),
  /// el cardinal «cerca de mí» y la vista «Micros cerca» (`/nearby`, con
  /// `radius`).
  static const String stopSearch = '/stops/search';
  static const String stopsNearby = '/stops/nearby';
}
