import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/theme/app_colors.dart';
import 'package:urbano/src/features/journey/application/journey_map_geometry.dart';
import 'package:urbano/src/features/journey/application/leg_stroke_colors.dart';
import 'package:urbano/src/features/journey/data/journey_models.dart';

/// Tramo de micro mínimo con color GTFS y (opcional) trazado `[lon, lat]`.
Map<String, dynamic> _bus(
  String route,
  String? color, {
  List<List<double>>? coords,
  Map<String, dynamic>? fromStop,
  Map<String, dynamic>? toStop,
}) => {
  'kind': 'bus',
  'routeId': route,
  'routeShortName': route,
  'routeColor': color,
  'tripId': 'T$route',
  'fromStop': ?fromStop,
  'toStop': ?toStop,
  if (coords != null) 'geometry': {'type': 'LineString', 'coordinates': coords},
};

const _walk = {'kind': 'walk', 'distanceMeters': 100};

List<JourneyLeg> _legs(List<Map<String, dynamic>> raw) =>
    raw.map(JourneyLeg.fromJson).toList();

/// Color con el que se dibuja cada tramo de micro (alternativo o GTFS).
List<String> _strokes(List<JourneyLeg> legs) {
  final alt = LegStrokeColors.forLegs(legs);
  return [
    for (var i = 0; i < legs.length; i++)
      if (legs[i].isBus) alt[i] ?? legs[i].routeColor ?? '',
  ];
}

void main() {
  group('colores de los tramos de micro', () {
    void expectAllDistinct(List<JourneyLeg> legs) {
      final colors = _strokes(legs).map(AppColors.fromHex).toList();
      final all = [LegStrokeColors.walk, ...colors];
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          expect(
            LegStrokeColors.distance(all[i], all[j]),
            greaterThanOrEqualTo(LegStrokeColors.minDistance),
            reason: 'trazos $i y $j se confunden',
          );
        }
      }
    }

    test('dos micros con el MISMO color GTFS se separan', () {
      final legs = _legs([
        _walk,
        _bus('8', 'D35400'),
        _bus('10', 'D35400'),
        _walk,
      ]);
      expectAllDistinct(legs);
      // El primero conserva la identidad de su línea.
      expect(_strokes(legs).first, 'D35400');
    });

    test('colores MUY parecidos (no idénticos) también se separan', () {
      // Dos naranjas GTFS: antes solo se comparaba el hex exacto.
      final legs = _legs([_bus('8', 'D35400'), _bus('10', 'E67E22')]);
      expectAllDistinct(legs);
    });

    test('el color alternativo no repite el de otro tramo', () {
      // 8 y 10 comparten color; 72 ya es rojo E53935 (el primero de la
      // paleta): el alternativo de 10 no puede ser ese rojo.
      final legs = _legs([
        _bus('72', 'E53935'),
        _bus('8', '1E88E5'),
        _bus('10', '1E88E5'),
      ]);
      expectAllDistinct(legs);
    });

    test('un micro gris no se confunde con la caminata', () {
      final legs = _legs([_walk, _bus('8', '9AA5B5'), _walk]);
      expectAllDistinct(legs);
    });

    test('colores ya distintos se respetan tal cual', () {
      final legs = _legs([_bus('8', 'D35400'), _bus('10', '1E88E5')]);
      expect(LegStrokeColors.forLegs(legs), isEmpty);
    });
  });

  group('hueco del transbordo', () {
    const stopX = {'id': 'X', 'name': 'X', 'lat': -17.7800, 'lon': -63.1500};

    test('micro → micro sin caminata: se une con un tramo a pie', () {
      // El micro A acaba en su calzada (al oeste de la parada) y B empieza en
      // la de enfrente (al este): sin conector quedaba un hueco vacío.
      final legs = _legs([
        _bus(
          'A',
          'D35400',
          coords: [
            [-63.1600, -17.7800],
            [-63.15015, -17.7800],
          ],
          toStop: stopX,
        ),
        _bus(
          'B',
          '1E88E5',
          coords: [
            [-63.14985, -17.7800],
            [-63.1400, -17.7900],
          ],
          fromStop: stopX,
        ),
      ]);
      final connectors = JourneyMapGeometry.transferConnectors(legs);
      expect(connectors, hasLength(1));
      expect(connectors.single.first, const LatLng(-17.78, -63.15015));
      expect(connectors.single[1], const LatLng(-17.78, -63.15));
      expect(connectors.single.last, const LatLng(-17.78, -63.14985));
    });

    test('con una caminata explícita entre micros no se duplica', () {
      final legs = _legs([
        _bus(
          'A',
          'D35400',
          coords: [
            [-63.16, -17.78],
            [-63.15, -17.78],
          ],
        ),
        _walk,
        _bus(
          'B',
          '1E88E5',
          coords: [
            [-63.149, -17.78],
            [-63.14, -17.79],
          ],
        ),
      ]);
      expect(JourneyMapGeometry.transferConnectors(legs), isEmpty);
    });

    test('trazados que ya se tocan no generan conector', () {
      final legs = _legs([
        _bus(
          'A',
          'D35400',
          coords: [
            [-63.16, -17.78],
            [-63.15, -17.78],
          ],
        ),
        _bus(
          'B',
          '1E88E5',
          coords: [
            [-63.15, -17.78],
            [-63.14, -17.79],
          ],
        ),
      ]);
      expect(JourneyMapGeometry.transferConnectors(legs), isEmpty);
    });
  });
}
