import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/home/presentation/widgets/home_action_tiles.dart';

/// Los cuatro accesos de Inicio se miden con la fuente REAL (Montserrat): bajo
/// `flutter test` el texto es Ahem y no diría si «Rutas, paradas y horarios»
/// entra en un teléfono angosto. En un Honor (~366 dp) se cortaba con «…».
void main() {
  setUpAll(() async {
    final loader = FontLoader('Montserrat');
    for (final file in Directory('assets/fonts').listSync()) {
      if (file.path.contains('Montserrat-') && file.path.endsWith('.ttf')) {
        final bytes = File(file.path).readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
    }
    await loader.load();
  });

  for (final width in const [360.0, 393.0]) {
    testWidgets('a $width dp ningún acceso corta su texto', (tester) async {
      tester.view.physicalSize = Size(width * 3, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: HomeActionTiles()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in const [
        'Rutas, paradas y horarios',
        'Planifica tu trayecto',
        'Qué micro pasa cerca',
        'Reporta y ayúdanos a mejorar',
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
      // Los títulos van en `FittedBox(scaleDown)`: al ancho del diseño
      // (393 dp) entran sin achicarse; en el teléfono más angosto pueden ceder
      // un poco, nunca hasta volverse letra chica.
      final minScale = width >= 393 ? 1.0 : 0.8;
      for (final title in const ['Micros', 'Viajes', 'Lugares', 'Denuncias']) {
        final text = tester.getSize(find.text(title));
        final box = tester.getSize(
          find.ancestor(of: find.text(title), matching: find.byType(FittedBox)),
        );
        expect(
          (box.width + 0.5) / text.width,
          greaterThanOrEqualTo(minScale),
          reason: title,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
