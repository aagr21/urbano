import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/location/place_search.dart';

Map<String, Object?> _feature(
  String name, {
  String key = 'highway',
  String value = 'secondary',
  String? district = 'Centro',
  String? street,
  String city = 'Santa Cruz de la Sierra',
  List<double> coords = const [-63.18, -17.77],
}) => {
  'geometry': {'coordinates': coords},
  'properties': {
    'name': name,
    'osm_key': key,
    'osm_value': value,
    'district': ?district,
    'street': ?street,
    'city': city,
  },
};

void main() {
  group('parsePhotonResults', () {
    test('una calle se lee como calle de su barrio', () {
      final out = parsePhotonResults({
        'features': [_feature('Avenida Monseñor Rivero')],
      });
      expect(out.single.name, 'Avenida Monseñor Rivero');
      expect(out.single.kind, PlaceKind.street);
      expect(out.single.subtitle, 'Centro');
      expect(out.single.lat, -17.77);
      expect(out.single.lon, -63.18);
    });

    test('descarta el ruido: pastos, límites y otras ciudades', () {
      final out = parsePhotonResults({
        'features': [
          _feature('Jardinera Monseñor Rivero', key: 'landuse', value: 'grass'),
          _feature('Santa Cruz', key: 'boundary', value: 'administrative'),
          _feature('Calle Sucre', city: 'Cochabamba'),
          _feature('Calle Sucre'),
        ],
      });
      expect(out.map((p) => p.name), ['Calle Sucre']);
    });

    test(
      'una sugerencia por nombre y zona (tramos, parada del mismo mall)',
      () {
        final out = parsePhotonResults({
          'features': [
            _feature('Ventura Mall', value: 'bus_stop'),
            _feature('Ventura Mall', key: 'shop', value: 'mall'),
            _feature('Avenida Busch'),
            _feature('Avenida Busch', coords: const [-63.17, -17.76]),
          ],
        });
        expect(out.map((p) => p.name), ['Ventura Mall', 'Avenida Busch']);
      },
    );

    test('un lugar lleva su calle y barrio como detalle', () {
      final out = parsePhotonResults({
        'features': [
          _feature(
            'Ventura Mall',
            key: 'shop',
            value: 'mall',
            street: 'Avenida Antonio Vaca Diez',
          ),
        ],
      });
      expect(out.single.kind, PlaceKind.poi);
      expect(out.single.subtitle, 'Avenida Antonio Vaca Diez · Centro');
    });

    test('respuesta inesperada no rompe: lista vacía', () {
      expect(parsePhotonResults(null), isEmpty);
      expect(parsePhotonResults({'features': 'x'}), isEmpty);
      expect(
        parsePhotonResults({
          'features': [
            {'properties': {}},
          ],
        }),
        isEmpty,
      );
    });
  });
}
