import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Una flecha de sentido sobre el trazado de un micro: dónde va y hacia dónde
/// apunta (`bearing` en grados, 0 = norte, sentido horario).
typedef RouteArrow = ({LatLng point, double bearing});

/// Reparte flechas cada [spacingMeters] metros a lo largo de [path].
///
/// Una sola pasada: cada flecha se interpola dentro de su segmento y hereda
/// el rumbo de ESE segmento, así que no hace falta buscar después "el segmento
/// más cercano" (que en curvas cerradas elegía el equivocado). La distancia
/// sobrante de un segmento se arrastra al siguiente, de modo que el espaciado
/// es uniforme aunque el shape tenga vértices muy juntos o tramos rectos de
/// varios cientos de metros (en esos tramos caen varias flechas).
///
/// Devuelve vacío si [path] tiene menos de dos puntos o [spacingMeters] no es
/// positivo (un espaciado de 0 no termina nunca).
List<RouteArrow> arrowsAlongPath(List<LatLng> path, double spacingMeters) {
  if (path.length < 2 || !(spacingMeters > 0)) return const [];
  const distance = Distance();
  final arrows = <RouteArrow>[];
  // Metros recorridos desde la última flecha (o desde el inicio del trazado).
  var sinceLast = 0.0;

  for (var i = 0; i < path.length - 1; i++) {
    final a = path[i];
    final b = path[i + 1];
    final segment = distance(a, b);
    if (segment <= 0) continue;

    final bearing = bearingBetween(a, b);
    // Posición, medida desde `a`, de la próxima flecha dentro del segmento.
    var at = spacingMeters - sinceLast;
    while (at <= segment) {
      final ratio = at / segment;
      arrows.add((
        point: LatLng(
          a.latitude + (b.latitude - a.latitude) * ratio,
          a.longitude + (b.longitude - a.longitude) * ratio,
        ),
        bearing: bearing,
      ));
      at += spacingMeters;
    }
    // Lo que queda del segmento después de la última flecha colocada en él.
    sinceLast = segment - (at - spacingMeters);
  }
  return arrows;
}

/// Rumbo inicial de [a] a [b] en grados (0 = norte, sentido horario).
double bearingBetween(LatLng a, LatLng b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
