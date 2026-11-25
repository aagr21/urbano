import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/features/nearby/domain/nearby_micros.dart';
import 'package:urbano/src/features/stops/data/stop_search_models.dart';

/// Dominio puro de «Micros cerca»: agrupar paradas por línea y elegir, por
/// sentido, la parada más cercana donde subir.
void main() {
  const origin = LatLng(-17.7833, -63.1821);

  StopHit stop(
    String id,
    double meters,
    List<StopRouteRef> routes, {
    double lat = -17.7833,
    double lon = -63.1821,
  }) => StopHit(
    id: id,
    name: 'Parada $id',
    lat: lat,
    lon: lon,
    distanceMeters: meters,
    routes: routes,
  );

  StopRouteRef line(String id, List<int> directions) => StopRouteRef(
    id: id,
    shortName: id,
    color: 'D35400',
    directionIds: directions,
  );

  group('groupNearbyMicros', () {
    test('cada sentido sube en SU parada más cercana', () {
      final micros = groupNearbyMicros([
        stop('A', 120, [
          line('41', [0]),
        ]),
        stop('B', 80, [
          line('41', [1]),
        ]),
        stop('C', 300, [
          line('41', [0, 1]),
        ]),
      ], origin);

      expect(micros, hasLength(1));
      final micro = micros.single;
      expect(micro.boardingFor(0)!.stopId, 'A');
      expect(micro.boardingFor(1)!.stopId, 'B');
      expect(micro.nearest.stopId, 'B');
      expect(micro.distanceMeters, 80);
      expect(micro.hasBothDirections, isTrue);
    });

    test('un sentido que no pasa cerca no se inventa', () {
      final micro = groupNearbyMicros([
        stop('A', 90, [
          line('60', [1]),
        ]),
      ], origin).single;

      expect(micro.boardingFor(0), isNull);
      expect(micro.boardingFor(1)!.confirmed, isTrue);
      expect(micro.hasBothDirections, isFalse);
    });

    test('sin directionIds ofrece ambos sentidos SIN confirmar, y una '
        'parada confirmada le gana aunque esté más lejos', () {
      final micro = groupNearbyMicros([
        stop('viejo', 50, [line('17', const [])]),
        stop('nuevo', 200, [
          line('17', [0]),
        ]),
      ], origin).single;

      expect(micro.boardingFor(0)!.stopId, 'nuevo');
      expect(micro.boardingFor(0)!.confirmed, isTrue);
      expect(micro.boardingFor(1)!.stopId, 'viejo');
      expect(micro.boardingFor(1)!.confirmed, isFalse);
    });

    test('ordena por distancia y, a igualdad, por nombre', () {
      final micros = groupNearbyMicros([
        stop('A', 300, [
          line('9', [0]),
        ]),
        stop('B', 100, [
          line('75', [0]),
          line('10', [0]),
        ]),
      ], origin);

      expect(micros.map((m) => m.route.id), ['10', '75', '9']);
    });

    test('sin distanceMeters la mide desde el punto consultado', () {
      final micro = groupNearbyMicros([
        StopHit(
          id: 'X',
          name: 'X',
          lat: -17.7843,
          lon: -63.1821,
          routes: [
            line('1', [0]),
          ],
        ),
      ], origin).single;

      // 0,001° de latitud ≈ 111 m.
      expect(micro.distanceMeters, closeTo(111, 2));
    });

    test('paradas sin líneas no generan resultados', () {
      expect(groupNearbyMicros([stop('A', 10, const [])], origin), isEmpty);
    });
  });

  group('NearbyBoarding.walkMinutes', () {
    NearbyBoarding at(double meters) => NearbyBoarding(
      directionId: 0,
      stopId: 's',
      stopName: 's',
      point: origin,
      distanceMeters: meters,
    );

    test('a 4,5 km/h y nunca menos de 1 minuto', () {
      expect(at(10).walkMinutes, 1);
      expect(at(75).walkMinutes, 1);
      expect(at(76).walkMinutes, 2);
      expect(at(450).walkMinutes, 6);
    });
  });

  group('NearbyQuery', () {
    test('ida y vuelta por la URL', () {
      const query = NearbyQuery(
        lat: -17.7833,
        lon: -63.1821,
        label: 'Plaza 24 de Septiembre',
        radiusMeters: 1000,
      );
      expect(NearbyQuery.fromParams(query.toParams()), query);
    });

    test('sin punto no hay consulta; radio fuera de rango se acota', () {
      expect(NearbyQuery.fromParams(const {'lat': '-17.7'}), isNull);
      final q = NearbyQuery.fromParams(const {
        'lat': '-17.7',
        'lon': '-63.1',
        'r': '9000',
      })!;
      expect(q.radiusMeters, 2000);
      expect(q.label, 'Punto elegido');
    });
  });

  test('formatNearbyDistance redondea a decenas y pasa a km', () {
    expect(formatNearbyDistance(4), '10 m');
    expect(formatNearbyDistance(123), '120 m');
    expect(formatNearbyDistance(500), '500 m');
    expect(formatNearbyDistance(1000), '1 km');
    expect(formatNearbyDistance(1234), '1,2 km');
  });

  test('arrowSpacingFor: 200 m en tramos cortos, ≤ ~45 flechas en largos', () {
    expect(arrowSpacingFor(1500), 200);
    expect(arrowSpacingFor(18000), 400);
  });

  test('circlePath cierra el aro a la distancia pedida', () {
    final ring = circlePath(origin, 500, steps: 12);
    expect(ring, hasLength(13));
    expect(ring.first.latitude, closeTo(ring.last.latitude, 1e-9));
    const distance = Distance();
    for (final p in ring) {
      expect(distance(origin, p), closeTo(500, 1));
    }
  });
}
