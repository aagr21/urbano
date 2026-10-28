import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/providers.dart';
import 'journey_models.dart';

/// Punto geográfico del origen/destino del viaje.
typedef JourneyPoint = ({double lat, double lon});

/// Contrato del planeador de viajes.
abstract class JourneyRepository {
  Future<List<JourneyOption>> plan({
    required JourneyPoint origin,
    required JourneyPoint destination,
    String? time,
    int maxResults = 3,
  });
}

class RemoteJourneyRepository implements JourneyRepository {
  RemoteJourneyRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<JourneyOption>> plan({
    required JourneyPoint origin,
    required JourneyPoint destination,
    String? time,
    int maxResults = 3,
  }) async {
    final json = await _api.fetchObject(
      Endpoints.journey,
      query: compactQuery({
        'originLat': origin.lat,
        'originLon': origin.lon,
        'destLat': destination.lat,
        'destLon': destination.lon,
        'time': time,
        'maxResults': maxResults,
      }),
    );
    final options = json['options'];
    if (options is! List) return const [];
    return options
        .whereType<Map<String, dynamic>>()
        .map(JourneyOption.fromJson)
        .toList(growable: false);
  }
}

final journeyRepositoryProvider = Provider<JourneyRepository>(
  (ref) => RemoteJourneyRepository(ref.watch(apiClientProvider)),
);
