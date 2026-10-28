import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/network/api_client.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';

/// Fake ÚNICO de [RouteRepository] para los tests de widget.
///
/// Reemplaza las tres copias que vimos romperse en cascada cuando la
/// interfaz cambia (la lección de la sesión del buscador de lugares). Todo
/// es configuración opcional con valores sanos por defecto:
/// - [listCalls]/[detailCalls]: registro para asertar qué se pidió.
/// - Catalogo por páginas con filtro `q` insensible a mayúsculas.
/// - `detail` derivado del catálogo (ida/vuelta + shape de 2 puntos) con
///   [headsigns] configurables, o un detalle fijo por id vía [details].
/// - [stops]/[departures] con fixtures directos (vacío por defecto).
/// - [listError]/[detailError] para simular no-red o 5xx.
class FakeRouteRepository implements RouteRepository {
  FakeRouteRepository(
    this.routes, {
    this.details,
    List<RouteStop> stops = const [],
    List<Departure> departures = const [],
    this.listError,
    this.detailError,
    this.headsigns = const ('Ida', 'Vuelta'),
    this.shape,
  }) : stopsFixture = stops,
       departuresFixture = departures;

  /// Catálogo servido por páginas (páginas vacías cuando se agota).
  final List<RouteSummary> routes;

  /// Detalles fijos por id; si el id no está, se deriva del catálogo.
  final Map<String, RouteDetail>? details;

  /// Paradas/salidas servidas por los métodos de la interfaz.
  final List<RouteStop> stopsFixture;
  final List<Departure> departuresFixture;

  /// Errores simulados (no-red/5xx) por llamada a listado/detalle.
  final Object? listError;
  final Object? detailError;

  /// Headsigns del detalle derivado (los tests del panel usan los suyos).
  final (String, String) headsigns;

  /// Forma del recorrido del detalle derivado (2 puntos bastan al encuadre).
  final RouteShape? shape;

  /// Registro de llamadas a listado: `page=N limit=M sort=S`.
  final List<String> listCalls = [];

  /// Registro de llamadas a detalle: `detail=id#directionId`.
  final List<String> detailCalls = [];

  /// Ventana de una página del catálogo, vacía tras el final (guarda el
  /// sublist negativo que reventaba el fake original del panel).
  static List<RouteSummary> pageOf(
    List<RouteSummary> catalog,
    int page,
    int limit,
  ) {
    if (limit <= 0 || page <= 0) return const [];
    final start = (page - 1) * limit;
    return start >= catalog.length
        ? const []
        : catalog.sublist(start, math.min(start + limit, catalog.length));
  }

  @override
  Future<Paged<RouteSummary>> list({
    String? q,
    int page = 1,
    int limit = 20,
    String? sort,
  }) async {
    listCalls.add('page=$page limit=$limit sort=${sort ?? '-'}');
    if (listError != null) throw listError!;
    final needle = q?.toLowerCase();
    final catalog = needle == null
        ? routes
        : routes
              .where(
                (r) =>
                    r.shortName.toLowerCase().contains(needle) ||
                    r.longName.toLowerCase().contains(needle) ||
                    r.id.toLowerCase().contains(needle),
              )
              .toList(growable: false);
    return Paged(
      items: pageOf(catalog, page, limit),
      meta: Meta(page: page, limit: limit, total: catalog.length),
    );
  }

  @override
  Future<RouteDetail> detail(String id, {int? directionId}) async {
    detailCalls.add('detail=$id#${directionId ?? 0}');
    if (detailError != null) throw detailError!;
    final fixed = details?[id];
    if (fixed != null) return fixed;
    final summary = routes.firstWhere(
      (r) => r.id == id,
      orElse: () => throw StateError('FakeRouteRepository: id "$id" no está'),
    );
    // El backend siempre devuelve la dirección (ida con headsign en el feed
    // real; aquí con el par configurable) y la shape de 2 puntos de prueba.
    return RouteDetail(
      id: summary.id,
      shortName: summary.shortName,
      longName: summary.longName,
      color: summary.color,
      textColor: summary.textColor,
      description: summary.description,
      type: summary.type,
      directionsCount: summary.directionsCount,
      stopCount: summary.stopCount,
      tripCount: summary.tripCount,
      bbox: const [],
      directions: [
        for (final i in List.generate(summary.directionsCount, (i) => i))
          RouteDirection(
            directionId: i,
            headsign: i == 0 ? headsigns.$1 : headsigns.$2,
            tripId: 'T$i',
            firstDeparture: '06:00:00',
            lastDeparture: '22:00:00',
            headwaySeconds: 600,
            stopCount: summary.stopCount,
          ),
      ],
      shape:
          shape ??
          const RouteShape(
            id: 'shape-fake',
            points: [LatLng(-17.78, -63.18), LatLng(-17.80, -63.16)],
          ),
    );
  }

  @override
  Future<List<Departure>> departures(
    String id, {
    String? stopId,
    int? directionId,
    String? time,
    String? date,
  }) async => departuresFixture;

  @override
  Future<List<RouteStop>> stops(String id, {int directionId = 0}) async =>
      stopsFixture;
}
