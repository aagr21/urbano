part of 'maplibre_engine.dart';

ml.LatLng _toMl(LatLng point) => ml.LatLng(point.latitude, point.longitude);

/// `maplibre_gl.LatLng` → `latlong2.LatLng`.
LatLng _toLatLng(ml.LatLng point) => LatLng(point.latitude, point.longitude);

extension on ml.LatLng {
  LatLng toLatLong() => LatLng(latitude, longitude);
}

/// Firma estable de la lista de polilíneas (para detectar cambios).
String _linesSignature(List<MapPolyline> polylines) {
  final buffer = StringBuffer();
  for (final line in polylines) {
    buffer
      ..write(_hex(line.color))
      ..write('|')
      ..write(line.width)
      ..write('|')
      ..write(line.opacity)
      ..write('|')
      ..write(line.outline)
      ..write(_hex(line.outlineColor))
      ..write('|')
      ..write(line.dashed)
      ..write('|');
    for (final point in line.points) {
      buffer
        ..write(point.latitude.toStringAsFixed(6))
        ..write(',')
        ..write(point.longitude.toStringAsFixed(6))
        ..write(';');
    }
    buffer.writeln();
  }
  return buffer.toString();
}

/// `Color` → `#RRGGBB` (formato que espera `LineOptions.lineColor`).
String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _anchorOf(MapMarker marker) => switch (marker.anchor) {
  MapMarkerAnchor.center => 'center',
  MapMarkerAnchor.top => 'top',
  MapMarkerAnchor.bottom => 'bottom',
};
