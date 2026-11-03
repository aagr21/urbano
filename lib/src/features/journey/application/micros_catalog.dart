import '../../routes/data/route_models.dart';
import '../../stops/data/stop_search_models.dart';

/// Catálogo del **panel de micros**: las funciones puras que necesita para
/// filtrar su listado, resolver las direcciones de una línea y armar la
/// referencia mínima que consume el controller al dibujar/borrar un recorrido.
///
/// Viven fuera de los widgets a propósito: así el panel solo pinta y esta
/// lógica se puede probar sin montar el árbol.

/// Clave de un recorrido activo en el mapa: `routeId#directionId`. Es el
/// contrato compartido entre el panel, los marcadores del mapa y el controller
/// del planeador.
String microDirectionKey(String routeId, int directionId) =>
    '$routeId#$directionId';

/// Una dirección de un micro: id GTFS (0 = ida, 1 = vuelta) + headsign
/// conocido (vacío si el detalle aún no se cargó).
class MicroDirection {
  const MicroDirection(this.directionId, this.headsign);

  final int directionId;
  final String headsign;

  String get label => directionId == 0 ? 'Ida' : 'Vuelta';
}

/// Filtra el listado ya descargado por numeral, nombre o id (local y gratis:
/// teclear no cuesta una petición).
List<RouteSummary> filterMicros(List<RouteSummary> micros, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return micros;
  return micros
      .where(
        (micro) =>
            micro.shortName.toLowerCase().contains(q) ||
            micro.longName.toLowerCase().contains(q) ||
            micro.id.toLowerCase().contains(q),
      )
      .toList();
}

/// Direcciones dibujables de un micro: las reales del detalle si ya se cargó
/// (con su headsign), o `0`/`1` por defecto (GTFS: 0 = ida, 1 = vuelta)
/// mientras no se conozcan.
List<MicroDirection> directionsOfMicro(
  RouteSummary micro,
  RouteDetail? detail,
) {
  if (detail != null && detail.directions.isNotEmpty) {
    return [
      for (final d in detail.directions)
        MicroDirection(d.directionId, d.headsign),
    ];
  }
  final count = micro.directionsCount.clamp(1, 2);
  return [for (var i = 0; i < count; i++) MicroDirection(i, '')];
}

/// Referencia de línea de un resultado del modo LUGARES → [RouteSummary]
/// mínima para el toggle: el controller solo lee `id` y `shortName` (la forma
/// de la ruta la pide él al backend).
RouteSummary summaryForStopRoute(StopRouteRef route) => RouteSummary(
  id: route.id,
  shortName: route.shortName,
  longName: 'Línea ${route.shortName}',
  color: route.color,
  textColor: 'FFFFFF',
  description: 'Transporte publico urbano de micros',
  type: 3,
  directionsCount: 2,
  stopCount: 0,
  tripCount: 0,
);
