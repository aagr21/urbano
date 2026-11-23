import '../../data/saved_trips.dart';
import '../../data/trip_history.dart';
import 'journey_recent_destinations.dart';

/// Construye una lista unificada de destinos recientes combinando savedTrips
/// y history, deduplicando por coordenadas y ordenando por fecha.
///
/// Retorna como máximo 10 elementos para no saturar el sheet.
List<RecentDestinationItem> buildUnifiedRecentList({
  required List<SavedTrip> savedTrips,
  required List<TripHistoryEntry> history,
}) {
  final seen = <String>{};
  final items = <RecentDestinationItem>[];

  for (final trip in savedTrips) {
    final destKey =
        '${trip.destinationLat.toStringAsFixed(4)}|${trip.destinationLon.toStringAsFixed(4)}';
    if (seen.contains(destKey)) continue;
    seen.add(destKey);
    items.add(RecentDestinationItem.savedTrip(trip));
  }

  for (final entry in history) {
    final destKey =
        '${entry.lat.toStringAsFixed(4)}|${entry.lon.toStringAsFixed(4)}';
    if (seen.contains(destKey)) continue;
    seen.add(destKey);
    items.add(RecentDestinationItem.historyEntry(entry));
  }

  // Ordenar por fecha más reciente primero
  items.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));

  return items;
}
