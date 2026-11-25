import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/widgets/photo_viewer.dart';
import 'package:urbano/src/core/widgets/route_photo.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_option_card.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/presentation/widgets/micro_bus_art.dart';

import 'helpers/journey_fixtures.dart';

/// La tarjeta de opción muestra horarios grandes, tipo y duración, instrucciones
/// paso a paso numeradas (1, 2, 3...) solo al abrirla, la tira de líneas a
/// tomar y el coste del pasaje.
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    bool selected = false,
    bool expanded = false,
    int index = 0,
    Map<String, RouteSummary> routes = const {},
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
                routes: routes,
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

  testWidgets('cerrada no muestra el paso a paso; abierta sí', (tester) async {
    await pumpCard(tester);
    expect(find.text('Camina 50 m'), findsNothing);
    expect(find.text('bájate en «Parada 200»'), findsNothing);
  });

  testWidgets('muestra pasos enumerados del viaje', (tester) async {
    await pumpCard(tester, expanded: true);

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

  testWidgets('la galería muestra una postal por micro, en orden y unidas '
      'por el transbordo', (tester) async {
    await pumpCard(tester);

    // Sin ficha de línea todavía: placas del color de cada micro (nunca un
    // hueco), numeradas 1 y 2 y con el nudo de transbordo entre ellas.
    expect(
      find.byKey(const ValueKey('journey-micro-shot-0-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journey-micro-shot-0-3')),
      findsOneWidget,
    );
    expect(find.byTooltip('Transbordo'), findsOneWidget);
    expect(find.text('101 ANGOSTURA'), findsWidgets);
    expect(find.text('5'), findsWidgets);
    expect(find.byType(MicroBusArt), findsNWidgets(2));
  });

  testWidgets('con la ficha de la línea, la postal muestra la foto y el '
      'trayecto, y tocarla la abre a pantalla completa', (tester) async {
    await pumpCard(
      tester,
      routes: {
        '101': const RouteSummary(
          id: '101',
          shortName: '101 ANGOSTURA',
          longName: 'Plan 3000 - Centro',
          color: 'D35400',
          textColor: 'FFFFFF',
          description: '',
          type: 3,
          directionsCount: 2,
          stopCount: 30,
          tripCount: 10,
          imageUrl: 'https://example.com/101.jpg',
        ),
      },
    );

    expect(find.byType(RoutePhoto), findsOneWidget);
    expect(find.text('Plan 3000 - Centro'), findsOneWidget);
    // La otra línea sigue en su placa ilustrada.
    expect(find.byType(MicroBusArt), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('journey-micro-shot-0-1')));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
  });

  testWidgets('horario, caminata y pasaje se leen en palabras', (tester) async {
    await pumpCard(tester);

    // Horarios con su ícono.
    expect(find.byIcon(Icons.login_rounded), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

    // Pie: caminata total y pasaje, en una línea.
    expect(find.text('200 m a pie'), findsOneWidget);
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
