import 'package:latlong2/latlong.dart';

import '../../stops/data/stop_search_models.dart';

/// Radios de búsqueda que ofrece «Micros cerca» (metros). El backend acepta
/// hasta 2000; más allá de 1 km ya no es «caminar hasta la parada».
const List<int> kNearbyRadii = [300, 500, 1000];

/// Radio por defecto: unas 6 cuadras, lo que se camina sin pensarlo.
const int kNearbyDefaultRadius = 500;

/// Velocidad de caminata para estimar minutos a la parada (4,5 km/h).
const double kWalkMetersPerMinute = 75;

/// Consulta de «Micros cerca»: el punto, cómo se llama y hasta dónde mirar.
///
/// Viaja en la URL de la vista (`/nearby?lat=&lon=&label=&r=`), así que se
/// puede reconstruir desde ahí y compartir el mismo elemento de provider.
class NearbyQuery {
  const NearbyQuery({
    required this.lat,
    required this.lon,
    required this.label,
    this.radiusMeters = kNearbyDefaultRadius,
  });

  /// Lee la consulta de los parámetros de la ruta; `null` si falta el punto.
  static NearbyQuery? fromParams(Map<String, String> params) {
    final lat = double.tryParse(params['lat'] ?? '');
    final lon = double.tryParse(params['lon'] ?? '');
    if (lat == null || lon == null) return null;
    final radius = int.tryParse(params['r'] ?? '') ?? kNearbyDefaultRadius;
    final label = params['label']?.trim();
    return NearbyQuery(
      lat: lat,
      lon: lon,
      label: (label == null || label.isEmpty) ? 'Punto elegido' : label,
      radiusMeters: radius.clamp(100, 2000),
    );
  }

  final double lat;
  final double lon;
  final String label;
  final int radiusMeters;

  LatLng get point => LatLng(lat, lon);

  NearbyQuery withRadius(int radius) =>
      NearbyQuery(lat: lat, lon: lon, label: label, radiusMeters: radius);

  Map<String, String> toParams() => {
    'lat': lat.toStringAsFixed(6),
    'lon': lon.toStringAsFixed(6),
    'label': label,
    'r': '$radiusMeters',
  };

  @override
  bool operator ==(Object other) =>
      other is NearbyQuery &&
      other.lat == lat &&
      other.lon == lon &&
      other.label == label &&
      other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(lat, lon, label, radiusMeters);
}

/// Parada donde subir a un sentido concreto de una línea.
class NearbyBoarding {
  const NearbyBoarding({
    required this.directionId,
    required this.stopId,
    required this.stopName,
    required this.point,
    required this.distanceMeters,
    this.confirmed = true,
  });

  /// 0 = ida, 1 = vuelta.
  final int directionId;
  final String stopId;
  final String stopName;
  final LatLng point;

  /// Distancia en línea recta desde el punto consultado.
  final double distanceMeters;

  /// `false` cuando el feed no dijo qué sentidos sirven la parada (payload
  /// antiguo): la UI lo ofrece sin afirmar que de verdad pasa por ahí.
  final bool confirmed;

  /// Minutos estimados a pie (mínimo 1).
  int get walkMinutes {
    final minutes = (distanceMeters / kWalkMetersPerMinute).ceil();
    return minutes < 1 ? 1 : minutes;
  }
}

/// Una línea que pasa cerca del punto, con sus sentidos disponibles.
class NearbyMicro {
  const NearbyMicro({required this.route, required this.boardings});

  final StopRouteRef route;

  /// Un embarque por sentido que pasa cerca, ordenados por `directionId`.
  final List<NearbyBoarding> boardings;

  /// El embarque más cercano de cualquier sentido.
  NearbyBoarding get nearest =>
      boardings.reduce((a, b) => a.distanceMeters <= b.distanceMeters ? a : b);

  double get distanceMeters => nearest.distanceMeters;

  /// Embarque de un sentido, o `null` si ese sentido no pasa cerca.
  NearbyBoarding? boardingFor(int directionId) {
    for (final b in boardings) {
      if (b.directionId == directionId) return b;
    }
    return null;
  }

