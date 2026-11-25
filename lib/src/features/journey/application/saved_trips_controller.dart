import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/json_list_store.dart';
import '../data/saved_trips.dart';
import '../domain/journey_place.dart';
import 'place_description.dart';

/// Puerto de persistencia de los viajes guardados.
///
/// En la app real usa `shared_preferences`; los tests inyectan uno en memoria.
abstract interface class SavedTripsStore {
  Future<List<SavedTrip>> load();
  Future<void> save(List<SavedTrip> trips);
}

/// Almacenamiento local (`urbano.trips.saved`), como lista JSON.
class SharedPreferencesSavedTripsStore implements SavedTripsStore {
  static const JsonListStore<SavedTrip> _store = JsonListStore(
    key: 'urbano.trips.saved',
    fromJson: SavedTrip.fromJson,
    toJson: _toJson,
  );

  static Map<String, Object?> _toJson(SavedTrip trip) => trip.toJson();

  @override
  Future<List<SavedTrip>> load() => _store.load();

  @override
  Future<void> save(List<SavedTrip> trips) => _store.save(trips);
}

/// Controlador de viajes guardados: pares origen→destino que el usuario
/// quiere reactivar rápido.
///
/// Deduplica por clave completa (origen + destino), conserva el más reciente
/// arriba y acota la lista a [maxEntries].
class SavedTripsController extends AsyncNotifier<List<SavedTrip>> {
  SavedTripsController([this._store]);

  final SavedTripsStore? _store;

  static const int maxEntries = 10;

  SavedTripsStore get _resolvedStore =>
      _store ?? SharedPreferencesSavedTripsStore();

  @override
  Future<List<SavedTrip>> build() async {
    final saved = await _resolvedStore.load();
    return _sorted(saved);
  }

  /// Agrega un viaje completo (origen + destino).
  Future<void> add({
    required JourneyPlace origin,
    required JourneyPlace destination,
    int? durationMinutes,
    DateTime? at,
  }) async {
    final oPoint = origin.pointOrNull;
    final dPoint = destination.pointOrNull;
    if (oPoint == null || dPoint == null) return;

    final oDesc = describePlace(origin);
    final dDesc = describePlace(destination);

    final trip = SavedTrip(
      originLabel: oDesc.label,
      originLat: oPoint.lat,
      originLon: oPoint.lon,
      destinationLabel: dDesc.label,
      destinationSubtitle: dDesc.subtitle,
      destinationLat: dPoint.lat,
      destinationLon: dPoint.lon,
      lastUsed: at ?? DateTime.now(),
      durationMinutes: durationMinutes,
    );

    final current = state.valueOrNull ?? await future;
    final next = _sorted([trip, ...current.where((t) => t.key != trip.key)]);
    state = AsyncData(next);
    await _resolvedStore.save(next);
  }

  /// Elimina un viaje guardado.
  Future<void> remove(SavedTrip trip) async {
    final current = state.valueOrNull ?? await future;
    final next = current.where((t) => t.key != trip.key).toList();
    state = AsyncData(next);
    await _resolvedStore.save(next);
  }

  /// Vacía la lista de viajes guardados.
  Future<void> clear() async {
    state = const AsyncData([]);
    await _resolvedStore.save(const []);
  }

  static List<SavedTrip> _sorted(List<SavedTrip> trips) =>
      sortedByLastUsed(trips, (trip) => trip.lastUsed, maxEntries: maxEntries);
}

/// Lista de viajes guardados (vive con la app).
final savedTripsControllerProvider =
    AsyncNotifierProvider<SavedTripsController, List<SavedTrip>>(
      SavedTripsController.new,
    );
