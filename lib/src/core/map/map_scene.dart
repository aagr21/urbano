import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'map_projection.dart';
import 'map_styles.dart';
import 'map_types.dart';

/// Descripción completa de lo que un motor de mapa debe dibujar y de los
/// eventos que debe reenviar.
///
/// La fachada [UrbanoMap] construye un [MapScene] por build y se lo pasa al
/// motor activo (`MapLibreEngine` o `FakeMapEngine`), de modo que ambos
/// comparten exactamente la misma API pública.
@immutable
class MapScene {
  const MapScene({
    required this.center,
    required this.zoom,
    this.cameraFit,
    this.polylines = const <MapPolyline>[],
    this.markers = const <MapMarker>[],
    this.interactive = true,
    this.showTiles = true,
    this.dark = false,
    this.styleOverride,
    this.backgroundOverride,
    this.minZoom = 4,
    this.maxZoom = 18,
    this.myLocationEnabled = false,
    this.followMyLocation = false,
    this.onMapReady,
    this.onTap,
    this.onPositionChanged,
    this.onMarkerTap,
    this.onMarkerDragStart,
    this.onMarkerDragUpdate,
    this.onMarkerDragEnd,
    this.onTrackingDismissed,
  });

  /// Centro inicial (ignorado si hay [cameraFit]).
  final LatLng center;
  final double zoom;

  /// Encuadre inicial sobre bounds (con padding y maxZoom).
  final MapCameraFit? cameraFit;

  final List<MapPolyline> polylines;
  final List<MapMarker> markers;

  /// `false` bloquea gestos (preview no interactiva).
  final bool interactive;

  /// `false` => sin tiles: la fachada usa el motor simulado.
  final bool showTiles;

  /// Tema claro/oscuro (elige estilo y fondo por defecto).
  final bool dark;

  /// `styleString` explícito del tile elegido (p. ej. el JSON ráster de Google).
  /// `null` → el derivado de [dark] (URL MapTiler claro/oscuro), el
  /// comportamiento histórico.
  final String? styleOverride;

  /// Color de fondo explícito del tile. `null` → el derivado de [dark].
  final Color? backgroundOverride;

  final double minZoom;
  final double maxZoom;

  /// Punto de "mi ubicación" en el mapa (puck) y si la cámara lo sigue.
  final bool myLocationEnabled;
  final bool followMyLocation;

  final VoidCallback? onMapReady;
  final MapTapCallback? onTap;
  final MapPositionChangedCallback? onPositionChanged;
  final MapMarkerTapCallback? onMarkerTap;
  final MapMarkerCallback? onMarkerDragStart;
  final MapMarkerCallback? onMarkerDragUpdate;
  final MapMarkerCallback? onMarkerDragEnd;

  /// El usuario dejó de seguir su ubicación (pan sobre el puck).
  final VoidCallback? onTrackingDismissed;

  /// URL/JSON del estilo según el tile ([styleOverride]) o el tema por defecto.
  String get styleString =>
      styleOverride ?? (dark ? UrbanoMapStyles.dark : UrbanoMapStyles.light);

  /// Color de fondo del lienzo (igual que el estilo para evitar parpadeos).
  ///
  /// El oscuro replica el `background` de *dataviz-dark* (`hsl(0, 0%, 16%)`
  /// = `#292929`), el claro el de *openstreetmap*.
  Color get background =>
      backgroundOverride ??
      (dark ? const Color(0xFF292929) : const Color(0xFFE8EEF5));

  /// Cámara inicial resuelta para un viewport concreto.
  MapCamera cameraFor(Size viewport) {
    final fit = cameraFit;
    if (fit == null) return MapCamera(center: center, zoom: zoom);
    return MapProjection.fitBounds(
      fit.bounds,
      viewport: viewport,
      padding: fit.padding,
      minZoom: minZoom,
      maxZoom: fit.maxZoom,
    );
  }

  MapScene copyWith({
    List<MapPolyline>? polylines,
    List<MapMarker>? markers,
    MapCameraFit? cameraFit,
    bool? clearCameraFit,
  }) => MapScene(
    center: center,
    zoom: zoom,
    cameraFit: (clearCameraFit ?? false) ? null : cameraFit ?? this.cameraFit,
    polylines: polylines ?? this.polylines,
    markers: markers ?? this.markers,
    interactive: interactive,
    showTiles: showTiles,
    dark: dark,
    styleOverride: styleOverride,
    backgroundOverride: backgroundOverride,
    minZoom: minZoom,
    maxZoom: maxZoom,
    myLocationEnabled: myLocationEnabled,
    followMyLocation: followMyLocation,
    onMapReady: onMapReady,
    onTap: onTap,
    onPositionChanged: onPositionChanged,
    onMarkerTap: onMarkerTap,
    onMarkerDragStart: onMarkerDragStart,
    onMarkerDragUpdate: onMarkerDragUpdate,
    onMarkerDragEnd: onMarkerDragEnd,
    onTrackingDismissed: onTrackingDismissed,
  );
}
