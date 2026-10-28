import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/core/widgets/urbano_map.dart';
import 'package:urbano/src/features/journey/data/journey_repository.dart';
import 'package:urbano/src/features/journey/presentation/map_picker_screen.dart';

List<Override> _overrides() => [
  myLocationProvider.overrideWith(
    (ref) async => const LatLng(-17.7833, -63.1821),
  ),
];

Widget _launcher(
  void Function(JourneyPoint?) onResult,
  List<Override> overrides, {
  JourneyPoint? initial,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open-picker'),
            onPressed: () {
              Navigator.push<JourneyPoint>(
                context,
                MaterialPageRoute(
                  builder: (_) => MapPickerScreen(
                    title: 'Origen',
                    initial: initial,
                    showTiles: false,
                  ),
                ),
              ).then(onResult);
            },
            child: const Text('abrir selector'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('MapPickerScreen devuelve el punto confirmado', (tester) async {
    JourneyPoint? picked;
    await tester.pumpWidget(
      _launcher(
        (point) => picked = point,
        _overrides(),
        initial: const (lat: -17.78, lon: -63.15),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();

    // Título y acción principal.
    expect(find.text('Origen'), findsOneWidget);
    expect(find.text('Usar este punto'), findsOneWidget);

    await tester.tap(find.text('Usar este punto'));
    await tester.pumpAndSettle();

    // Devuelve las coordenadas del centro del pin.
    expect(picked, isNotNull);
    expect(picked!.lat, closeTo(-17.78, 0.0001));
    expect(picked!.lon, closeTo(-63.15, 0.0001));
  });

  testWidgets(
    'el pin queda fijo en el centro: mover el mapa cambia la coordenada',
    (tester) async {
      JourneyPoint? picked;
      await tester.pumpWidget(
        _launcher(
          (point) => picked = point,
          _overrides(),
          initial: const (lat: -17.78, lon: -63.15),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-picker')));
      await tester.pumpAndSettle();

      // El pin está clavado en el centro: su punta (borde inferior) toca el
      // centro exacto de la pantalla.
      final screen = tester.getSize(find.byType(MapPickerScreen));
      final pin = tester.getRect(find.byType(MapsPin));
      expect(pin.center.dx, closeTo(screen.width / 2, 1));
      expect(pin.bottom, closeTo(screen.height / 2, 2));

      // Mover el mapa NO mueve el pin, pero sí cambia la coordenada elegida.
      const moved = LatLng(-17.79, -63.17);
      tester
          .state<FakeMapEngineState>(find.byType(FakeMapEngine))
          .moveCamera(moved, 15);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(MapsPin)),
        pin,
        reason: 'el pin debe seguir clavado en el centro al mover el mapa',
      );

      await tester.tap(find.text('Usar este punto'));
      await tester.pumpAndSettle();

      expect(picked!.lat, closeTo(-17.79, 0.0001));
      expect(picked!.lon, closeTo(-63.17, 0.0001));
    },
  );

  testWidgets('muestra la coordenada exacta que se va a devolver', (
    tester,
  ) async {
    JourneyPoint? picked;
    await tester.pumpWidget(
      _launcher(
        (point) => picked = point,
        _overrides(),
        initial: const (lat: -17.78, lon: -63.15),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-picker')));
    await tester.pumpAndSettle();

    // El chip refleja el punto inicial.
    expect(find.text('Punto: -17.78000, -63.15000'), findsOneWidget);

    // Y se actualiza solo al mover el mapa (mismo debounce que la parada).
    tester
        .state<FakeMapEngineState>(find.byType(FakeMapEngine))
        .moveCamera(const LatLng(-17.80123, -63.17456), 15);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Punto: -17.80123, -63.17456'), findsOneWidget);

    await tester.tap(find.text('Usar este punto'));
    await tester.pumpAndSettle();

    // Lo que se muestra es exactamente lo que se guarda.
    expect(picked!.lat, closeTo(-17.80123, 1e-6));
    expect(picked!.lon, closeTo(-63.17456, 1e-6));
  });

  testWidgets('el mapa del picker no pide tiles en tests', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MapPickerScreen(showTiles: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El pin del centro y la barra inferior están presentes.
    expect(find.byType(MapsPin), findsOneWidget);
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
