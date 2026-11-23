import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Distancia haversine (m) entre dos coordenadas, radio terrestre medio.
/// La usa el motor del mapa para los trazos discontinuos y el resampleo;
/// interna de `core/utils` para que no haya 3 copias repartidas por la app.
double haversineMeters(LatLng a, LatLng b) {
  const earthRadiusM = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

/// Bearing (grados, 0 = norte, sentido horario) de [a] hacia [b].
///
/// Lo usa el motor de mapa para orientar las cabezas de flecha en el sentido
/// real de avance del recorrido.
double bearingDegrees(LatLng a, LatLng b) {
  double rad(double degrees) => degrees * math.pi / 180;
  final lat1 = rad(a.latitude);
  final lat2 = rad(b.latitude);
  final dLon = rad(b.longitude - a.longitude);
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
