import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/route_models.dart';
import '../data/route_repository.dart';

/// Parámetros de listado de rutas.
class RoutesQuery {
  const RoutesQuery({
    this.q = '',
    this.page = 1,
    this.limit = 20,
    this.sort = 'name',
  });

  final String q;
  final int page;
  final int limit;
  final String sort;

  RoutesQuery copyWith({String? q, int? page, int? limit, String? sort}) =>
      RoutesQuery(
        q: q ?? this.q,
        page: page ?? this.page,
        limit: limit ?? this.limit,
        sort: sort ?? this.sort,
      );

  @override
  bool operator ==(Object other) =>
      other is RoutesQuery &&
      other.q == q &&
      other.page == page &&
      other.limit == limit &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(q, page, limit, sort);
}

/// Identidad de detalle: ruta + dirección.
class RouteKey {
  const RouteKey(this.routeId, {this.directionId = 0});

  final String routeId;
  final int directionId;

  @override
  bool operator ==(Object other) =>
      other is RouteKey &&
      other.routeId == routeId &&
      other.directionId == directionId;

  @override
  int get hashCode => Object.hash(routeId, directionId);
}

/// Consulta de una tira de salidas (`/routes/:id/departures`). La UI del
/// detalle ya no la muestra, pero la capa de datos la conserva para
/// consultas puntuales (y los tests que la ejercitan).
class DeparturesQuery {
  const DeparturesQuery({
    required this.routeId,
    this.stopId,
    this.directionId,
    this.time,
    this.date,
  });

  final String routeId;
  final String? stopId;
  final int? directionId;
  final String? time;
  final String? date;

  @override
  bool operator ==(Object other) =>
      other is DeparturesQuery &&
      other.routeId == routeId &&
      other.stopId == stopId &&
      other.directionId == directionId &&
      other.time == time &&
      other.date == date;

  @override
  int get hashCode => Object.hash(routeId, stopId, directionId, time, date);
}

/// Listado de rutas (con caché en el repositorio).
final routesListProvider = FutureProvider.autoDispose
    .family<Paged<RouteSummary>, RoutesQuery>((ref, query) {
      final repository = ref.watch(routeRepositoryProvider);
      return repository.list(
        q: query.q.isEmpty ? null : query.q,
        page: query.page,
        limit: query.limit,
        sort: query.sort,
      );
    });

/// Detalle de una ruta (polilínea + direcciones).
final routeDetailProvider = FutureProvider.autoDispose
    .family<RouteDetail, RouteKey>((ref, key) {
      return ref
          .watch(routeRepositoryProvider)
          .detail(key.routeId, directionId: key.directionId);
    });

/// Paradas del recorrido en orden: alimenta «Pasa por» del detalle.
final routeStopsProvider = FutureProvider.autoDispose
    .family<List<RouteStop>, RouteKey>((ref, key) {
      return ref
          .watch(routeRepositoryProvider)
          .stops(key.routeId, directionId: key.directionId);
    });

/// Próximas salidas (sin hora ⇒ hora actual America/La_Paz en el backend).
final routeDeparturesProvider = FutureProvider.autoDispose
    .family<List<Departure>, DeparturesQuery>((ref, query) {
      return ref
          .watch(routeRepositoryProvider)
          .departures(
            query.routeId,
            stopId: query.stopId,
            directionId: query.directionId,
            time: query.time,
            date: query.date,
          );
    });
