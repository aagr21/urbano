import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'map_types.dart';

/// Proyección Web Mercator usada por los dos motores.
///
/// El motor simulado la usa para pintar líneas/marcadores sin plataforma, y
/// ambos motores la usan para encuadrar bounds (`MapCameraFit`) de forma
/// determinista en Dart en lugar de depender de la plataforma.
class MapProjection {
  MapProjection._();

  static const double _tileSize = 256;

  /// Longitud → X normalizado [0, 1].
  static double lngToX(double longitude) => (longitude + 180) / 360;

  /// Latitud → Y normalizado [0, 1] (0 = norte).
  static double latToY(double latitude) {
    final sinLat = math
        .sin(latitude * math.pi / 180)
        .clamp(-0.9999, 0.9999)
        .toDouble();
    return 0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi);
  }

  static double xToLng(double x) => x * 360 - 180;

  static double yToLat(double y) {
    final n = math.pi * (1 - 2 * y);
    return 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }

  /// Tamaño del mundo en pixels para un zoom dado.
  static double worldSize(double zoom) =>
      _tileSize * math.pow(2.0, zoom).toDouble();

  /// Proyecta [point] a un pixel del viewport con la cámara dada.
  static Offset project(
    LatLng point, {
    required LatLng center,
    required double zoom,
    required Size viewport,
  }) {
    final world = worldSize(zoom);
    var dx = (lngToX(point.longitude) - lngToX(center.longitude)) * world;
    // Envuelve en el lado más corto (mapa que cruza el antimeridiano).
    if (dx > world / 2) dx -= world;
    if (dx < -world / 2) dx += world;
    final dy = (latToY(point.latitude) - latToY(center.latitude)) * world;
    return Offset(viewport.width / 2 + dx, viewport.height / 2 + dy);
  }

  /// Invierte [project].
  static LatLng unproject(
    Offset pixel, {
    required LatLng center,
    required double zoom,
    required Size viewport,
  }) {
    final world = worldSize(zoom);
    final x =
        lngToX(center.longitude) + (pixel.dx - viewport.width / 2) / world;
    final y =
        latToY(center.latitude) + (pixel.dy - viewport.height / 2) / world;
    return LatLng(yToLat(y), xToLng(x));
  }

  /// Cámara que encuadra [bounds] dentro de [viewport] con [padding].
  ///
  /// Devuelve el centro y el zoom (limitado a `minZoom..maxZoom`).
  static MapCamera fitBounds(
    MapBounds bounds, {
    required Size viewport,
    EdgeInsets padding = EdgeInsets.zero,
    double minZoom = 4,
    double maxZoom = 17,
  }) {
    if (viewport.isEmpty || viewport.width <= 0 || viewport.height <= 0) {
      return MapCamera(center: bounds.center, zoom: maxZoom);
    }

    final dx =
        (lngToX(bounds.northeast.longitude) -
                lngToX(bounds.southwest.longitude))
            .abs();
    final dy =
        (latToY(bounds.southwest.latitude) - latToY(bounds.northeast.latitude))
            .abs();

    final availableWidth = math.max(1.0, viewport.width - padding.horizontal);
    final availableHeight = math.max(1.0, viewport.height - padding.vertical);

    var zoom = maxZoom;
    if (dx > 0) {
      zoom = math.min(zoom, _zoomFor(availableWidth / (dx * _tileSize)));
    }
    if (dy > 0) {
      zoom = math.min(zoom, _zoomFor(availableHeight / (dy * _tileSize)));
    }
    zoom = zoom.clamp(minZoom, maxZoom).toDouble();

    // El centro de los bounds debe caer en el centro *disponible* del
    // viewport (teniendo en cuenta paddings asimétricos).
    final world = worldSize(zoom);
    final centerX =
        (lngToX(bounds.southwest.longitude) +
            lngToX(bounds.northeast.longitude)) /
        2;
    final centerY =
        (latToY(bounds.southwest.latitude) +
            latToY(bounds.northeast.latitude)) /
        2;
    final offsetPixelsX = (padding.left - padding.right) / 2;
    final offsetPixelsY = (padding.top - padding.bottom) / 2;
    final cameraX = centerX - offsetPixelsX / world;
    final cameraY = centerY - offsetPixelsY / world;

    return MapCamera(
      center: LatLng(yToLat(cameraY), xToLng(cameraX)),
      zoom: zoom,
    );
  }

  /// Zoom al que [ratio] (pixels disponibles / pixels necesarios) vale 1.
  static double _zoomFor(double ratio) => math.log(ratio) / math.ln2;
}
