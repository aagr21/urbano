import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/presentation/widgets/route_list_tile.dart';

/// Regresión: la fila del buscador de Inicio NO desborda por la derecha
/// cuando el `shortName` de la línea es largo (el feed devuelve líneas largas
/// que coinciden con consultas cortas como "37").
///
/// Antes el `RouteBadge` iba en un `Flexible(flex: 0)`, que no acotaba su
/// ancho: el chip se medía a su tamaño natural y se salía del `Row`.
void main() {
  testWidgets('RouteListTile no desborda a ancho de móvil con numeral largo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    const route = RouteSummary(
      id: '37-EXPRESO',
      shortName: '37 EXPRESO VILLA SANTA CRUZ CAMINO AL NORTE LARGO',
      longName:
          'Micro 37 Avenida Cristo Redentor esquina Universidad Tecnológica',
      color: 'D35400',
      textColor: 'FFFFFF',
      description: 'Transporte publico urbano de micros',
      type: 3,
      directionsCount: 2,
      stopCount: 20,
      tripCount: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          // Ancho real de móvil (~393 lógicos): la fila tiene que caber.
          body: Center(
            child: SizedBox(
              width: 360,
              child: RouteListTile(
                key: ValueKey(route.id),
                route: route,
                heroPrefix: 'search',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Sin desbordamiento (RenderFlex) ni otra excepción de renderizado.
    expect(tester.takeException(), isNull);
  });
}
