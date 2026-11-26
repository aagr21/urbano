import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';

RouteDetail _detail(List<String> headsigns) => RouteDetail(
  id: '17',
  shortName: '17',
  longName: '',
  color: '7F8C8D',
  textColor: 'FFFFFF',
  description: '',
  type: 3,
  directionsCount: headsigns.length,
  stopCount: 10,
  tripCount: 2,
  bbox: const [],
  directions: [
    for (var i = 0; i < headsigns.length; i++)
      RouteDirection(
        directionId: i,
        headsign: headsigns[i],
        tripId: 'T$i',
        firstDeparture: '06:00:00',
        lastDeparture: '22:00:00',
        headwaySeconds: 600,
        stopCount: 10,
      ),
  ],
  shape: null,
);

/// Headsign que vale la pena mostrar junto al sentido elegido.
void main() {
  test('un destino con nombre real se muestra', () {
    expect(meaningfulHeadsign(_detail(['Plan 3000', 'Centro']), 1), 'Centro');
  });

  test('«Ida»/«Vuelta» o vacío no dicen nada', () {
    final detail = _detail([' IDA ', '']);
    expect(meaningfulHeadsign(detail, 0), isNull);
    expect(meaningfulHeadsign(detail, 1), isNull);
  });

  test('sin detalle o sentido inexistente, nada', () {
    expect(meaningfulHeadsign(null, 0), isNull);
    expect(meaningfulHeadsign(_detail(['Centro']), 5), isNull);
  });
}
