import 'dart:math' as math;

import 'package:flutter/painting.dart' show Color;

import '../../../core/theme/app_colors.dart';
import '../data/journey_models.dart';

/// Colores de dibujo de los tramos de un viaje (mapa, tarjeta, leyenda,
/// galería de micros): una sola regla para que nunca diverjan.
abstract final class LegStrokeColors {
  /// Color de los tramos a pie (trazo punteado del mapa y su leyenda). Entra
  /// en el reparto de colores: ningún micro puede confundirse con él.
  static const Color walk = Color(0xFF94A3B8);

  /// Distancia perceptual mínima ("redmean", 0-765) para que dos trazos se
  /// lean como colores distintos. Dos naranjas GTFS parecidos (`D35400` vs
  /// `E67E22`) quedan en ~103: por debajo de este umbral se separan.
  static const double minDistance = 120;

  /// Colores de dibujo de los tramos de micro de un viaje: **cada tramo de
  /// micro lleva un color distinto** de los demás tramos (y del gris de la
  /// caminata), para que en el mapa, la tarjeta y la leyenda no se confundan.
  ///
  /// - El primer tramo conserva su color GTFS (identidad de la línea) salvo
  ///   que se confunda con la caminata.
  /// - Cada tramo siguiente conserva el suyo si se distingue de todos los ya
  ///   asignados; si no (mismo color o uno muy parecido: no basta comparar el
  ///   hex exacto), toma el primero de la paleta que sí se distingue.
  ///
  /// Devuelve solo los tramos que cambian: índice en [legs] → hex sin `#`.
  static Map<int, String> forLegs(List<JourneyLeg> legs) {
    final assigned = <Color>[walk];
    final legAltColors = <int, String>{};
    const palette = _palette;
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      if (!leg.isBus) continue;
      final own = AppColors.fromHex(leg.routeColor);
      if (_isDistinct(own, assigned)) {
        assigned.add(own);
        continue;
      }
      final alt = palette.firstWhere(
        (hex) => _isDistinct(AppColors.fromHex(hex), assigned),
        // Más tramos que colores distinguibles (no ocurre con 1 transbordo):
        // se rota la paleta antes que repetir el color propio.
        orElse: () => palette[legAltColors.length % palette.length],
      );
      legAltColors[i] = alt;
      assigned.add(AppColors.fromHex(alt));
    }
    return legAltColors;
  }

  static bool _isDistinct(Color color, List<Color> others) =>
      others.every((o) => distance(color, o) >= minDistance);

  /// Distancia de color "redmean": aproximación barata a la percepción humana
  /// (pondera el verde y corrige rojo/azul según la luminosidad del rojo).
  static double distance(Color a, Color b) {
    final r1 = (a.r * 255).round();
    final r2 = (b.r * 255).round();
    final dr = (r1 - r2).toDouble();
    final dg = ((a.g - b.g) * 255).toDouble();
    final db = ((a.b - b.b) * 255).toDouble();
    final rMean = (r1 + r2) / 2;
    return math.sqrt(
      (2 + rMean / 256) * dr * dr +
          4 * dg * dg +
          (2 + (255 - rMean) / 256) * db * db,
    );
  }

  /// Paleta de colores alternativos para distinguir tramos de micro cuyo
  /// color GTFS se repite o se parece al de otro tramo del mismo viaje.
  static const List<String> _palette = [
    'E53935', // rojo
    '1E88E5', // azul
    '43A047', // verde
    'FB8C00', // naranja
    '8E24AA', // púrpura
    'D81B60', // rosa
    '00ACC1', // cian
    '7CB342', // verde claro
    'FDD835', // amarillo
    '6D4C41', // marrón
  ];
}
