import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/complaints/application/route_picker.dart';
import 'package:urbano/src/features/complaints/presentation/widgets/complaint_route_selector_sheet.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';

RouteSummary _route(String number, {List<String>? stops}) => RouteSummary(
  id: number,
  shortName: number,
  longName: 'Micro $number',
  color: 'D35400',
  textColor: 'FFFFFF',
  description: '',
  type: 3,
  directionsCount: 2,
  stopCount: 100,
  tripCount: 2,
  keyStops: stops,
);

final _routes = [
  _route('1', stops: ['Avenida Piraí esquina Calle Venus', 'Parada S1966']),
  _route('8', stops: ['Avenida Santa Cruz']),
  _route('18'),
  _route('80', stops: ['Calle Los Ceibos esquina Calle Los Sauces']),
  _route('85'),
];

void main() {
  group('búsqueda del selector de micro', () {
    test(
      'un número trae la exacta, luego las que empiezan y al final el resto',
      () {
        expect(searchRoutes(_routes, '8').map((r) => r.id), [
          '8',
          '80',
          '85',
          '18',
        ]);
      },
    );

    test('se busca por calle y sin tildes', () {
      expect(searchRoutes(_routes, 'pirai').map((r) => r.id), ['1']);
      expect(searchRoutes(_routes, 'CEIBOS').map((r) => r.id), ['80']);
    });

    test('vacío devuelve todas en su orden', () {
      expect(searchRoutes(_routes, '  '), _routes);
    });

    test('el resumen abrevia y descarta las paradas genéricas', () {
      expect(routeStopsSummary(_routes[0]), 'Pasa por Av. Piraí y C. Venus');
      expect(routeStopsSummary(_routes[2]), isNull);
    });
  });

  group('hoja «¿En qué micro pasó?»', () {
    Future<RouteSummary?> Function() open(
      WidgetTester tester, {
      RouteSummary? selected,
    }) {
      RouteSummary? result;
      var done = false;
      return () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async {
                      result = await showModalBottomSheet<RouteSummary>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ComplaintRouteSelectorSheet(
                          routes: _routes,
                          selected: selected,
                        ),
                      );
                      done = true;
                    },
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        return done ? result : null;
      };
    }

    testWidgets('abre sin teclado, con cabecera y recorrido por fila', (
      tester,
    ) async {
      await open(tester)();

      expect(find.text('¿En qué micro pasó?'), findsOneWidget);
      expect(find.text('5 líneas · por número o calle'), findsOneWidget);
      // Sin autofocus: la lista se puede recorrer apenas se abre.
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('route-picker-search')),
      );
      expect(field.autofocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Pasa por Av. Piraí y C. Venus'), findsOneWidget);
    });

    testWidgets('buscar por calle filtra y elegir devuelve la línea', (
      tester,
    ) async {
      RouteSummary? picked;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    picked = await showModalBottomSheet<RouteSummary>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ComplaintRouteSelectorSheet(
                        routes: _routes,
                        selected: null,
                      ),
                    ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('route-picker-search')),
        'ceibos',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 RESULTADO'), findsOneWidget);
      expect(find.text('Micro 80'), findsOneWidget);
      expect(find.text('Micro 1'), findsNothing);

      await tester.tap(find.text('Micro 80'));
      await tester.pumpAndSettle();
      expect(picked?.id, '80');
    });

    testWidgets('la línea elegida queda fija arriba y no se repite', (
      tester,
    ) async {
      await open(tester, selected: _routes.last)();

      expect(find.byKey(const ValueKey('route-picker-pinned')), findsOneWidget);
      expect(find.text('Micro 85'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Micro 85')).dy,
        lessThan(tester.getTopLeft(find.text('Micro 1')).dy),
        reason: 'la elegida va antes que el resto',
      );
    });

    testWidgets('sin coincidencias ofrece volver a ver todas', (tester) async {
      await open(tester)();
      await tester.enterText(
        find.byKey(const ValueKey('route-picker-search')),
        'zzz',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ninguna línea coincide'), findsOneWidget);

      await tester.tap(find.text('Ver todas'));
      await tester.pumpAndSettle();
      expect(find.text('Micro 1'), findsOneWidget);
    });
  });
}
