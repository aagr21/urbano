import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/utils/image_decode.dart';

void main() {
  Future<({int? width, int? height})> decode(
    WidgetTester tester, {
    double? width,
    double? height,
  }) async {
    late ({int? width, int? height}) result;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2.75),
        child: Builder(
          builder: (context) {
            result = imageDecodeSize(
              context,
              logicalWidth: width,
              logicalHeight: height,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('una caja diminuta (foto que se abre animando) nunca da 0', (
    tester,
  ) async {
    // 0,1 dp × 2,75 = 0,275 px: con `round()` era 0 y `Image` fallaba con
    // `cacheWidth == null || cacheWidth > 0`.
    final size = await decode(tester, width: 0.1, height: 0.05);
    expect(size.width, decodeStep);
    expect(size.height, decodeStep);
  });

  testWidgets('redondea hacia arriba en escalones y respeta el máximo', (
    tester,
  ) async {
    // 64 dp × 2,75 = 176 px → escalón de 256.
    expect((await decode(tester, width: 64)).width, 256);
    // 360 dp × 2,75 = 990 px → 1024.
    expect((await decode(tester, width: 360)).width, 1024);
    expect((await decode(tester, width: 5000)).width, 1600);
  });

  testWidgets('sin medida (o inválida) deja el tamaño por defecto', (
    tester,
  ) async {
    final size = await decode(tester, width: double.infinity, height: 0);
    expect(size.width, isNull);
    expect(size.height, isNull);
  });

  testWidgets('tamaños vecinos de una animación comparten escalón', (
    tester,
  ) async {
    final a = (await decode(tester, width: 100)).width;
    final b = (await decode(tester, width: 110)).width;
    expect(a, b, reason: '275 y 302,5 px caen en el escalón de 384');
  });
}
