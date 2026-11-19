import 'package:urbano/src/features/journey/application/trip_history_controller.dart';
import 'package:urbano/src/features/journey/data/trip_history.dart';

/// Historial de viajes sin `shared_preferences`: los tests no tocan plugins.
class MemoryTripHistoryStore implements TripHistoryStore {
  MemoryTripHistoryStore([List<TripHistoryEntry> seed = const []])
    : saved = [...seed];

  /// Última lista persistida (lo que leería una nueva sesión).
  List<TripHistoryEntry> saved;

  @override
  Future<List<TripHistoryEntry>> load() async => [...saved];

  @override
  Future<void> save(List<TripHistoryEntry> entries) async =>
      saved = [...entries];
}
