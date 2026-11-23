import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/saved_trips.dart';
import '../domain/journey_place.dart';

/// Puerto de persistencia de los viajes guardados.
///
/// En la app real usa `shared_preferences`; los tests inyectan uno en memoria.
abstract interface class SavedTripsStore {
  Future<List<SavedTrip>> load();
  Future<void> save(List<SavedTrip> trips);
}

/// Almacenamiento local (`urbano.trips.saved`), como lista JSON.
class SharedPreferencesSavedTripsStore implements SavedTripsStore {
  static const _key = 'urbano.trips.saved';

  @override
  Future<List<SavedTrip>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(SavedTrip.fromJson)
          .whereType<SavedTrip>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<SavedTrip> trips) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _key,
        jsonEncode([for (final t in trips) t.toJson()]),
      );
    } catch (_) {}
  }
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

    final oDesc = _describe(origin);
    final dDesc = _describe(destination);

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

  static List<SavedTrip> _sorted(List<SavedTrip> trips) {
    final list = [...trips]..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return list.length <= maxEntries ? list : list.sublist(0, maxEntries);
  }

  static ({String label, String? subtitle}) _describe(JourneyPlace place) {
    return switch (place) {
      JourneyPlacePoi(:final name, :final subtitle) => (
        label: name,
        subtitle: subtitle == null || subtitle.trim().isEmpty
            ? 'Lugar de Santa Cruz'
            : subtitle,
      ),
      JourneyPlacePoint(:final address, :final lat, :final lon) => (
        label:
            address ?? '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
        subtitle: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
      ),
      JourneyPlaceLocation(:final address, :final lat, :final lon) => (
        label: address ?? 'Mi ubicación',
        subtitle: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
      ),
    };
  }
}

/// Lista de viajes guardados (vive con la app).
final savedTripsControllerProvider =
    AsyncNotifierProvider<SavedTripsController, List<SavedTrip>>(
      SavedTripsController.new,
    );
