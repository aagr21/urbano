import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/providers.dart';
import '../../../core/utils/simple_cache.dart';
import 'stats.dart';

/// Acceso a los metadatos del feed (stats + health).
abstract class StatsRepository {
  Future<Stats> stats();

  Future<HealthInfo> health();
}

class RemoteStatsRepository implements StatsRepository {
  RemoteStatsRepository(this._api)
    : _cache = SimpleCache(ttl: const Duration(minutes: 10));

  final ApiClient _api;
  final SimpleCache _cache;

  @override
  Future<Stats> stats() async {
    const key = 'stats';
    final cached = _cache.read<Stats>(key);
    if (cached != null) return cached;
    final result = Stats.fromJson(await _api.fetchObject(Endpoints.stats));
    _cache.write(key, result);
    return result;
  }

  @override
  Future<HealthInfo> health() async =>
      HealthInfo.fromJson(await _api.fetchObject(Endpoints.health));
}

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => RemoteStatsRepository(ref.watch(apiClientProvider)),
);
