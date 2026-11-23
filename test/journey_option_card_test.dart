import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_option_card.dart';

import 'helpers/journey_fixtures.dart';

/// La tarjeta de opción muestra horarios grandes, tipo y duración, instrucciones
/// paso a paso numeradas (1, 2, 3...), líneas a tomar y coste del pasaje.
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    bool selected = false,
    bool expanded = false,
    int index = 0,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              JourneyOptionCard(
                option: fixtureTransferOption(),
                expanded: expanded,
                index: index,
                selected: selected,
                onToggle: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra horarios grandes, tipo y duración', (tester) async {
    await pumpCard(tester);

    expect(find.text('06:10'), findsOneWidget);
    expect(find.text('07:05'), findsOneWidget);
    expect(find.text('Directo'), findsNothing);
    expect(find.text('1 transbordo'), findsOneWidget);
    expect(find.text('55 min'), findsOneWidget);
  });

  testWidgets('muestra pasos enumerados del viaje', (tester) async {
    await pumpCard(tester);

    // 1) caminar
    expect(find.text('1'), findsWidgets);
    expect(find.text('Camina 50 m'), findsOneWidget);
    expect(find.text('hasta «Parada 10»'), findsOneWidget);

    // 2) subir al primer micro
    expect(find.text('Sube a la '), findsWidgets);
    expect(find.text('101 ANGOSTURA'), findsWidgets);
    expect(find.text('bájate en «Transbordo Central»'), findsOneWidget);

    // 3) transfer
    expect(find.text('Bájate en «Transbordo Central»'), findsOneWidget);

    // 4) segundo micro
    expect(find.text('Sube a la '), findsWidgets);
    expect(find.text('5'), findsWidgets);
    expect(find.text('bájate en «Parada 200»'), findsOneWidget);

    // 5) llegar caminando
    expect(find.text('Camina 120 m'), findsOneWidget);
    expect(find.text('y llegas a tu destino'), findsOneWidget);
  });

  testWidgets('muestra líneas a tomar con sus colores', (tester) async {
    await pumpCard(tester);

    expect(find.text('Líneas que vas a tomar:'), findsOneWidget);
    expect(find.text('101 ANGOSTURA'), findsWidgets);
    expect(find.text('5'), findsWidgets);
    expect(find.byIcon(Icons.directions_bus_rounded), findsWidgets);
  });

  testWidgets('horario, caminata y pasaje se leen en palabras', (tester) async {
    await pumpCard(tester);

    // Horarios con su ícono.
    expect(find.byIcon(Icons.login_rounded), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

    // Resumen al pie: pasaje.
    expect(find.text('Bs 7.00 · 2 pasajes'), findsOneWidget);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
  });

  testWidgets('en reposo la tarjeta lleva borde y sombra', (tester) async {
    await pumpCard(tester);

    final card = tester.firstWidget(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    ) as AnimatedContainer;
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
  });

  testWidgets('no muestra horas ni paradas en los pasos', (tester) async {
    await pumpCard(tester);
    expect(find.text('06:10 → 06:40'), findsNothing);
    expect(find.text('paradas'), findsNothing);

    await pumpCard(tester, expanded: true);
    expect(find.text('06:10 → 06:40'), findsNothing);
    expect(find.text('paradas'), findsNothing);
  });
}
