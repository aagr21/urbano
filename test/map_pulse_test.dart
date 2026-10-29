import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/map/map_tile.dart';
import 'package:urbano/src/core/map/map_types.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/theme/map_theme_controller.dart';
import 'package:urbano/src/core/widgets/urbano_map.dart';

/// Store en memoria: `flutter test` no toca plugins (misma regla que
/// `map_theme_test.dart`).
class _MemoryMapThemeStore implements MapThemeStore {
  @override
  Future<MapTile?> load() async => null;

  @override
  Future<void> save(MapTile? tile) async {}
}

const _me = LatLng(-17.7833, -63.1821);

const _pulse = MapPulse(point: _me, color: Colors.blue);

/// Monta la fachada con el motor simulado (`showTiles: false`) y espera a que
/// el [Ambient] del aura llegue a su reposo acotado.
Future<void> _pumpMap(WidgetTester tester, List<MapPulse> pulses) async {
  final container = ProviderContainer(
    overrides: [
      mapThemeStoreProvider.overrideWithValue(_MemoryMapThemeStore()),
      mapThemeControllerProvider.overrideWith(
        () => MapThemeController.preloaded(null),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: UrbanoMap(center: _me, showTiles: false, pulses: pulses),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los pulsos llegan a la escena del motor', (tester) async {
    await _pumpMap(tester, const [_pulse]);

    final engine = tester.widget<FakeMapEngine>(find.byType(FakeMapEngine));
    expect(engine.scene.pulses, hasLength(1));
    expect(engine.scene.pulses.single.point, _me);
  });

  testWidgets('el aura se pinta como capa propia (no como marcador)', (
    tester,
  ) async {
    int pulsePainters() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter != null)
        .length;

    await _pumpMap(tester, const []);
    final withoutPulse = pulsePainters();

    await _pumpMap(tester, const [_pulse]);
    final withPulse = pulsePainters();

    // El motor simulado añade UN `CustomPaint` por pulso (las polilíneas van
    // siempre), así que el aura no puede confundirse con un marcador.
    expect(withPulse, withoutPulse + 1);
    expect(tester.takeException(), isNull);
  });
}
