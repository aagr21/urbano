import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/widgets/loading_shimmer.dart';

/// Reproduce el bug histórico: el esqueleto dentro de un contenedor más
/// pequeño que su contenido NO debe lanzar "bottom overflowed".
void main() {
  testWidgets('SkeletonList no desborda con poca altura disponible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(height: 140, child: SkeletonList())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SkeletonCard), findsWidgets);
    expect(tester.takeException(), isNull);

    // Desmontar cancela los timers de la animación infinita del shimmer.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('SkeletonList respeta el número de tarjetas solicitado', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SkeletonList(count: 3, leading: 52),
          ),
        ),
      ),
    );
    // Sin pumpAndSettle: el shimmer anima en bucle infinito.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SkeletonCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