  bool get hasBothDirections => boardings.length > 1;
}

/// Agrupa las paradas cercanas por línea.
///
/// Para cada línea y CADA SENTIDO se queda con la parada más cercana que lo
/// sirve: la ida y la vuelta suelen ir por calles (o aceras) distintas, así
/// que «dónde subo» depende del sentido. Una parada sin `directionIds` (feed
/// antiguo) cuenta para los dos sentidos, marcada como no confirmada; una
/// confirmada siempre gana a una supuesta.
///
/// El resultado va ordenado por distancia al embarque más cercano y, a
/// igualdad, por nombre corto (orden estable para la lista).
List<NearbyMicro> groupNearbyMicros(List<StopHit> stops, LatLng origin) {
  const distance = Distance();
  final byRoute = <String, StopRouteRef>{};
  final best = <String, Map<int, NearbyBoarding>>{};

  for (final stop in stops) {
    final point = LatLng(stop.lat, stop.lon);
    final meters = stop.distanceMeters ?? distance(origin, point);
    for (final route in stop.routes) {
      if (route.id.isEmpty) continue;
      byRoute.putIfAbsent(route.id, () => route);
      final known = route.directionIds.isNotEmpty;
      final directions = known ? route.directionIds : const [0, 1];
      final slots = best.putIfAbsent(route.id, () => {});
      for (final directionId in directions) {
        final candidate = NearbyBoarding(
          directionId: directionId,
          stopId: stop.id,
          stopName: stop.name,
          point: point,
          distanceMeters: meters,
          confirmed: known,
        );
        final current = slots[directionId];
        if (current == null || _beats(candidate, current)) {
          slots[directionId] = candidate;
        }
      }
    }
  }

  final micros = [
    for (final entry in best.entries)
      NearbyMicro(
        route: byRoute[entry.key]!,
        boardings: entry.value.values.toList()
          ..sort((a, b) => a.directionId.compareTo(b.directionId)),
      ),
  ];
  micros.sort((a, b) {
    final byDistance = a.distanceMeters.compareTo(b.distanceMeters);
    if (byDistance != 0) return byDistance;
    return a.route.shortName.compareTo(b.route.shortName);
  });
  return micros;
}

/// Un embarque confirmado gana a uno supuesto; entre iguales, el más cercano.
bool _beats(NearbyBoarding candidate, NearbyBoarding current) {
  if (candidate.confirmed != current.confirmed) return candidate.confirmed;
  return candidate.distanceMeters < current.distanceMeters;
}

/// Distancia legible: «80 m», «450 m», «1,2 km».
String formatNearbyDistance(double meters) {
  if (meters < 1000) {
    final rounded = (meters / 10).round() * 10;
    return '${rounded < 10 ? 10 : rounded} m';
  }
  final km = (meters / 1000).toStringAsFixed(1);
  // «1 km», no «1,0 km».
  final trimmed = km.endsWith('.0') ? km.substring(0, km.length - 2) : km;
  return '${trimmed.replaceAll('.', ',')} km';
}

/// Aproximación de un círculo de [radiusMeters] alrededor de [center] como
/// polilínea cerrada (para pintar la zona de búsqueda sobre el mapa).
List<LatLng> circlePath(LatLng center, double radiusMeters, {int steps = 72}) {
  const distance = Distance();
  return [
    for (var i = 0; i <= steps; i++)
      distance.offset(center, radiusMeters, 360 * i / steps),
  ];
}

/// Espaciado de flechas para un trazado de [lengthMeters]: una cada 200 m en
/// recorridos cortos y nunca más de ~45 en una línea que cruza la ciudad
/// (encimadas a zoom bajo se leen como una mancha, no como sentido).
double arrowSpacingFor(double lengthMeters) {
  final spread = lengthMeters / 45;
  return spread > 200 ? spread : 200;
}

/// Longitud total de una polilínea en metros.
double pathLengthMeters(List<LatLng> path) {
  const distance = Distance();
  var total = 0.0;
  for (var i = 1; i < path.length; i++) {
    total += distance(path[i - 1], path[i]);
  }
  return total;
}
