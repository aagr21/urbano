import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/routes/presentation/micros_screen.dart';
import 'package:urbano/src/features/routes/presentation/widgets/micro_bus_art.dart';

import 'helpers/fake_route_repository.dart';

RouteSummary _route(String id) => RouteSummary(
  id: id,
  shortName: id,
  longName: 'Micro $id',
  color: '7F8C8D',
  textColor: 'FFFFFF',
  description: 'Transporte publico urbano de micros',
  type: 3,
  directionsCount: 2,
  stopCount: 84,
  tripCount: 2,
);

Future<FakeRouteRepository> _pumpCatalog(
  WidgetTester tester,
  List<RouteSummary> routes,
) async {
  final repository = FakeRouteRepository(routes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [routeRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: AppTheme.light(), home: const MicrosScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return repository;
}

void main() {
  testWidgets('el catálogo pide la segunda página al llegar al final', (
    tester,
  ) async {
    final repository = await _pumpCatalog(tester, [
      for (var i = 1; i <= 130; i++) _route('${100 + i} LINEA'),
    ]);
    expect(repository.listCalls.first, contains('page=1 limit=100'));

    // Un tirón hasta el fondo dispara el paginado por cercanía.
    await tester.drag(
      find.byKey(const ValueKey('micros-list')),
      const Offset(0, -100000),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      repository.listCalls.any((call) => call.contains('page=2')),
      isTrue,
      reason: 'al acercarse al final se pide la página siguiente',
    );
    // La lista acumula, no reemplaza: la primera línea sigue estando al subir.
    await tester.drag(
      find.byKey(const ValueKey('micros-list')),
      const Offset(0, 100000),
    );
    await tester.pump();
    expect(find.text('101 LINEA'), findsOneWidget);
  });

  testWidgets('cada línea trae su micro ilustrado y ninguna parada', (
    tester,
  ) async {
    await _pumpCatalog(tester, [_route('101 ANGOSTURA')]);

    // La imagen de la línea es parte de la tarjeta (color GTFS incluido).
    expect(find.byType(MicroBusArt), findsOneWidget);
    // El catálogo no inventa paradas: el backend no las expone por ruta.
    expect(find.textContaining('paradas'), findsNothing);
    // La cifra sigue en la tarjeta (el rótulo puede cambiar: viajes/rutas).
    expect(find.textContaining('2 '), findsOneWidget);
  });

  testWidgets('el buscador filtra por numeral y «Limpiar» devuelve todo', (
    tester,
  ) async {
    final repository = await _pumpCatalog(tester, [
      _route('101 ANGOSTURA'),
      _route('202 VILLA 1RO DE MAYO'),
    ]);

    await tester.enterText(find.byType(TextField), '202');
    // El buscador espera 280 ms antes de consultar.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('202 VILLA 1RO DE MAYO'), findsOneWidget);
    expect(find.text('101 ANGOSTURA'), findsNothing);
    expect(repository.listCalls.length, 2);

    await tester.tap(find.byTooltip('Limpiar búsqueda'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('101 ANGOSTURA'), findsOneWidget);
    expect(find.text('202 VILLA 1RO DE MAYO'), findsOneWidget);
  });
}
