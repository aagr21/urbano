import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/presentation/widgets/route_places.dart';

RouteStop _stop(int sequence, String name) => RouteStop(
  id: 'S$sequence',
  name: name,
  lat: -17.78,
  lon: -63.16,
  sequence: sequence,
);

List<RouteStop> _brasilRun() => [
  for (var i = 1; i <= 20; i++)
    _stop(i, 'Avenida Brasil esquina Calle ${i * 100}'),
];

void main() {
  group('RoutePlaces.mainPlaces · heurística de lugares principales', () {
    test(
      'vías de refuerzo: la recurrente gana y sale primera (geográfica)',
      () {
        final result = RoutePlaces.mainPlaces(_brasilRun());
        expect(result.first, 'Avenida Brasil');
        expect(result.length, lessThanOrEqualTo(10));
      },
    );

    test('el «esquina» separa dos vías y ambas cuentan como candidatos', () {
      final result = RoutePlaces.mainPlaces([
        _stop(1, 'Cuarto Anillo esquina Radial 12'),
        _stop(2, 'Tercer Anillo esquina Radial 12'),
        _stop(3, 'Cuarto Anillo esquina Radial 27'),
      ]);
      expect(
        result.toSet(),
        containsAll(<String>['Cuarto Anillo', 'Radial 12']),
      );
    });

    test('tope de 10 lugares aunque haya más vías recurrentes', () {
      final stops = [
        for (var i = 1; i <= 20; i++)
          _stop(i, 'Vía ${i % 10} esquina Calle ${i % 9}'),
      ];
      expect(RoutePlaces.mainPlaces(stops).length, 10);
    });

    test('un hito conocido vale doble aunque el micro pase pocas veces', () {
      final result = RoutePlaces.mainPlaces([
        for (var i = 1; i <= 8; i++)
          _stop(i, 'Calle Común $i esquina Avenida Relleno'),
        // «Terminal Bimodal» solo aparece 2 veces pero ES el destino.
        _stop(9, 'Avenida Relleno esquina Terminal Bimodal'),
        _stop(10, 'Terminal Bimodal esquina Calle Común 1'),
      ]);
      expect(result, contains('Terminal Bimodal'));
    });

    test('variantes del mismo vía (« - » vs «-») cuentan como UNA', () {
      final result = RoutePlaces.mainPlaces([
        for (var i = 1; i <= 10; i++)
          _stop(i, 'Doble Vía Santa Cruz - La Guardia esquina Calle $i'),
        _stop(11, 'Otra Calle esquina Doble Vía Santa Cruz-La Guardia'),
      ]);
      expect(result.where((p) => p.startsWith('Doble Vía')), hasLength(1));
    });

    test('lista vacía ⇒ vacía, sin error', () {
      expect(RoutePlaces.mainPlaces(const []), isEmpty);
    });

    test('nombres sin «esquina» se conservan íntegros (uno cada uno)', () {
      final result = RoutePlaces.mainPlaces([
        _stop(1, 'Terminal Bimodal'),
        _stop(2, 'Terminal Bimodal'),
      ]);
      expect(result, ['Terminal Bimodal']);
    });
  });
}
