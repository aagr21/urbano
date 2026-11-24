import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/features/journey/domain/route_arrows.dart';

void main() {
  const distance = Distance();

  group('arrowsAlongPath', () {
    test('un tramo recto de 1 km recibe 5 flechas cada 200 m y termina '
        '(regresión: un segmento ≥ espaciado colgaba el hilo de UI)', () {
      const a = LatLng(-17.78, -63.18);
      final b = distance.offset(a, 1000, 0);
      final arrows = arrowsAlongPath([a, b], 200);

      expect(arrows, hasLength(5));
      for (var i = 0; i < arrows.length; i++) {
        expect(distance(a, arrows[i].point), closeTo(200.0 * (i + 1), 1));
        expect(arrows[i].bearing, closeTo(0, 0.5));
      }
    });

    test('el sobrante de un segmento corto se arrastra al siguiente', () {
      const a = LatLng(-17.78, -63.18);
      final b = distance.offset(a, 150, 90); // 150 m al este
      final c = distance.offset(b, 150, 90); // 300 m en total
      final arrows = arrowsAlongPath([a, b, c], 200);

      expect(arrows, hasLength(1));
      expect(distance(a, arrows.single.point), closeTo(200, 1));
      expect(arrows.single.bearing, closeTo(90, 0.5));
    });

    test('cada flecha toma el rumbo de su propio segmento, también en una '
        'curva cerrada', () {
      const a = LatLng(-17.78, -63.18);
      final b = distance.offset(a, 400, 0); // norte
      final c = distance.offset(b, 400, 90); // luego este
      final arrows = arrowsAlongPath([a, b, c], 200);

      expect(arrows.map((x) => x.bearing.round()), [0, 0, 90, 90]);
    });

    test('entradas degeneradas devuelven vacío sin colgarse', () {
      const a = LatLng(-17.78, -63.18);
      final b = distance.offset(a, 500, 0);
      expect(arrowsAlongPath([a], 200), isEmpty);
      expect(arrowsAlongPath([a, a, a], 200), isEmpty);
      expect(arrowsAlongPath([a, b], 0), isEmpty);
      expect(arrowsAlongPath([a, b], -5), isEmpty);
    });
  });
}
