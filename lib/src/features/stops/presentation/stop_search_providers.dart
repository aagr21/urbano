import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stop_search_models.dart';
import '../data/stop_search_repository.dart';

/// Búsqueda de paradas por texto (`/stops/search`): esquinas con sus
/// líneas. Family por texto; el repositorio ya cachea (TTL), así que
/// reabrir el panel no vuelve a pagar la red.
final stopNameSearchProvider = FutureProvider.autoDispose
    .family<List<StopHit>, String>((ref, q) {
      return ref.watch(stopSearchRepositoryProvider).search(q);
    });
