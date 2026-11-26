import 'package:latlong2/latlong.dart';

import 'journey_place.dart';

/// Distancia mínima (línea recta) entre origen y destino para planificar en
/// transporte: por debajo, caminar es más rápido. Coincide con el guard del
/// backend (`MIN_TRANSIT_DISTANCE_M` en journey.service.ts).
const double minTransitDistanceM = 150.0;

/// Distancia en línea recta entre dos extremos, o `null` si falta alguno.
double? endpointsDistanceMeters(
  JourneyPlace? origin,
  JourneyPlace? destination,
) {
  final src = origin.pointOrNull;
  final dst = destination.pointOrNull;
  if (src == null || dst == null) return null;
  return const Distance().as(
    LengthUnit.Meter,
    LatLng(src.lat, src.lon),
    LatLng(dst.lat, dst.lon),
  );
}

/// Origen y destino están (casi) en el mismo sitio: no hay viaje en micro.
bool endpointsTooClose(JourneyPlace? origin, JourneyPlace? destination) =>
    (endpointsDistanceMeters(origin, destination) ?? double.infinity) <
    minTransitDistanceM;
