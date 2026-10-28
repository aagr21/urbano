import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/journey/data/journey_models.dart';
import 'package:urbano/src/features/journey/data/journey_repository.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';

/// Opción mínima con buses [routes] (por su `routeShortName`) y una sola hora.
JourneyOption _option({
  required JourneyType type,
  required List<String> routes,
  required String departAt,
  required int durationMinutes,
}) {
  final busLegs = [
    for (final (i, r) in routes.indexed)
      {
        'kind': 'bus',
        'routeId': r,
        'routeShortName': r,
        'tripId': '$r-T$i',
        'fromStopId': 'A$i',
        'toStopId': 'B$i',
        'departAt': departAt,
        'arriveAt': departAt,
      },
  ];
  return JourneyOption.fromJson({
    'type': type == JourneyType.direct ? 'direct' : 'transfer',
    'departAt': departAt,
    'arriveAt': departAt,
    'durationMinutes': durationMinutes,
    'legs': busLegs,
  });
}

String _sig(JourneyOption o) =>
    o.busLegs.map((l) => l.routeShortName ?? l.routeId).join('>');

void main() {
  group('refineJourneyOptions', () {
    test('colapsa la misma secuencia de rutas que solo cambia de hora', () {
      final input = [
        _option(
          type: JourneyType.transfer,
          routes: ['8', '10'],
          departAt: '10:30:00',
          durationMinutes: 40,
        ),
        _option(
          type: JourneyType.transfer,
          routes: ['8', '10'],
          departAt: '10:35:00',
          durationMinutes: 38,
        ),
      ];

      final result = refineJourneyOptions(input, maxShown: 3);

      expect(result, hasLength(1));
      // Se queda con la salida más próxima, aunque la otra sea más corta.
      expect(result.single.departAt, '10:30:00');
    });

    test('muestra primero las opciones sin transbordo', () {
      final input = [
        _option(
          type: JourneyType.transfer,
          routes: ['8', '10'],
          departAt: '06:00:00',
          durationMinutes: 20,
        ),
        _option(
          type: JourneyType.direct,
          routes: ['8'],
          departAt: '06:30:00',
          durationMinutes: 45,
        ),
      ];

      final result = refineJourneyOptions(input, maxShown: 3);

      expect(result.map((o) => o.type), [
        JourneyType.direct,
        JourneyType.transfer,
      ]);
    });

    test('conserva combinaciones distintas y limita a maxShown', () {
      final input = [
        _option(
          type: JourneyType.direct,
          routes: ['8'],
          departAt: '06:20:00',
          durationMinutes: 30,
        ),
        _option(
          type: JourneyType.direct,
          routes: ['8'],
          departAt: '06:40:00',
          durationMinutes: 28,
        ),
        _option(
          type: JourneyType.direct,
          routes: ['10'],
          departAt: '06:10:00',
          durationMinutes: 35,
        ),
        _option(
          type: JourneyType.transfer,
          routes: ['8', '10'],
          departAt: '06:15:00',
          durationMinutes: 50,
        ),
      ];

      final result = refineJourneyOptions(input, maxShown: 2);

      expect(result.map(_sig), ['8', '10']);
      // Directos primero (orden por duración asc: 8=30 < 10=35); el transbordo
      // "8 > 10" queda fuera por el corte a maxShown.
      expect(result.every((o) => o.type == JourneyType.direct), isTrue);
    });
  });

  group('journeyProvider · pool de candidatos', () {
    // El DTO del backend valida maxResults con @Min(1)/@Max(10): superarlo
    // responde 400 "Validation failed" y rompe la planificación.
    Future<List<int>> requestedFor(int maxShown) async {
      final requested = <int>[];
      final container = ProviderContainer(
        overrides: [
          journeyRepositoryProvider.overrideWithValue(
            _RecordingRepository(requested),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(
        journeyProvider(
          JourneyQuery(
            origin: const JourneyPlaceLocation(lat: -17.78, lon: -63.15),
            destination: const JourneyPlaceLocation(lat: -17.79, lon: -63.16),
            maxResults: maxShown,
          ),
        ).future,
      );
      return requested;
    }

    test(
      'pide más candidatos de los que muestra, sin pasar del tope 10',
      () async {
        for (final maxShown in [1, 3, 5, 10]) {
          final requested = await requestedFor(maxShown);
          expect(requested, hasLength(1), reason: 'maxShown=$maxShown');
          expect(requested.single, greaterThanOrEqualTo(maxShown));
          expect(requested.single, lessThanOrEqualTo(10));
          expect(requested.single, greaterThan(0));
        }
      },
    );
  });
}

/// Repositorio falso que registra el `maxResults` solicitado.
class _RecordingRepository implements JourneyRepository {
  _RecordingRepository(this.requested);

  final List<int> requested;

  @override
  Future<List<JourneyOption>> plan({
    required JourneyPoint origin,
    required JourneyPoint destination,
    String? time,
    int maxResults = 3,
  }) async {
    requested.add(maxResults);
    return [
      _option(
        type: JourneyType.direct,
        routes: const ['8'],
        departAt: '06:00:00',
        durationMinutes: 30,
      ),
    ];
  }
}
