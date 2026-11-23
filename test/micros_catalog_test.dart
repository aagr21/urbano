import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/routes/presentation/micros_screen.dart';

import 'helpers/fake_route_repository.dart';

/// Sentinel para omitir keyStops en el helper de prueba.
const _noKeyStops = Object();

RouteSummary _route(String id, {Object? keyStops = _defaultKeyStops}) {
  return RouteSummary(
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
    keyStops: keyStops == _noKeyStops ? null : keyStops as List<String>?,
  );
}

const List<String> _defaultKeyStops = ['El Mechero', 'Centro'];

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
      find.byType(CustomScrollView).first,
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
      find.byType(CustomScrollView).first,
      const Offset(0, 100000),
    );
    await tester.pump();
    // El longName (Micro 101 LINEA) se muestra en los extremos de ruta.
    expect(find.text('Micro 101 LINEA'), findsOneWidget);
  });

  testWidgets('cada línea muestra los extremos de ruta (origen → destino)', (
    tester,
  ) async {
    await _pumpCatalog(tester, [_route('101 ANGOSTURA')]);

    // El longName se muestra en la tarjeta.
    expect(find.text('Micro 101 ANGOSTURA'), findsAtLeast(1));
    // Los extremos de ruta se muestran como chips: origen y destino.
    expect(find.text('El Mechero'), findsAtLeast(1));
    expect(find.text('Centro'), findsAtLeast(1));
    // La flecha de avance entre extremos.
    expect(find.byIcon(Icons.double_arrow_rounded), findsAtLeast(1));
  });

  testWidgets('sin keyStops muestra fallback con paradas', (tester) async {
    await _pumpCatalog(tester, [_route('101', keyStops: _noKeyStops)]);

    // El longName se muestra.
    expect(find.text('Micro 101'), findsAtLeast(1));
    // El fallback muestra la cantidad de paradas.
    expect(find.textContaining('paradas'), findsAtLeast(1));
    // No hay flecha de extremos sin keyStops.
    expect(find.byIcon(Icons.double_arrow_rounded), findsNothing);
  });

  testWidgets('el buscador filtra por numeral y limpiar devuelve todo', (
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

    expect(find.text('Micro 202 VILLA 1RO DE MAYO'), findsOneWidget);
    expect(find.text('Micro 101 ANGOSTURA'), findsNothing);
    expect(repository.listCalls.length, 2);

    // Limpiar el campo de texto y re-cargar
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Micro 101 ANGOSTURA'), findsOneWidget);
    expect(find.text('Micro 202 VILLA 1RO DE MAYO'), findsOneWidget);
  });
}
