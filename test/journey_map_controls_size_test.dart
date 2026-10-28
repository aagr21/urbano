import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/location/location_fab.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/widgets/map_tile_button.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_map_button.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_map_controls.dart';

void main() {
  testWidgets('columna de controles del mapa: un solo diámetro', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          child: Scaffold(
            body: JourneyMapControls(
              onZoomIn: () {},
              onZoomOut: () {},
              onOpenMicros: () async {},
              microsActive: false,
              tracking: false,
              onFollowChanged: (_) {},
              fullscreen: false,
              onToggleFullscreen: () {},
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(MapCircleButton).first);
    expect(size.width, AppControl.mapButton);
    expect(size.height, AppControl.mapButton);
    // Todos los botones de estilo MapCircleButton miden lo mismo (2 zoom,
    // micros y pantalla completa).
    final count = tester.widgetList(find.byType(MapCircleButton)).length;
    for (var i = 0; i < count; i++) {
      final dim = tester.getSize(find.byType(MapCircleButton).at(i));
      expect(dim.width, AppControl.mapButton);
      expect(dim.height, AppControl.mapButton);
    }
    // El FAB de ubicación y el brillo compartelan diámetro.
    final fab = tester.getSize(find.byType(LocationFab));
    expect(fab.width, AppControl.mapButton);
    expect(fab.height, AppControl.mapButton);
    final toggle = tester.getSize(find.byType(MapTileButton));
    expect(toggle.width, AppControl.mapButton);
    expect(toggle.height, AppControl.mapButton);
  });
}
