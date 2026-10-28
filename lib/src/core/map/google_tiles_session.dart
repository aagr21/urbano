import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Color, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'map_tile.dart';

/// Sesión de la Map Tiles API de Google: token con caducidad y ancho de tesela.
@immutable
class GoogleSession {
  const GoogleSession({
    required this.session,
    required this.expiresAt,
    required this.tileWidth,
  });

  final String session;
  final DateTime expiresAt;
  final int tileWidth;
}

/// Construye el `style.json` ráster de MapLibre para un tile de Google a partir
/// de una [session] ya creada. Es una función pura (sin red) para poder
/// probarla sin tocar la API.
///
/// `maplibre_gl` acepta JSON crudo como `styleString`; la URL conserva los
/// marcadores `{z}/{x}/{y}` que el motor sustituye por tesela.
String buildGoogleStyleJson({
  required MapTile tile,
  required GoogleSession session,
  required String apiKey,
}) {
  final url =
      'https://tile.googleapis.com/v1/2dtiles/{z}/{x}/{y}'
      '?session=${session.session}&key=$apiKey';
  return jsonEncode(<String, dynamic>{
    'version': 8,
    'sources': <String, dynamic>{
      'google': <String, dynamic>{
        'type': 'raster',
        'tiles': <String>[url],
        'tileSize': session.tileWidth,
        'scheme': 'xyz',
        'attribution': tile.attribution,
      },
    },
    'layers': <dynamic>[
      <String, dynamic>{
        'id': 'background',
        'type': 'background',
        'paint': <String, dynamic>{
          'background-color': _hex(tile.backgroundColor),
        },
      },
    ],
  });
}

String _hex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}

/// Cliente de la Map Tiles API: crea y cachea sesiones, arma el estilo ráster.
///
/// Las sesiones caducan (~2 semanas), así que se reutiliza la cacheada mientras
/// quede más de un día de validez y se refresca cerca de la expiración.
class GoogleTilesService {
  final Dio _dio = Dio();

  /// Cache por `mapType` (roadmap/satellite comparten endpoint pero no sesión).
  final Map<String, GoogleSession> _sessions = <String, GoogleSession>{};

  Future<GoogleSession> _sessionFor(String mapType) async {
    final now = DateTime.now();
    final cached = _sessions[mapType];
    if (cached != null && cached.expiresAt.difference(now).inHours > 24) {
      return cached;
    }
    final response = await _dio.postUri<dynamic>(
      Uri.parse(
        'https://tile.googleapis.com/v1/createSession?key=${Env.googleMapsApiKey}',
      ),
      data: <String, dynamic>{
        'mapType': mapType,
        'language': 'es',
        'region': 'BO',
      },
    );
    final data = response.data as Map<String, dynamic>;
    final session = data['session'] as String;
    final expirySeconds = int.parse(data['expiry'] as String);
    final tileWidth = (data['tileWidth'] as num?)?.toInt() ?? 256;
    final created = GoogleSession(
      session: session,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expirySeconds * 1000),
      tileWidth: tileWidth,
    );
    _sessions[mapType] = created;
    return created;
  }

  /// `styleString` ráster listo para MapLibre del tile [tile] (Google).
  Future<String> styleJson(MapTile tile) async {
    final session = await _sessionFor(tile.sessionMapType);
    return buildGoogleStyleJson(
      tile: tile,
      session: session,
      apiKey: Env.googleMapsApiKey,
    );
  }
}

/// Cliente único de Google Tiles (una cache de sesiones por run de la app).
final googleTilesServiceProvider = Provider<GoogleTilesService>(
  (ref) => GoogleTilesService(),
);

/// Estilo ráster resuelto para un tile de Google (crea la sesión bajo demanda).
/// Solo se observa para [MapTile.isGoogle]; los tiles MapTiler usan su
/// [MapTileInfo.staticStyle] síncrono. Bajo `flutter test` el motor es
/// `FakeMapEngine` (`showTiles: false`), así que este provider nunca corre.
final googleStyleProvider = FutureProvider.family<String, MapTile>(
  (ref, tile) => ref.watch(googleTilesServiceProvider).styleJson(tile),
);
