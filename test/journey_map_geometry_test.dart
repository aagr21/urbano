import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/features/journey/application/journey_map_geometry.dart';
import 'package:urbano/src/features/journey/data/journey_models.dart';

import 'helpers/journey_fixtures.dart';

JourneyLeg _bus(List<List<double>> coords, {Map<String, dynamic>? fromStop}) =>
    JourneyLeg.fromJson({
      'kind': 'bus',
      'routeId': '1',
      'routeShortName': '1',
      'routeColor': 'D35400',
      'tripId': 'T1',
      'fromStop': ?fromStop,
      'geometry': {'type': 'LineString', 'coordinates': coords},
    });

JourneyLeg _walk() =>
    JourneyLeg.fromJson(const {'kind': 'walk', 'distanceMeters': 80});

/// Geometría del viaje en el mapa, sin widgets.
void main() {
  group('joinWalkToBus', () {
    // El micro empieza en la calzada, ~15 m al este del final de la caminata.
    final bus = _bus([
      [-63.15000, -17.78000],
      [-63.14000, -17.79000],
    ]);

    test('cose la caminata al trazado del micro siguiente si está cerca', () {
      const walkEnd = LatLng(-17.78, -63.15014); // ~15 m
      final joined = JourneyMapGeometry.joinWalkToBus(
        [const LatLng(-17.77, -63.16), walkEnd],
        [_walk(), bus],
        0,
      );
      expect(joined.last, const LatLng(-17.78, -63.15));
      expect(joined.first, const LatLng(-17.77, -63.16), reason: 'no se toca');
    });

    test('un hueco real (> 60 m) no se inventa', () {
      const far = LatLng(-17.78, -63.152); // ~210 m
      final joined = JourneyMapGeometry.joinWalkToBus(
        [const LatLng(-17.77, -63.16), far],
        [_walk(), bus],
        0,
      );
      expect(joined.last, far);
    });

    test('con un solo punto no hace nada', () {
      final single = [const LatLng(1, 2)];
      expect(JourneyMapGeometry.joinWalkToBus(single, [bus], -1), same(single));
    });
  });

  group('straightWalkSegment', () {
    const origin = LatLng(-17.77, -63.16);
    const destination = LatLng(-17.80, -63.13);
    final busLeg = _bus(
      [
        [-63.15, -17.78],
        [-63.14, -17.79],
      ],
      fromStop: {'id': 'S', 'name': 'Subida', 'lat': -17.78, 'lon': -63.15},
    );

    test('acceso: pin de origen → parada de subida', () {
      final legs = [_walk(), busLeg];
      final option = fixtureDirectOption();
      expect(
        JourneyMapGeometry.straightWalkSegment(
          option,
          legs,
          0,
          origin,
          destination,
        ),
        [origin, const LatLng(-17.78, -63.15)],
      );
    });

    test('egreso: termina en el pin de destino', () {
      final legs = [busLeg, _walk()];
      final segment = JourneyMapGeometry.straightWalkSegment(
        fixtureDirectOption(),
        legs,
        1,
        origin,
        destination,
      );
      expect(segment?.last, destination);
    });
  });

  test('fitPoints incluye los pines y todo el trazado', () {
    const origin = LatLng(-17.77, -63.16);
    const destination = LatLng(-17.80, -63.13);
    final points = JourneyMapGeometry.fitPoints(
      fixtureDirectOption(),
      origin,
      destination,
    );
    expect(points.take(2), [origin, destination]);
    expect(points.length, greaterThan(2));
  });

  test('walkPaths de una opción con transbordo trae caminatas punteadas', () {
    final paths = JourneyMapGeometry.walkPaths(
      fixtureTransferOption(),
      const LatLng(-17.77, -63.16),
      const LatLng(-17.80, -63.13),
    );
    expect(paths, isNotEmpty);
    expect(paths.every((p) => p.length >= 2), isTrue);
  });
}
