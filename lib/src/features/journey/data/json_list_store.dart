import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lista de entidades serializables guardada como JSON en `shared_preferences`.
///
/// Es la pieza común del historial (`urbano.trips.recent`) y de los viajes
/// guardados (`urbano.trips.saved`): mismo formato, mismo manejo silencioso de
/// fallos. Debajo de `flutter test` no hay plugin, así que `load` devuelve una
/// lista vacía y `save` no hace nada; la app sigue funcionando igual porque el
/// estado vive en memoria. Un JSON viejo o corrupto descarta **esa fila**,
/// nunca la pantalla entera.
class JsonListStore<T> {
  const JsonListStore({
    required this.key,
    required this.fromJson,
    required this.toJson,
  });

  final String key;
  final T? Function(Object? raw) fromJson;
  final Map<String, Object?> Function(T item) toJson;

  Future<List<T>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map(fromJson).whereType<T>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<T> items) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        key,
        jsonEncode([for (final item in items) toJson(item)]),
      );
    } catch (_) {
      // La persistencia es opcional: el estado vive igual en memoria.
    }
  }
}
