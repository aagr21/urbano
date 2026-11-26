import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/osm_street_repository.dart';
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

/// Página del catálogo que precalienta el arranque.
///
/// La comparten el panel de micros de Viaje **y la pantalla de carga**
/// (`bootReadinessProvider` en `core/boot`): como `routesListProvider` está
/// indexado por la propia consulta, ambos suscriben al mismo provider y el
/// arranque dispara **un solo** `/routes`, no uno por pantalla.
const RoutesQuery homeCatalogQuery = RoutesQuery(limit: 6);

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

/// Calles y avenidas del recorrido, resueltas con OpenStreetMap (Overpass).
///
/// Parte del trazado que ya trae el detalle, así que no pide dos veces la
/// geometría. Bajo `flutter test` el repositorio devuelve vacío sin tocar la
/// red y la sección «Por dónde pasa» simplemente no se monta.
final routeStreetsProvider = FutureProvider.autoDispose
    .family<List<String>, RouteKey>((ref, key) async {
      final detail = await ref.watch(routeDetailProvider(key).future);
      final points = detail.shape?.points ?? const [];
      if (points.length < 2) return const [];
      return ref.watch(osmStreetRepositoryProvider).streetsAlong(points);
    });
