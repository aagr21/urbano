import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/providers.dart';
import '../../../core/utils/simple_cache.dart';
import 'route_models.dart';

/// Contrato de acceso a rutas.
abstract class RouteRepository {
  Future<Paged<RouteSummary>> list({
    String? q,
    int page = 1,
    int limit = 20,
    String? sort,
  });

  Future<RouteDetail> detail(String id, {int? directionId});

  /// Paradas EN ORDEN del recorrido (`directionId` 0 = ida, 1 = vuelta).
  Future<List<RouteStop>> stops(String id, {int directionId = 0});

  Future<List<Departure>> departures(
    String id, {
    String? stopId,
    int? directionId,
    String? time,
    String? date,
  });
}

class RemoteRouteRepository implements RouteRepository {
  RemoteRouteRepository(this._api)
    : _cache = SimpleCache(ttl: const Duration(minutes: 3));

  final ApiClient _api;
  final SimpleCache _cache;

  @override
  Future<Paged<RouteSummary>> list({
    String? q,
    int page = 1,
    int limit = 20,
    String? sort,
  }) {
    final key = 'routes|${q ?? ''}|$page|$limit|${sort ?? ''}';
    final cached = _cache.read<Paged<RouteSummary>>(key);
    if (cached != null) return Future.value(cached);

    return _api
        .fetchPaged<RouteSummary>(
          Endpoints.routes,
          query: compactQuery({
            'q': q,
            'page': page,
            'limit': limit,
            'sort': sort,
          }),
          fromJson: RouteSummary.fromJson,
        )
        .then((result) {
          _cache.write(key, result);
          return result;
        });
  }

  @override
  Future<RouteDetail> detail(String id, {int? directionId}) {
    final key = 'route|$id|${directionId ?? 0}';
    final cached = _cache.read<RouteDetail>(key);
    if (cached != null) return Future.value(cached);

    return _api
        .fetchObject(
          Endpoints.route(id),
          query: compactQuery({'directionId': directionId}),
        )
        .then((json) {
          final detail = RouteDetail.fromJson(json);
          _cache.write(key, detail);
          return detail;
        });
  }

  @override
  Future<List<RouteStop>> stops(String id, {int directionId = 0}) {
    final key = 'route-stops|$id|$directionId';
    final cached = _cache.read<List<RouteStop>>(key);
    if (cached != null) return Future.value(cached);

    return _api
        .fetchList<RouteStop>(
          Endpoints.routeStops(id),
          query: compactQuery({'directionId': directionId}),
          fromJson: RouteStop.fromJson,
        )
        .then((stops) {
          _cache.write(key, stops);
          return stops;
        });
  }

  @override
  Future<List<Departure>> departures(
    String id, {
    String? stopId,
    int? directionId,
    String? time,
    String? date,
  }) => _api.fetchList<Departure>(
    Endpoints.routeDepartures(id),
    query: compactQuery({
      'stopId': stopId,
      'directionId': directionId,
      'time': time,
      'date': date,
    }),
    fromJson: Departure.fromJson,
  );
}

final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => RemoteRouteRepository(ref.watch(apiClientProvider)),
);
