import 'package:urbano/src/features/journey/data/journey_models.dart';

/// Opción directa: caminata + micro con `geometry` + caminata.
JourneyOption fixtureDirectOption() => JourneyOption.fromJson(const {
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
          [-63.155, -17.785],
          [-63.16, -17.79],
        ],
      },
    },
    {'kind': 'walk', 'durationMinutes': 3, 'distanceMeters': 120},
  ],
});

/// Opción con transbordo: el segundo micro NO tiene `geometry` (línea recta).
JourneyOption fixtureTransferOption() => JourneyOption.fromJson(const {
  'type': 'transfer',
  'departAt': '06:10:00',
  'arriveAt': '07:05:00',
  'durationMinutes': 55,
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
    {'kind': 'walk', 'durationMinutes': 1, 'distanceMeters': 50},
    {
      'kind': 'bus',
      'routeId': '101',
      'routeShortName': '101 ANGOSTURA',
      'routeColor': '7F8C8D',
      'tripId': 'T9',
      'fromStopId': 'S10',
      'toStopId': 'SC',
      'departAt': '06:10:00',
      'arriveAt': '06:40:00',
      'stops': 8,
      'fromStop': {
        'id': 'S10',
        'name': 'Parada 10',
        'lat': -17.78,
        'lon': -63.15,
      },
      'toStop': {
        'id': 'SC',
        'name': 'Transbordo Central',
        'lat': -17.785,
        'lon': -63.155,
      },
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [-63.15, -17.78],
          [-63.153, -17.783],
          [-63.155, -17.785],
        ],
      },
    },
    {'kind': 'transfer', 'durationMinutes': 3},
    {
      'kind': 'bus',
      'routeId': '5',
      'routeShortName': '5',
      'routeColor': '27AE60',
      'tripId': 'T5',
      'fromStopId': 'SC',
      'toStopId': 'S200',
      'departAt': '06:45:00',
      'arriveAt': '07:02:00',
      'stops': 6,
      'fromStop': {
        'id': 'SC',
        'name': 'Transbordo Central',
        'lat': -17.785,
        'lon': -63.155,
      },
      'toStop': {
        'id': 'S200',
        'name': 'Parada 200',
        'lat': -17.79,
        'lon': -63.16,
      },
      'geometry': null,
    },
    {'kind': 'walk', 'durationMinutes': 3, 'distanceMeters': 120},
  ],
});
