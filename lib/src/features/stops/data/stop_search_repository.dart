import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/providers.dart';
import '../../../core/utils/simple_cache.dart';
import 'stop_search_models.dart';

/// Acceso a paradas por nombre y por cercanía (`/stops/*` del backend).
abstract class StopSearchRepository {
  /// Paradas cuyo nombre casa con [q] (búsqueda insensible, `pg_trgm`).
  Future<List<StopHit>> search(String q);

  /// Paradas ordenadas por distancia al punto dado, con `distanceMeters`.
  Future<List<StopHit>> nearby({required double lat, required double lon});
}

class RemoteStopSearchRepository implements StopSearchRepository {
  RemoteStopSearchRepository(this._api)
    : _cache = SimpleCache(ttl: const Duration(minutes: 3));

  final ApiClient _api;
  final SimpleCache _cache;

  static StopHit _fromJson(Map<String, dynamic> json) => StopHit.fromJson(json);

  @override
  Future<List<StopHit>> search(String q) {
    final key = 'stop-search|$q';
    final cached = _cache.read<List<StopHit>>(key);
    if (cached != null) return Future.value(cached);
    return _api
        .fetchList<StopHit>(
          Endpoints.stopSearch,
          query: compactQuery({'q': q, 'limit': 30}),
          fromJson: _fromJson,
        )
        .then((hits) {
          _cache.write(key, hits);
          return hits;
        });
  }

  @override
  Future<List<StopHit>> nearby({required double lat, required double lon}) {
    final key = 'stop-nearby|$lat|$lon';
    final cached = _cache.read<List<StopHit>>(key);
    if (cached != null) return Future.value(cached);
    return _api
        .fetchList<StopHit>(
          Endpoints.stopsNearby,
          query: compactQuery({'lat': lat, 'lon': lon, 'limit': 30}),
          fromJson: _fromJson,
        )
        .then((hits) {
          _cache.write(key, hits);
          return hits;
        });
  }
}

final stopSearchRepositoryProvider = Provider<StopSearchRepository>((ref) {
  return RemoteStopSearchRepository(ref.watch(apiClientProvider));
});
