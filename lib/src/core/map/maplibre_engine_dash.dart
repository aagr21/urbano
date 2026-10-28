part of 'maplibre_engine.dart';

const double _dashOnMeters = 14;
const double _dashOffMeters = 11;
const double _dashStepMeters = 3;

/// Divide [points] en tramos "pintado" (~14 m) y "hueco" (~11 m) siguiendo la
/// geometría real, para pintarlos como varias `Line` (MapLibre no expone
/// `line-dasharray` por anotación).
List<List<LatLng>> _dashSegments(List<LatLng> points) {
  final path = _resample(points, _dashStepMeters);
  if (path.length < 2) return [points];

  final segments = <List<LatLng>>[];
  var current = <LatLng>[path.first];
  var remaining = _dashOnMeters;
  var drawing = true;

  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1];
    final b = path[i];
    final total = _haversineMeters(a, b);
    if (total <= 0) continue;
    var position = 0.0;
    while (position < total) {
      final take = math.min(total - position, remaining);
      final start = _lerp(a, b, position / total);
      final end = _lerp(a, b, (position + take) / total);
      if (drawing) {
        if (current.isEmpty || _haversineMeters(current.last, start) > 0.5) {
          current.add(start);
        }
        current.add(end);
      }
      position += take;
      remaining -= take;
      if (remaining <= 1e-9) {
        if (drawing && current.length >= 2) segments.add(current);
        current = <LatLng>[end];
        drawing = !drawing;
        remaining = drawing ? _dashOnMeters : _dashOffMeters;
      }
    }
  }
  if (drawing && current.length >= 2) segments.add(current);
  return segments;
}

/// Remuestrea la polilínea cada [stepMeters] metros manteniendo la forma.
List<LatLng> _resample(List<LatLng> points, double stepMeters) {
  if (points.length < 2) return List.of(points);
  final out = <LatLng>[points.first];
  var carry = 0.0;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final segment = _haversineMeters(a, b);
    if (segment <= 0) continue;
    var fromA = carry;
    while (fromA + stepMeters <= segment) {
      fromA += stepMeters;
      out.add(_lerp(a, b, fromA / segment));
    }
    carry = segment - fromA;
  }
  out.add(points.last);
  return out;
}

double _haversineMeters(LatLng a, LatLng b) {
  const radius = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * radius * math.asin(math.min(1, math.sqrt(h)));
}

LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
  a.latitude + (b.latitude - a.latitude) * t,
  a.longitude + (b.longitude - a.longitude) * t,
);
