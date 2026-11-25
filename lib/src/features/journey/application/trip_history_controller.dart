import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/json_list_store.dart';
import '../data/trip_history.dart';
import '../domain/journey_place.dart';
import 'place_description.dart';

/// Puerto de persistencia del historial de viajes.
///
/// En la app real usa `shared_preferences`; los tests inyectan uno en memoria
/// (regla del repo: `flutter test` no toca plugins).
abstract interface class TripHistoryStore {
  Future<List<TripHistoryEntry>> load();
  Future<void> save(List<TripHistoryEntry> entries);
}

/// Historial local (`urbano.trips.recent`), como lista JSON.
class SharedPreferencesTripHistoryStore implements TripHistoryStore {
  static const JsonListStore<TripHistoryEntry> _store = JsonListStore(
    key: 'urbano.trips.recent',
    fromJson: TripHistoryEntry.fromJson,
    toJson: _toJson,
  );

  static Map<String, Object?> _toJson(TripHistoryEntry entry) => entry.toJson();

  @override
  Future<List<TripHistoryEntry>> load() => _store.load();

  @override
  Future<void> save(List<TripHistoryEntry> entries) => _store.save(entries);
}

/// Dueño del historial de viajes recientes del home: lo carga al arrancar y lo
/// alimenta cada vez que el planeador termina de calcular un viaje.
///
/// Deduplica por destino ([TripHistoryEntry.key]), conserva el más reciente
/// arriba y acota la lista para que el home no crezca sin fin.
class TripHistoryController extends AsyncNotifier<List<TripHistoryEntry>> {
  TripHistoryController([this._store]);

  final TripHistoryStore? _store;

  /// Fila máxima que guarda el home. La hoja «Ver todos» pagina de 8 en 8,
  /// así que el historial puede crecer holgadamente por encima de una página.
  static const int maxEntries = 30;

  TripHistoryStore get _resolvedStore =>
      _store ?? SharedPreferencesTripHistoryStore();

  @override
  Future<List<TripHistoryEntry>> build() async {
    final saved = await _resolvedStore.load();
    return _sorted(saved);
  }

  /// Anota un destino recién planificado.
  ///
  /// Se guarda por destino (no por par origen→destino): el viaje se vuelve a
  /// planificar desde donde esté el usuario cuando toca la fila del home.
  Future<void> record({
    required JourneyPlace destination,
    int? durationMinutes,
    DateTime? at,
  }) async {
    final point = destination.pointOrNull;
    if (point == null) return;
    final current = state.valueOrNull ?? await future;
    final described = describePlace(destination);
    final entry = TripHistoryEntry(
      label: described.label,
      subtitle: described.subtitle,
      lat: point.lat,
      lon: point.lon,
      lastUsed: at ?? DateTime.now(),
      durationMinutes: durationMinutes,
    );
    final next = _sorted([
      entry,
      ...current.where((saved) => saved.key != entry.key),
    ]);
    state = AsyncData(next);
    await _resolvedStore.save(next);
  }

  /// Elimina una entrada del historial.
  Future<void> remove(TripHistoryEntry entry) async {
    final current = state.valueOrNull ?? await future;
    final next = current.where((e) => e.key != entry.key).toList();
    state = AsyncData(next);
    await _resolvedStore.save(next);
  }

  /// Vacía el historial (ajuste futuro del usuario; también limpia los tests).
  Future<void> clear() async {
    state = const AsyncData([]);
    await _resolvedStore.save(const []);
  }

  static List<TripHistoryEntry> _sorted(List<TripHistoryEntry> entries) =>
      sortedByLastUsed(
        entries,
        (entry) => entry.lastUsed,
        maxEntries: maxEntries,
      );
}

/// Historial de viajes recientes (vive con la app, como el planeador).
final tripHistoryControllerProvider =
    AsyncNotifierProvider<TripHistoryController, List<TripHistoryEntry>>(
      TripHistoryController.new,
    );
