import '../data/saved_trips.dart';
import '../data/trip_history.dart';

export '../../../core/utils/paging.dart';

/// Destino reciente de la hoja «¿A dónde vas?»: un viaje guardado (origen y
/// destino) o una fila del historial (solo destino).
sealed class RecentDestinationItem {
  const RecentDestinationItem({required this.key, required this.lastUsed});
  final String key;
  final DateTime lastUsed;

  factory RecentDestinationItem.savedTrip(SavedTrip trip) =
      RecentDestinationSavedTrip;
  factory RecentDestinationItem.historyEntry(TripHistoryEntry entry) =
      RecentDestinationHistoryEntry;
}

class RecentDestinationSavedTrip extends RecentDestinationItem {
  RecentDestinationSavedTrip(this.trip)
    : super(key: trip.key, lastUsed: trip.lastUsed);
  final SavedTrip trip;
}

class RecentDestinationHistoryEntry extends RecentDestinationItem {
  RecentDestinationHistoryEntry(this.entry)
    : super(key: entry.key, lastUsed: entry.lastUsed);
  final TripHistoryEntry entry;
}

/// Une viajes guardados e historial en una sola lista: un destino por punto
/// (redondeado a 4 decimales, ~11 m; el viaje guardado gana porque trae
/// también el origen) y del más reciente al más viejo.
List<RecentDestinationItem> buildUnifiedRecentList({
  required List<SavedTrip> savedTrips,
  required List<TripHistoryEntry> history,
}) {
  final seen = <String>{};
  final items = <RecentDestinationItem>[];

  for (final trip in savedTrips) {
    if (seen.add(_pointKey(trip.destinationLat, trip.destinationLon))) {
      items.add(RecentDestinationItem.savedTrip(trip));
    }
  }
  for (final entry in history) {
    if (seen.add(_pointKey(entry.lat, entry.lon))) {
      items.add(RecentDestinationItem.historyEntry(entry));
    }
  }

  items.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
  return items;
}

String _pointKey(double lat, double lon) =>
    '${lat.toStringAsFixed(4)}|${lon.toStringAsFixed(4)}';
