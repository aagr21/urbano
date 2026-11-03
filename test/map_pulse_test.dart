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

  test('el aura se apaga y se achica al alejar el mapa', () {
    // A zoom de calle el latido se ve entero…
    expect(pulsePresence(16), 1.0);
    expect(pulsePresence(15), 1.0);
    expect(pulseRadiusScale(16), 1.0);

    // …y al alejarse se desvanece hasta casi imperceptible (nunca a 0).
    expect(pulsePresence(10), closeTo(0.18, 1e-9));
    expect(pulsePresence(13.75), closeTo(0.59, 1e-9));
    expect(pulsePresence(14), lessThan(pulsePresence(15)));

    // El radio acompaña: lejos los anillos casi se esconden tras el punto.
    expect(pulseRadiusScale(10), lessThan(0.7));
    expect(pulseRadiusScale(10), lessThan(pulseRadiusScale(16)));
  });

  test('cada onda entra sin golpe y se disuelve', () {
    // En los extremos del recorrido la opacidad es 0: al reiniciar su vuelta
    // no hay «flash» (el visto bueno anterior saltaba a plena opacidad).
    expect(pulseWaveGlow(0), 0);
    expect(pulseWaveGlow(1), 0);
    // Sube rápido en el primer tramo, con el pico cerca del arranque…
    expect(pulseWaveGlow(0.2), greaterThan(0.5));
    expect(pulseWaveGlow(0.35), greaterThan(pulseWaveGlow(0.9)));
    // …y el final del recorrido es casi invisible: la onda no se corta.
    expect(pulseWaveGlow(0.9), lessThan(0.05));
    expect(pulseWaveGlow(0.02), lessThan(0.1));
  });

  test('el anillo flota hacia fuera y frena (easeOut)', () {
    expect(pulseWaveGrowth(0), 0);
    expect(pulseWaveGrowth(1), MapPulse.growth);
    // Ya a mitad de vuelta recorrió la mayor parte del camino…
    expect(pulseWaveGrowth(0.5), greaterThan(MapPulse.growth * 0.6));
    // …y nunca vuelve hacia dentro.
    for (var i = 1; i <= 20; i++) {
      expect(
        pulseWaveGrowth(i / 20),
        greaterThan(pulseWaveGrowth((i - 1) / 20)),
      );
    }
  });

  test('el halo respira entre 0 y 1', () {
    expect(pulseBreath(0), closeTo(0.5, 1e-9));
    expect(pulseBreath(0.25), closeTo(1.0, 1e-9));
    expect(pulseBreath(0.75), closeTo(0.0, 1e-9));
  });
}
