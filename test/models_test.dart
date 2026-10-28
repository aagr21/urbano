import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/network/api_client.dart';
import 'package:urbano/src/features/home/data/stats.dart';
import 'package:urbano/src/features/journey/data/journey_models.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';

void main() {
  group('RouteSummary', () {
    test('fromJson lee el item del contrato (directions numérico)', () {
      final route = RouteSummary.fromJson(const {
        'id': '101 ANGOSTURA',
        'shortName': '101 ANGOSTURA',
        'longName': 'Micro 101 ANGOSTURA',
        'color': '7F8C8D',
        'textColor': 'FFFFFF',
        'description': 'Transporte publico urbano de micros',
        'type': 3,
        'directions': 2,
        'stopCount': 84,
        'tripCount': 2,
      });

      expect(route.id, '101 ANGOSTURA');
      expect(route.shortName, '101 ANGOSTURA');
      expect(route.longName, 'Micro 101 ANGOSTURA');
      expect(route.color, '7F8C8D');
      expect(route.textColor, 'FFFFFF');
      expect(route.type, 3);
      expect(route.directionsCount, 2);
      expect(route.stopCount, 84);
      expect(route.tripCount, 2);
    });

    test('directions como lista (detalle) cuenta direcciones', () {
      final route = RouteSummary.fromJson(const {
        'id': 'R1',
        'shortName': 'R1',
        'longName': 'Micro R1',
        'color': '000000',
        'textColor': 'FFFFFF',
        'type': 3,
        'directions': [
          {'directionId': 0, 'headsign': 'Ida'},
          {'directionId': 1, 'headsign': 'Vuelta'},
        ],
      });
      expect(route.directionsCount, 2);
    });

    test('campos ausentes caen en defaults sanos', () {
      final route = RouteSummary.fromJson(const {});
      expect(route.id, '');
      expect(route.color, '64748B');
      expect(route.stopCount, 0);
      expect(route.directionsCount, 0);
    });

    test('toJson conserva los campos', () {
      const json = {
        'id': 'A',
        'shortName': 'A',
        'longName': 'Micro A',
        'color': 'D35400',
        'textColor': 'FFFFFF',
        'description': 'x',
        'type': 3,
        'directions': 1,
        'stopCount': 10,
        'tripCount': 1,
      };
      expect(RouteSummary.fromJson(json).toJson(), json);
    });
  });

  group('RouteDetail', () {
    test('fromJson parsea bbox, direcciones y shape LineString', () {
      final detail = RouteDetail.fromJson(const {
        'id': '133 LA GUARDIA',
        'shortName': '133 LA GUARDIA',
        'longName': 'Micro 133 LA GUARDIA',
        'color': '3498DB',
        'textColor': 'FFFFFF',
        'description': 'Transporte publico urbano de micros',
        'type': 3,
        'stopCount': 84,
        'tripCount': 2,
        'bbox': [-63.35, -17.85, -63.05, -17.70],
        'directions': [
          {
            'directionId': 0,
            'headsign': 'Ida',
            'tripId': 'T97',
            'firstDeparture': '06:00:00',
            'lastDeparture': '22:00:00',
            'headwaySeconds': 300,
            'stopCount': 42,
          },
        ],
        'shape': {
          'type': 'Feature',
          'properties': {'id': 'SH97'},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [-63.18, -17.78],
              [-63.19, -17.79],
            ],
          },
        },
      });

      expect(detail.bbox, [-63.35, -17.85, -63.05, -17.70]);
      expect(detail.directions, hasLength(1));
      expect(detail.directions.first.headsign, 'Ida');
      expect(detail.directions.first.headwaySeconds, 300);
      expect(detail.shape, isNotNull);
      expect(detail.shape!.id, 'SH97');
      expect(detail.shape!.points, hasLength(2));
      expect(detail.shape!.points.first, const LatLng(-17.78, -63.18));
      expect(detail.directionById(0)!.tripId, 'T97');
    });
  });

  group('JourneyOption', () {
    test('opcion directa con legs (walk+bus+walk)', () {
      final option = JourneyOption.fromJson(const {
        'type': 'direct',
        'departAt': '06:03:00',
        'arriveAt': '06:41:00',
        'durationMinutes': 38,
        'walkToStop': {'id': 'S10', 'name': 'Parada 10', 'distanceMeters': 80},
        'walkFromStop': {
          'id': 'S200',
          'name': 'Parada 200',
          'distanceMeters': 120,
        },
        'legs': [
          {'kind': 'walk', 'durationMinutes': 2, 'distanceMeters': 80},
          {
            'kind': 'bus',
            'routeId': '1',
            'routeShortName': '1',
            'routeColor': 'D35400',
            'tripId': 'T1',
            'fromStopId': 'S10',
            'toStopId': 'S200',
            'departAt': '06:03:00',
            'arriveAt': '06:39:00',
            'stops': 12,
          },
          {'kind': 'walk', 'durationMinutes': 3, 'distanceMeters': 120},
        ],
      });

      expect(option.type, JourneyType.direct);
      expect(option.durationMinutes, 38);
      expect(option.legs, hasLength(3));
      expect(option.busLegs, hasLength(1));

      final bus = option.busLegs.single;
      expect(bus.routeId, '1');
      expect(bus.routeColor, 'D35400');
      expect(bus.fromStopId, 'S10');
      expect(bus.toStopId, 'S200');
      expect(bus.stops, 12);
      expect(bus.kind, JourneyLegKind.bus);

      expect(option.walkToStop!.distanceMeters, 80);
      expect(option.walkFromStop!.name, 'Parada 200');
      expect(option.legs.first.isWalk, isTrue);
    });

    test('opcion con transbordo', () {
      final option = JourneyOption.fromJson(const {
        'type': 'transfer',
        'departAt': '06:10:00',
        'arriveAt': '07:05:00',
        'durationMinutes': 55,
        'legs': [
          {'kind': 'walk', 'durationMinutes': 1, 'distanceMeters': 50},
          {
            'kind': 'bus',
            'routeId': '101',
            'routeShortName': '101 ANGOSTURA',
            'routeColor': '7F8C8D',
            'departAt': '06:10:00',
            'arriveAt': '06:40:00',
            'stops': 8,
          },
          {
            'kind': 'bus',
            'routeId': '5',
            'routeShortName': '5',
            'routeColor': '27AE60',
            'departAt': '06:45:00',
            'arriveAt': '07:02:00',
            'stops': 6,
          },
        ],
      });

      expect(option.type, JourneyType.transfer);
      expect(option.type.label, '1 transbordo');
      expect(option.busLegs, hasLength(2));
      expect(option.legs, hasLength(3));
    });
  });

  group('JourneyOption · mapa', () {
    test('leg con geometry y fromStop/toStop; walk refs con lat/lon', () {
      final option = JourneyOption.fromJson(const {
        'type': 'direct',
        'departAt': '06:03:00',
        'arriveAt': '06:41:00',
        'durationMinutes': 38,
        'walkToStop': {
          'id': 'S10',
          'name': 'Parada 10',
          'distanceMeters': 80,
          'lat': -17.78,
          'lon': -63.15,
        },
        'walkFromStop': {
          'id': 'S200',
          'name': 'Parada 200',
          'distanceMeters': 120,
          'lat': -17.79,
          'lon': -63.16,
        },
        'legs': [
          {'kind': 'walk', 'durationMinutes': 2, 'distanceMeters': 80},
          {
            'kind': 'bus',
            'routeId': '1',
            'routeShortName': '1',
            'routeColor': 'D35400',
            'tripId': 'T1',
            'fromStopId': 'S10',
            'toStopId': 'S200',
            'departAt': '06:03:00',
            'arriveAt': '06:39:00',
            'stops': 12,
            'fromStop': {
              'id': 'S10',
              'name': 'Parada 10',
              'lat': -17.78,
              'lon': -63.15,
            },
            'toStop': {
              'id': 'S200',
              'name': 'Parada 200',
              'lat': -17.79,
              'lon': -63.16,
            },
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [-63.15, -17.78],
                [-63.152, -17.781],
                [-63.16, -17.79],
              ],
            },
          },
          {'kind': 'walk', 'durationMinutes': 3, 'distanceMeters': 120},
        ],
      });

      // Walk refs con posición (GeoJSON usa [lon, lat]).
      expect(option.walkToStop!.hasPosition, isTrue);
      expect(option.walkToStop!.position, const LatLng(-17.78, -63.15));
      expect(option.walkFromStop!.distanceMeters, 120);

      final bus = option.busLegs.single;
      expect(bus.fromStop!.position, const LatLng(-17.78, -63.15));
      expect(bus.toStop!.name, 'Parada 200');
      expect(bus.geometry, hasLength(3));
      expect(bus.geometry!.first, const LatLng(-17.78, -63.15));
      expect(bus.geometry!.last, const LatLng(-17.79, -63.16));
      expect(bus.mapPoints, bus.geometry);

      expect(option.hasMapData, isTrue);
      // Paradas relevantes sin duplicados (walkToStop == fromStop).
      expect(option.stopRefs.map((s) => s.id).toList(), ['S10', 'S200']);
    });

    test('geometry null degrada a línea recta fromStop → toStop', () {
      final option = JourneyOption.fromJson(const {
        'type': 'direct',
        'departAt': '06:03:00',
        'arriveAt': '06:41:00',
        'durationMinutes': 38,
        'legs': [
          {
            'kind': 'bus',
            'routeId': '1',
            'routeColor': 'D35400',
            'fromStop': {
              'id': 'S10',
              'name': 'Parada 10',
              'lat': -17.78,
              'lon': -63.15,
            },
            'toStop': {
              'id': 'S200',
              'name': 'Parada 200',
              'lat': -17.79,
              'lon': -63.16,
            },
            'geometry': null,
          },
        ],
      });

      final bus = option.busLegs.single;
      expect(bus.geometry, isNull);
      expect(bus.mapPoints, [
        const LatLng(-17.78, -63.15),
        const LatLng(-17.79, -63.16),
      ]);
    });

    test('geometry malformada o incompleta se ignora (degrada)', () {
      final withoutShape = JourneyLeg.fromJson(const {
        'kind': 'bus',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            ['x', 'y'],
          ],
        },
      });
      expect(withoutShape.geometry, isNull);

      final notLineString = JourneyLeg.fromJson(const {
        'kind': 'bus',
        'geometry': {
          'type': 'Point',
          'coordinates': [-63.15, -17.78],
        },
      });
      expect(notLineString.geometry, isNull);
      expect(notLineString.mapPoints, isNull);
    });

    test('toJson conserva geometry, fromStop/toStop y lat/lon', () {
      final leg = JourneyLeg.fromJson(const {
        'kind': 'bus',
        'routeId': '1',
        'routeColor': 'D35400',
        'fromStop': {
          'id': 'S10',
          'name': 'Parada 10',
          'lat': -17.78,
          'lon': -63.15,
        },
        'toStop': {
          'id': 'S200',
          'name': 'Parada 200',
          'lat': -17.79,
          'lon': -63.16,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [-63.15, -17.78],
            [-63.16, -17.79],
          ],
        },
      });

      final json = leg.toJson();
      expect(json['fromStop'], {
        'id': 'S10',
        'name': 'Parada 10',
        'distanceMeters': null,
        'lat': -17.78,
        'lon': -63.15,
      });
      // La geometría se re-emite como GeoJSON [lon, lat].
      expect(json['geometry'], {
        'type': 'LineString',
        'coordinates': [
          [-63.15, -17.78],
          [-63.16, -17.79],
        ],
      });
      expect(JourneyLeg.fromJson(json).geometry, leg.geometry);
      expect(
        JourneyLeg.fromJson(json).toStop!.position,
        const LatLng(-17.79, -63.16),
      );
    });
  });

  group('Departure / Stats / Health', () {
    test('Departure.fromJson', () {
      final departure = Departure.fromJson(const {
        'tripId': 'T97',
        'directionId': 0,
        'headsign': 'Ida',
        'time': '06:07:18',
        'realTime': false,
        'headwaySeconds': 300,
      });
      expect(departure.tripId, 'T97');
      expect(departure.time, '06:07:18');
      expect(departure.realTime, isFalse);
      expect(departure.headwaySeconds, 300);
    });

    test('Stats.fromJson', () {
      final stats = Stats.fromJson(const {
        'routes': 154,
        'stops': 31461,
        'trips': 308,
        'shapes': 130105,
        'service': {
          'start': '2026-10-06',
          'end': '2027-10-06',
          'days': 'diario',
        },
        'firstDeparture': '06:00:00',
        'lastDeparture': '22:00:00',
        'headwaySeconds': 300,
      });
      expect(stats.routes, 154);
      expect(stats.stops, 31461);
      expect(stats.service.days, 'diario');
      expect(stats.headwaySeconds, 300);
    });

    test('HealthInfo.fromJson', () {
      final health = HealthInfo.fromJson(const {
        'status': 'ok',
        'db': 'up',
        'uptime': 123.4,
        'version': '1.0.0',
      });
      expect(health.isOk, isTrue);
      expect(health.version, '1.0.0');
    });
  });

  group('Meta / Paged', () {
    test('Meta.fromJson lee el envoltorio', () {
      final meta = Meta.fromJson(const {'page': 1, 'limit': 20, 'total': 154});
      expect(meta.page, 1);
      expect(meta.total, 154);
      expect(meta.safeTotal, 154);
    });

    test('compactQuery elimina nulos y vacíos', () {
      expect(compactQuery({'q': null, 'page': 1, 'sort': ''}), {'page': 1});
    });
  });
}
