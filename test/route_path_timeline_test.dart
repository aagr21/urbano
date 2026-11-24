import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/routes/presentation/route_providers.dart';
import 'package:urbano/src/features/routes/presentation/widgets/route_path_timeline.dart';

const _streets = [
  'Av. Uno',
  'Av. Dos',
  'Av. Tres',
  'Av. Cuatro',
  'Av. Cinco',
  'Av. Seis',
  'Av. Siete',
  'Av. Ocho',
];

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routeStreetsProvider.overrideWith((ref, key) async => _streets),
        routeStopsProvider.overrideWith((ref, key) async => const []),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: RoutePathTimeline(
              routeKey: RouteKey('101'),
              routeColor: Color(0xFF0F766E),
              origin: 'El Mechero',
              destination: 'Centro',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('arranca plegado: solo «Sale de» y «Llega a» y el acceso a '
      'las calles', (tester) async {
    await _pump(tester);

    expect(find.text('Sale de'), findsOneWidget);
    expect(find.text('El Mechero'), findsOneWidget);
    expect(find.text('Llega a'), findsOneWidget);
    expect(find.text('Centro'), findsOneWidget);
    expect(find.text('Av. Uno'), findsNothing);
    expect(find.text('Ver las 8 calles por donde pasa'), findsOneWidget);
  });

  testWidgets('desplegado muestra todas las calles en orden, entre la salida '
      'y la llegada', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('route-path-more')));
    await tester.pumpAndSettle();

    expect(find.text('Ver las 8 calles por donde pasa'), findsNothing);
    for (final street in _streets) {
      expect(find.text(street), findsOneWidget);
    }
    final top = tester.getTopLeft(find.text('El Mechero')).dy;
    final first = tester.getTopLeft(find.text('Av. Uno')).dy;
    final last = tester.getTopLeft(find.text('Av. Ocho')).dy;
    final end = tester.getTopLeft(find.text('Centro')).dy;
    expect(top, lessThan(first));
    expect(first, lessThan(last));
    expect(last, lessThan(end));
  });
}
