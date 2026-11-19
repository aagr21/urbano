import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/trip_history.dart';
import '../domain/journey_place.dart';

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
  static const _key = 'urbano.trips.recent';

  @override
  Future<List<TripHistoryEntry>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(TripHistoryEntry.fromJson)
          .whereType<TripHistoryEntry>()
          .toList(growable: false);
    } catch (_) {
      // Sin plugin (test) o store corrupto: el home simplemente no muestra la
      // sección y la app sigue funcionando.
      return const [];
    }
  }

  @override
  Future<void> save(List<TripHistoryEntry> entries) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _key,
        jsonEncode([for (final entry in entries) entry.toJson()]),
      );
    } catch (_) {
      // La persistencia es opcional: el historial vive igual en memoria.
    }
  }
}

/// Dueño del historial de viajes recientes del home: lo carga al arrancar y lo
/// alimenta cada vez que el planeador termina de calcular un viaje.
///
/// Deduplica por destino ([TripHistoryEntry.key]), conserva el más reciente
/// arriba y acota la lista para que el home no crezca sin fin.
class TripHistoryController extends AsyncNotifier<List<TripHistoryEntry>> {
  TripHistoryController([this._store]);

  final TripHistoryStore? _store;

  /// Fila máxima que guarda el home.
  static const int maxEntries = 6;

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
    final described = _describe(destination);
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

  /// Vacía el historial (ajuste futuro del usuario; también limpia los tests).
  Future<void> clear() async {
    state = const AsyncData([]);
    await _resolvedStore.save(const []);
  }

  static List<TripHistoryEntry> _sorted(List<TripHistoryEntry> entries) {
    final list = [...entries]..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
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

/// Historial de viajes recientes (vive con la app, como el planeador).
final tripHistoryControllerProvider =
    AsyncNotifierProvider<TripHistoryController, List<TripHistoryEntry>>(
      TripHistoryController.new,
    );
