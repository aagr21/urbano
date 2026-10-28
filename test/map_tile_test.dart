import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/map/google_tiles_session.dart';
import 'package:urbano/src/core/map/map_styles.dart';
import 'package:urbano/src/core/map/map_tile.dart';
import 'package:urbano/src/core/widgets/map_layer_preview.dart';

/// Unit tests puros del tile del mapa: metadatos de [MapTile] y el constructor
/// de estilo ráster de Google. No tocan red ni plugins (regla del repo).
void main() {
  group('MapTile (metadatos)', () {
    test('resolve: sin elección el tile sigue al brillo de la app', () {
      expect(MapTile.resolve(appDark: false), MapTile.osm);
      expect(MapTile.resolve(appDark: true), MapTile.dark);
    });

    test('resolve: una elección fijada manda sobre el brillo de la app', () {
      expect(
        MapTile.resolve(appDark: false, choice: MapTile.dark),
        MapTile.dark,
      );
      expect(MapTile.resolve(appDark: true, choice: MapTile.osm), MapTile.osm);
      expect(
        MapTile.resolve(appDark: true, choice: MapTile.googleRoadmap),
        MapTile.googleRoadmap,
      );
    });

    test('cada tile declara su brillo', () {
      expect(MapTile.osm.brightness, Brightness.light);
      expect(MapTile.googleRoadmap.brightness, Brightness.light);
      expect(MapTile.dark.brightness, Brightness.dark);
      expect(MapTile.googleSatellite.brightness, Brightness.dark);
    });

    test('solo los tiles Google van por sesión', () {
      expect(MapTile.osm.isGoogle, isFalse);
      expect(MapTile.dark.isGoogle, isFalse);
      expect(MapTile.googleRoadmap.isGoogle, isTrue);
      expect(MapTile.googleSatellite.isGoogle, isTrue);
    });

    test('los no-Google tienen estilo síncrono; los Google, no', () {
      expect(MapTile.osm.staticStyle, UrbanoMapStyles.light);
      expect(MapTile.dark.staticStyle, UrbanoMapStyles.dark);
      expect(MapTile.googleRoadmap.staticStyle, isNull);
      expect(MapTile.googleSatellite.staticStyle, isNull);
    });

    test('los nombres visibles son únicos', () {
      final labels = MapTile.values.map((t) => t.label).toList();
      expect(labels.toSet().length, labels.length);
      expect(
        labels,
        containsAll(<String>[
          'OpenStreetMap',
          'Google Maps',
          'Google Satélite',
          'Oscuro',
        ]),
      );
    });

    test('cada capa tiene nombre corto y proveedor para la tarjeta', () {
      // El selector dice «capa», nunca «tile»: título corto + proveedor debajo.
      final shortLabels = MapTile.values.map((t) => t.shortLabel).toList();
      expect(shortLabels.toSet().length, shortLabels.length);
      expect(MapTile.osm.shortLabel, 'Mapa');
      expect(MapTile.googleRoadmap.provider, 'Google');
      expect(MapTile.googleSatellite.provider, 'Google');
      expect(MapTile.dark.provider, 'MapTiler');
      expect(MapTile.osm.provider, 'OpenStreetMap');
    });

    test('cada capa tiene una paleta de miniatura coherente con su brillo', () {
      for (final tile in MapTile.values) {
        final p = tile.preview;
        // Campos completos y sin transparentes: la miniatura se pinta sola.
        for (final c in [
          p.canvas,
          p.street,
          p.arterial,
          p.block,
          p.park,
          p.water,
          p.route,
        ]) {
          expect(c.a, 1.0, reason: '${tile.name} pinta con alpha');
        }
        // El lienzo de la miniatura acompaña el brillo declarado de la capa.
        final darkCanvas = p.canvas.computeLuminance() < 0.5;
        expect(darkCanvas, tile.brightness == Brightness.dark);
      }
    });

    test('mapType de sesión: satélite vs roadmap', () {
      expect(MapTile.googleSatellite.sessionMapType, 'satellite');
      expect(MapTile.googleRoadmap.sessionMapType, 'roadmap');
    });

    test('fondo a juego con el brillo del tile', () {
      // El oscuro/satélite pintan lienzo tenue; el claro/roadmap, claro.
      expect(
        MapTile.dark.backgroundColor.computeLuminance(),
        lessThan(MapTile.osm.backgroundColor.computeLuminance()),
      );
      expect(
        MapTile.googleSatellite.backgroundColor.computeLuminance(),
        lessThan(MapTile.googleRoadmap.backgroundColor.computeLuminance()),
      );
    });

    test('atribución: Google vs OpenStreetMap', () {
      expect(MapTile.osm.attribution, contains('OpenStreetMap'));
      expect(MapTile.dark.attribution, contains('MapTiler'));
      expect(MapTile.googleRoadmap.attribution, contains('Google'));
      expect(MapTile.googleSatellite.attribution, contains('Google'));
    });
  });

  group('MapLayerPreview (miniaturas del selector)', () {
    testWidgets('pinta cada capa sin desbordes ni excepciones', (tester) async {
      for (final tile in MapTile.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  // Tamaño de tarjeta del selector y de la pastilla automática.
                  width: tile == MapTile.osm ? 132 : 46,
                  height: tile == MapTile.osm ? 78 : 34,
                  child: MapLayerPreview(
                    tile: tile,
                    showRoute: tile == MapTile.osm,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: tile.name);
        expect(find.byType(MapLayerPreview), findsOneWidget);
      }
    });
  });

  group('buildGoogleStyleJson (estilo ráster de Google, sin red)', () {
    final session = GoogleSession(
      session: 'SESSION_TOKEN',
      expiresAt: DateTime(2026),
      tileWidth: 512,
    );

    Map<String, dynamic> decode(String tile) =>
        jsonDecode(tile) as Map<String, dynamic>;

    test('es JSON MapLibre v8 con fuente ráster y capa de fondo', () {
      final json = buildGoogleStyleJson(
        tile: MapTile.googleRoadmap,
        session: session,
        apiKey: 'API_KEY',
      );
      final style = decode(json);

      expect(style['version'], 8);
      final sources = style['sources'] as Map<String, dynamic>;
      final google = sources['google'] as Map<String, dynamic>;
      expect(google['type'], 'raster');
      expect(google['tileSize'], 512);
      expect(google['scheme'], 'xyz');
      expect(style['layers'], isA<List<dynamic>>());
    });

    test('la URL de teselas lleva {z}/{x}/{y}, session y key', () {
      final json = buildGoogleStyleJson(
        tile: MapTile.googleSatellite,
        session: session,
        apiKey: 'API_KEY',
      );
      final style = decode(json);
      final google =
          (style['sources'] as Map<String, dynamic>)['google']
              as Map<String, dynamic>;
      final tiles = google['tiles'] as List<dynamic>;
      final url = tiles.single as String;

      expect(url, contains('tile.googleapis.com/v1/2dtiles/{z}/{x}/{y}'));
      expect(url, contains('session=SESSION_TOKEN'));
      expect(url, contains('key=API_KEY'));
    });

    test('el color de fondo coincide con el del tile', () {
      final json = buildGoogleStyleJson(
        tile: MapTile.googleSatellite,
        session: session,
        apiKey: 'API_KEY',
      );
      final style = decode(json);
      final layer =
          (style['layers'] as List<dynamic>).single as Map<String, dynamic>;
      final paint = layer['paint'] as Map<String, dynamic>;
      final expected =
          '#${(MapTile.googleSatellite.backgroundColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

      expect(layer['type'], 'background');
      expect(paint['background-color'], expected);
    });
  });
}
