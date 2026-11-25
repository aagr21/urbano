import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/nearby/presentation/nearby_search_widgets.dart';

/// Los accesos de la hoja de «Lugares» se miden con la fuente REAL: bajo
/// `flutter test` el texto es Ahem (un cuadrado por glifo) y no diría nada de
/// si «Marcar en el mapa» entra en un teléfono.
void main() {
  setUpAll(() async {
    final loader = FontLoader('Inter');
    for (final file in Directory('assets/fonts').listSync()) {
      if (file.path.contains('Inter-')) {
        final bytes = File(file.path).readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
    }
    await loader.load();
  });

  /// Los dos accesos como en la hoja (5/11 y 6/11 del ancho), con el margen
  /// lateral de la hoja (`AppSpace.lg + 4` a cada lado).
  Future<void> pumpActions(WidgetTester tester, double screenWidth) async {
    tester.view.physicalSize = Size(screenWidth * 2.75, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg + 4),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: NearbyQuickAction(
                    icon: Icons.near_me_rounded,
                    label: 'Mi ubicación',
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  flex: 6,
                  child: NearbyQuickAction(
                    icon: Icons.add_location_alt_rounded,
                    label: 'Marcar en el mapa',
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// ¿El texto entra entero a tamaño real en la caja que le toca?
  bool fitsAtFullSize(WidgetTester tester, String label) {
    final text = tester.getSize(find.text(label));
    final box = tester.getSize(
      find.ancestor(of: find.text(label), matching: find.byType(FittedBox)),
    );
    return text.width <= box.width + 0.5;
  }

  testWidgets('en un teléfono (393 dp) «Marcar en el mapa» se lee entero', (
    tester,
  ) async {
    await pumpActions(tester, 393);
    for (final label in ['Mi ubicación', 'Marcar en el mapa']) {
      final widget = tester.widget<Text>(find.text(label));
      expect(widget.overflow, isNot(TextOverflow.ellipsis), reason: label);
      expect(fitsAtFullSize(tester, label), isTrue, reason: label);
    }
  });

  testWidgets('en pantalla angosta (320 dp) se achica, sin cortarse', (
    tester,
  ) async {
    await pumpActions(tester, 320);
    expect(
      find.ancestor(
        of: find.text('Marcar en el mapa'),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
