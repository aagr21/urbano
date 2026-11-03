import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/widgets/splash_gate.dart';
import 'package:urbano/src/core/widgets/urbano_logo.dart';

/// La portada de arranque: tapa la app, se levanta sola y no deja nada
/// montado ni ticking después.
void main() {
  Widget host(Widget child, {bool reduced = false}) => MediaQuery(
    // `disableAnimations` es el mismo interruptor que lee `Motion.reduced`.
    data: MediaQueryData(disableAnimations: reduced),
    child: MaterialApp(home: child),
  );

  Future<void> pumpCover(WidgetTester tester, {bool reduced = false}) =>
      tester.pumpWidget(
        host(
          const SplashGate(child: Center(child: Text('app debajo'))),
          reduced: reduced,
        ),
      );

  testWidgets('la portada tapa la app desde el primer frame', (tester) async {
    await pumpCover(tester);

    // La app ya está montada detrás: la portada no retrasa el init.
    expect(find.text('app debajo'), findsOneWidget);
    expect(find.byType(UrbanoLogo), findsOneWidget);
    expect(find.text('URBANO'), findsOneWidget);
    expect(find.text('Muévete por Santa Cruz'), findsOneWidget);
  });

  testWidgets('se levanta sola al terminar su línea de tiempo', (tester) async {
    await pumpCover(tester);

    // A media coreografía sigue tapando.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('URBANO'), findsOneWidget);

    // Pasado el total (1500 ms) la portada ya no está en el árbol: ni opacidad
    // 0 ni ticker esperando, así que ningún `pumpAndSettle` posterior la ve.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.text('URBANO'), findsNothing);
    expect(find.byType(SplashGate), findsOneWidget);
    expect(find.text('app debajo'), findsOneWidget);
  });

  testWidgets('con «reducir animaciones» no hay portada', (tester) async {
    await pumpCover(tester, reduced: true);
    await tester.pumpAndSettle();

    expect(find.text('URBANO'), findsNothing);
    expect(find.byType(UrbanoLogo), findsNothing);
    expect(find.text('app debajo'), findsOneWidget);
  });
}
