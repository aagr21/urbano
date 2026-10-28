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
