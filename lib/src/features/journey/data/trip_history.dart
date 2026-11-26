import 'package:flutter/foundation.dart';

/// Destino de un viaje ya planificado, guardado para el home.
///
/// Es dato puro: no guarda el origen ni la hora de salida (el viaje se vuelve a
/// planificar desde donde esté el usuario cuando toca la fila), solo **a dónde
/// fue**, cuánto tardó la última vez y cuándo fue.
@immutable
class TripHistoryEntry {
  const TripHistoryEntry({
    required this.label,
    this.subtitle,
    required this.lat,
    required this.lon,
    required this.lastUsed,
    this.durationMinutes,
  });

  /// Nombre del destino tal como lo mostró el planeador.
  final String label;

  /// Contexto del destino (zona/anillo del hito, coordenadas del punto…).
  final String? subtitle;

  final double lat;
  final double lon;
  final DateTime lastUsed;

  /// Duración de la última planificación, si se llegó a calcular.
  final int? durationMinutes;

  /// Identidad de deduplicación: mismo nombre y mismo punto.
  String get key =>
      '${label.toLowerCase()}|${lat.toStringAsFixed(4)}|${lon.toStringAsFixed(4)}';

  Map<String, Object?> toJson() => {
    'label': label,
    if (subtitle != null && subtitle!.trim().isNotEmpty) 'subtitle': subtitle,
    'lat': lat,
    'lon': lon,
    'lastUsed': lastUsed.toIso8601String(),
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
  };

  /// Reconstruye una entrada del almacenamiento local.
  ///
  /// Devuelve `null` ante cualquier campo inválido: un JSON viejo o corrupto
  /// descarta ESA fila, nunca la pantalla entera.
  static TripHistoryEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final label = raw['label'];
    final lat = raw['lat'];
    final lon = raw['lon'];
    final used = switch (raw['lastUsed']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    };
    if (label is! String || label.trim().isEmpty) return null;
    if (lat is! num || lon is! num || used == null) return null;
    final subtitle = raw['subtitle'];
    final duration = raw['durationMinutes'];
    return TripHistoryEntry(
      label: label,
      subtitle: subtitle is String && subtitle.trim().isNotEmpty
          ? subtitle
          : null,
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      lastUsed: used,
      durationMinutes: duration is num ? duration.toInt() : null,
    );
  }
}

/// Filas del historial cuyo nombre o contexto contienen [query] (sin
/// distinguir mayúsculas). Sin texto, todas.
List<TripHistoryEntry> filterTripHistory(
  List<TripHistoryEntry> entries,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return entries;
  return entries
      .where(
        (entry) =>
            entry.label.toLowerCase().contains(q) ||
            (entry.subtitle?.toLowerCase().contains(q) ?? false),
      )
      .toList(growable: false);
}
