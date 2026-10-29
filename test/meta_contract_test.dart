import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/home/data/meta.dart';
import 'package:urbano/src/features/home/presentation/home_providers.dart';
import 'package:urbano/src/features/info/presentation/info_screen.dart';

/// Contrato de `GET /meta` del lado cliente (`docs/api-contract.md`):
/// el modelo parsea la envolvente `{ feed, limits }` y la pantalla Info
/// despliega la versión/vigencia del dataset SIN red (provider override).
void main() {
  Map<String, dynamic> payload() => {
    'feed': {
      'version': '1.0',
      'publisher': 'Micros Santa Cruz',
      'lang': 'es',
      'startDate': '20261006',
      'endDate': '20271006',
    },
    'limits': {
      'maxResults': 10,
      'walkRadiusM': 500,
      'maxCandidateStops': 15,
      'minTransitDistanceM': 150,
      'minBoardingPairDistanceM': 150,
      'walkSpeedMPerMin': 80,
      'transferPenaltyMinutes': 10,
    },
  };

  group('MetaInfo (modelo del contrato /meta)', () {
    test('parsea feed + límites del JSON real del backend', () {
      final meta = MetaInfo.fromJson(payload());

      expect(meta.version, '1.0');
      expect(meta.publisher, 'Micros Santa Cruz');
      expect(meta.lang, 'es');
      expect(meta.limits['maxResults'], 10);
      expect(meta.limits['minTransitDistanceM'], 150);
    });

    test('summary formatea versión y vigencia GTFS (YYYYMMDD)', () {
      final meta = MetaInfo.fromJson(payload());
      expect(meta.summary, 'v1.0 · 2026-10-06 → 2027-10-06');
      expect(meta.prettyDate('20261006'), '2026-10-06');
    });

    test('feed incompleto → degradación legible, no crashea', () {
      const meta = MetaInfo(
        version: '',
        publisher: '',
        lang: '',
        startDate: '',
        endDate: '',
        limits: {},
      );
      expect(meta.summary, 'sin versión');
      expect(meta.publisher.isEmpty, isTrue);
    });

    test('sin fechas el summary solo muestra versión', () {
      const meta = MetaInfo(
        version: '2.1',
        publisher: 'X',
        lang: 'es',
        startDate: '',
        endDate: '',
        limits: {},
      );
      expect(meta.summary, 'v2.1');
    });
  });

  group('InfoScreen · fila "Versión del dataset"', () {
    testWidgets('muestra la versión y vigencia del feed real', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // /meta es el foco; stats y salud quedan offline como en el
            // resto del harness de Info (dio outside no debe abrir timers).
            metaProvider.overrideWith(
              (ref) async => MetaInfo.fromJson(payload()),
            ),
            statsProvider.overrideWith((ref) async => throw Exception('x')),
            healthProvider.overrideWith((ref) async => throw Exception('x')),
          ],
          child: const MaterialApp(home: InfoScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Versión del dataset'), findsOneWidget);
      expect(find.text('v1.0 · 2026-10-06 → 2027-10-06'), findsOneWidget);
    });

    testWidgets('sin conexión el row degrada a "Sin conexión"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            metaProvider.overrideWith((ref) async => throw Exception('x')),
            // Igual que arriba: nada de red en el harness de Info.
            statsProvider.overrideWith((ref) async => throw Exception('x')),
            healthProvider.overrideWith((ref) async => throw Exception('x')),
          ],
          child: const MaterialApp(home: InfoScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Sin conexión'), findsWidgets);
    });
  });
}
