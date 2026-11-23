import 'package:flutter/foundation.dart';

/// Viaje completo guardado localmente (origen + destino).
///
/// A diferencia de [TripHistoryEntry], que solo guarda el destino, esto
/// conserva el par origen→destino para que el usuario pueda reactivar
/// un viaje completo con un toque.
@immutable
class SavedTrip {
  const SavedTrip({
    required this.originLabel,
    required this.originLat,
    required this.originLon,
    required this.destinationLabel,
    required this.destinationSubtitle,
    required this.destinationLat,
    required this.destinationLon,
    required this.lastUsed,
    this.durationMinutes,
  });

  final String originLabel;
  final double originLat;
  final double originLon;
  final String destinationLabel;
  final String? destinationSubtitle;
  final double destinationLat;
  final double destinationLon;
  final DateTime lastUsed;
  final int? durationMinutes;

  /// Identidad de deduplicación: mismo origen y mismo destino.
  String get key =>
      '${originLabel.toLowerCase()}|${originLat.toStringAsFixed(4)}|${originLon.toStringAsFixed(4)}|'
      '${destinationLabel.toLowerCase()}|${destinationLat.toStringAsFixed(4)}|${destinationLon.toStringAsFixed(4)}';

  Map<String, Object?> toJson() => {
    'originLabel': originLabel,
    'originLat': originLat,
    'originLon': originLon,
    'destinationLabel': destinationLabel,
    if (destinationSubtitle != null && destinationSubtitle!.trim().isNotEmpty)
      'destinationSubtitle': destinationSubtitle,
    'destinationLat': destinationLat,
    'destinationLon': destinationLon,
    'lastUsed': lastUsed.toIso8601String(),
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
  };

  /// Reconstruye un viaje guardado del almacenamiento local.
  ///
  /// Devuelve `null` ante cualquier campo inválido: un JSON viejo o corrupto
  /// descarta ESA fila, nunca la pantalla entera.
  static SavedTrip? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final oLabel = raw['originLabel'];
    final oLat = raw['originLat'];
    final oLon = raw['originLon'];
    final dLabel = raw['destinationLabel'];
    final dLat = raw['destinationLat'];
    final dLon = raw['destinationLon'];
    final used = switch (raw['lastUsed']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    };
    if (oLabel is! String ||
        dLabel is! String ||
        oLat is! num ||
        oLon is! num ||
        dLat is! num ||
        dLon is! num ||
        used == null) {
      return null;
    }
    final dSub = raw['destinationSubtitle'];
    final dur = raw['durationMinutes'];
    return SavedTrip(
      originLabel: oLabel,
      originLat: oLat.toDouble(),
      originLon: oLon.toDouble(),
      destinationLabel: dLabel,
      destinationSubtitle: dSub is String && dSub.trim().isNotEmpty
          ? dSub
          : null,
      destinationLat: dLat.toDouble(),
      destinationLon: dLon.toDouble(),
      lastUsed: used,
      durationMinutes: dur is num ? dur.toInt() : null,
    );
  }
}
