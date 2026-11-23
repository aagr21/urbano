import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/home/presentation/widgets/recent_trips.dart';
import 'package:urbano/src/features/journey/application/trip_history_controller.dart';
import 'package:urbano/src/features/journey/data/trip_history.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/memory_trip_history_store.dart';

/// Historial de [count] destinos, del más reciente (`Destino 0`) al más viejo.
List<TripHistoryEntry> _entries(int count) => [
  for (var i = 0; i < count; i++)
    TripHistoryEntry(
      label: 'Destino $i',
      subtitle: 'Centro histórico',
      lat: -17.78 - i * 0.001,
      lon: -63.18,
      lastUsed: DateTime.now().subtract(Duration(hours: i + 1)),
      durationMinutes: 10 + i,
    ),
];

/// Monta la portada mínima (solo el historial) con un router real, para que
/// tocar una fila pueda cambiar a `/journey` como en la app.
Future<GoRouter> _pumpHome(
  WidgetTester tester,
  List<TripHistoryEntry> entries,
) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: SingleChildScrollView(child: RecentTrips())),
      ),
      GoRoute(
        path: '/journey',
        builder: (_, _) => const Scaffold(body: Text('viaje')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripHistoryControllerProvider.overrideWith(
          () => TripHistoryController(MemoryTripHistoryStore(entries)),
        ),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('RecentTrips', () {
    testWidgets('la portada lista solo los 3 viajes más recientes', (
      tester,
    ) async {
      final entries = _entries(5);
      await _pumpHome(tester, entries);

      expect(find.text('Destino 0'), findsOneWidget);
      expect(find.text('Destino 1'), findsOneWidget);
      expect(find.text('Destino 2'), findsOneWidget);
      expect(
        find.text('Destino 3'),
        findsNothing,
        reason: 'el cuarto viaje vive en la hoja «Ver todos»',
      );
      expect(find.text('Destino 4'), findsNothing);

      final seeAll = find.byKey(const ValueKey('recent-trips-see-all'));
      expect(seeAll, findsOneWidget);
      expect(
        find.descendant(of: seeAll, matching: find.text('2')),
        findsNothing,
        reason: 'la píldora «Ver todos» no lleva número',
      );
    });

    testWidgets('con 3 viajes o menos no hay botón «Ver todos»', (
      tester,
    ) async {
      await _pumpHome(tester, _entries(3));

      expect(find.text('Destino 0'), findsOneWidget);
      expect(find.text('Destino 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('recent-trips-see-all')),
        findsNothing,
        reason: 'no hay nada más que mostrar',
      );
    });

    testWidgets('«Ver todos» abre la hoja con el historial completo', (
      tester,
    ) async {
      final entries = _entries(5);
      await _pumpHome(tester, entries);

      await tester.tap(find.byKey(const ValueKey('recent-trips-see-all')));
      await tester.pumpAndSettle();

      expect(find.text('5 destinos guardados'), findsOneWidget);
      for (final entry in entries) {
        expect(
          find.byKey(ValueKey('recent-trip-all-${entry.key}')),
          findsOneWidget,
          reason: 'la hoja lista también los que no caben en la portada',
        );
      }
      // La portada sigue montada debajo: sus filas no se duplican con las de
      // la hoja (claves distintas) ni se pierden.
      expect(
        find.byKey(ValueKey('recent-trip-${entries.first.key}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('recent-trip-${entries[3].key}')),
        findsNothing,
      );
    });

    testWidgets('con más de 8 viajes la hoja pagina de 8 en 8', (tester) async {
      final entries = _entries(10);
      await _pumpHome(tester, entries);

      await tester.tap(find.byKey(const ValueKey('recent-trips-see-all')));
      await tester.pumpAndSettle();

      expect(find.text('10 destinos guardados'), findsOneWidget);
      expect(find.text('Página 1 de 2'), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        expect(
          find.byKey(ValueKey('recent-trip-all-${entries[i].key}')),
          findsOneWidget,
          reason: 'la primera página muestra los 8 más recientes',
        );
      }
      expect(
        find.byKey(ValueKey('recent-trip-all-${entries[8].key}')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('recent-trip-all-${entries[9].key}')),
        findsNothing,
      );

      final next = find.byKey(const ValueKey('recent-trips-next-page'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();

      expect(find.text('Página 2 de 2'), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        expect(
          find.byKey(ValueKey('recent-trip-all-${entries[i].key}')),
          findsNothing,
        );
      }
      expect(
        find.byKey(ValueKey('recent-trip-all-${entries[8].key}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('recent-trip-all-${entries[9].key}')),
        findsOneWidget,
      );

      final prev = find.byKey(const ValueKey('recent-trips-prev-page'));
      await tester.ensureVisible(prev);
      await tester.pumpAndSettle();
      await tester.tap(prev);
      await tester.pumpAndSettle();
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(
        find.byKey(ValueKey('recent-trip-all-${entries[0].key}')),
        findsOneWidget,
      );
    });

    testWidgets('el buscador filtra por destino y reinicia la página', (
      tester,
    ) async {
      final entries = _entries(12);
      await _pumpHome(tester, entries);

      await tester.tap(find.byKey(const ValueKey('recent-trips-see-all')));
      await tester.pumpAndSettle();
      final next = find.byKey(const ValueKey('recent-trips-next-page'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 2'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('recent-trips-search')),
        'Destino 1',
      );
      await tester.pumpAndSettle();

      expect(find.text('Página 2 de 2'), findsNothing);
      for (final i in [1, 10, 11]) {
        expect(
          find.byKey(ValueKey('recent-trip-all-${entries[i].key}')),
          findsOneWidget,
          reason: 'coinciden los destinos que contienen "Destino 1"',
        );
      }
      expect(
        find.byKey(ValueKey('recent-trip-all-${entries[0].key}')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('recent-trips-clear-search')));
      await tester.pumpAndSettle();
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(
        find.byKey(ValueKey('recent-trip-all-${entries[0].key}')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('recent-trips-search')),
        'zzz',
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin destinos para «zzz»'), findsOneWidget);
    });

    testWidgets(
      'tocar una fila de la hoja la cierra y abre el sheet de destino',
      (tester) async {
        final entries = _entries(5);
        await _pumpHome(tester, entries);

        await tester.tap(find.byKey(const ValueKey('recent-trips-see-all')));
        await tester.pumpAndSettle();

        final target = find.byKey(
          ValueKey('recent-trip-all-${entries[3].key}'),
        );
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();

        // La hoja «Ver todos» se cierra y se abre el sheet de destino modal
        // (no navega a /journey).
        expect(
          find.text('5 destinos guardados'),
          findsNothing,
          reason: 'la hoja «Ver todos» se cerró al elegir el destino',
        );
        // El sheet de destino aparece con el destino pre-llenado.
        expect(find.text('Destino 3'), findsWidgets);
      },
    );
  });
}
