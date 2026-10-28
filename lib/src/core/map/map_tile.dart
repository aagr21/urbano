import 'package:flutter/material.dart';

import 'map_styles.dart';

/// Paleta con la que se pinta la **miniatura** de una capa en el selector.
///
/// Son colores del dibujo del mapa (no de la interfaz): por eso viven aquí,
/// junto al [MapTile] que representan, y no en `AppColors`.
class MapLayerPreviewPalette {
  const MapLayerPreviewPalette({
    required this.canvas,
    required this.street,
    required this.arterial,
    required this.block,
    required this.park,
    required this.water,
    required this.route,
  });

  /// Fondo del mini-mapa.
  final Color canvas;

  /// Calles finas de la retícula.
  final Color street;

  /// Avenidas (más gruesas, en diagonal).
  final Color arterial;

  /// Manzanas entre calles.
  final Color block;

  final Color park;
  final Color water;

  /// Recorrido destacado de micro que dibuja la miniatura.
  final Color route;
}

/// Capa base del mapa que el usuario puede elegir.
///
/// Sustituye al antiguo toggle claro↔oscuro: cada opción declara su propio
/// [brightness], que solo afecta al **mapa base** (estilo, fondo, placeholder
/// mientras carga Google). Los overlays —botones, chips, paneles, hojas— siguen
/// siempre el tema de la app: elegir «Oscuro» no re-tematiza la interfaz.
/// La selección `null` en el controller significa "sigue al tema de la app" y
/// se resuelve con [MapTile.resolve].
///
/// En la interfaz se habla de **capas**, nunca de «tiles»: lo que cambia es la
/// capa que se ve debajo de la ruta, no un conjunto de teselas.
enum MapTile {
  /// MapTiler OpenStreetMap (vectorial, claro).
  osm,

  /// Google Maps "roadmap" (ráster, claro). Requiere clave de Map Tiles API.
  googleRoadmap,

  /// Google Maps "satellite" (imágenes, oscuro). Requiere clave de Map Tiles API.
  googleSatellite,

  /// MapTiler dataviz-dark (vectorial, oscuro).
  dark;

  /// Capa efectiva del MAPA dados el brillo de la app [appDark] y la elección
  /// guardada [choice].
  ///
  /// `null` (sin elección) = la capa por defecto del brillo de la app:
  /// [MapTile.osm] con app clara, [MapTile.dark] con app oscura — el
  /// comportamiento histórico.
  static MapTile resolve({required bool appDark, MapTile? choice}) =>
      choice ?? (appDark ? MapTile.dark : MapTile.osm);
}

/// Metadatos de presentación y renderizado de cada [MapTile] (capa del mapa).
extension MapTileInfo on MapTile {
  /// Brillo del mapa que pinta esta capa (fondo, placeholder y carga nativa).
  Brightness get brightness => switch (this) {
    MapTile.osm || MapTile.googleRoadmap => Brightness.light,
    MapTile.dark || MapTile.googleSatellite => Brightness.dark,
  };

  /// Si el estilo se sirve desde Google (necesita sesión + clave en runtime).
  bool get isGoogle =>
      this == MapTile.googleRoadmap || this == MapTile.googleSatellite;

  /// Nombre visible de la capa (se usa en avisos y en la píldora de atribución).
  String get label => switch (this) {
    MapTile.osm => 'OpenStreetMap',
    MapTile.googleRoadmap => 'Google Maps',
    MapTile.googleSatellite => 'Google Satélite',
    MapTile.dark => 'Oscuro',
  };

  /// Nombre corto de la capa: el título grande de la tarjeta del selector.
  String get shortLabel => switch (this) {
    MapTile.osm => 'Mapa',
    MapTile.googleRoadmap => 'Mapas',
    MapTile.googleSatellite => 'Satélite',
    MapTile.dark => 'Oscuro',
  };

  /// Proveedor de la capa, en segunda línea de la tarjeta.
  String get provider => switch (this) {
    MapTile.osm => 'OpenStreetMap',
    MapTile.googleRoadmap || MapTile.googleSatellite => 'Google',
    MapTile.dark => 'MapTiler',
  };

  /// Ícono de la capa en el selector.
  IconData get icon => switch (this) {
    MapTile.osm => Icons.map_rounded,
    MapTile.googleRoadmap => Icons.layers_rounded,
    MapTile.googleSatellite => Icons.satellite_alt_rounded,
    MapTile.dark => Icons.bedtime_rounded,
  };

  /// Paleta con la que [MapLayerPreview] dibuja el mini-mapa de la tarjeta.
  MapLayerPreviewPalette get preview => switch (this) {
    MapTile.osm => const MapLayerPreviewPalette(
      canvas: Color(0xFFEAF1F8),
      street: Color(0xFFFFFFFF),
      arterial: Color(0xFFFDF0C9),
      block: Color(0xFFD8E2EC),
      park: Color(0xFFC7E8C8),
      water: Color(0xFFB9DDF2),
      route: Color(0xFF008C7B),
    ),
    MapTile.googleRoadmap => const MapLayerPreviewPalette(
      canvas: Color(0xFFF1EFE9),
      street: Color(0xFFFCFBF7),
      arterial: Color(0xFFF6C36B),
      block: Color(0xFFE3DFD4),
      park: Color(0xFFC9E3BD),
      water: Color(0xFFA9CBE8),
      route: Color(0xFF4285F4),
    ),
    MapTile.googleSatellite => const MapLayerPreviewPalette(
      canvas: Color(0xFF242A1F),
      street: Color(0xFF9A9E92),
      arterial: Color(0xFFCBC9B4),
      block: Color(0xFF3A4032),
      park: Color(0xFF2F4128),
      water: Color(0xFF16262F),
      route: Color(0xFF3BE0CE),
    ),
    MapTile.dark => const MapLayerPreviewPalette(
      canvas: Color(0xFF1B1B1E),
      street: Color(0xFF3A3A40),
      arterial: Color(0xFF4A4A52),
      block: Color(0xFF252529),
      park: Color(0xFF22332E),
      water: Color(0xFF1D2A34),
      route: Color(0xFF4FE3D0),
    ),
  };

  /// Estilo síncrono (URL `style.json` de MapTiler). `null` para las capas
  /// Google, cuyo `styleString` se construye en runtime tras crear la sesión.
  String? get staticStyle => switch (this) {
    MapTile.osm => UrbanoMapStyles.light,
    MapTile.dark => UrbanoMapStyles.dark,
    MapTile.googleRoadmap || MapTile.googleSatellite => null,
  };

  /// `mapType` para el `createSession` de la Map Tiles API.
  String get sessionMapType => switch (this) {
    MapTile.googleSatellite => 'satellite',
    MapTile.osm || MapTile.dark || MapTile.googleRoadmap => 'roadmap',
  };

  /// Color de fondo del lienzo (carga nativa y motor simulado) a juego con la
  /// capa, para fundir sin destello mientras llegan las teselas.
  Color get backgroundColor => switch (this) {
    MapTile.osm => const Color(0xFFE8EEF5),
    MapTile.dark => const Color(0xFF292929),
    MapTile.googleRoadmap => const Color(0xFFDDDDDD),
    MapTile.googleSatellite => const Color(0xFF20211F),
  };

  /// Texto de atribución de la superficie simulada (el motor real muestra el
  /// control nativo de MapLibre, que lee la atribución del estilo/ráster).
  String get attribution =>
      isGoogle ? 'Imágenes ©2026 Google' : '© OpenStreetMap · © MapTiler';
}
