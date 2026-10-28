/// Resultado de la búsqueda de lugares: una parada del feed con las líneas
/// (vía `/stops/search`) o la cercanía al usuario (`/stops/nearby`, que trae
/// `distanceMeters`) y las micros que la sirven.
class StopHit {
  const StopHit({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.routes,
    this.distanceMeters,
  });

  factory StopHit.fromJson(Map<String, dynamic> json) => StopHit(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble() ?? 0,
    lon: (json['lon'] as num?)?.toDouble() ?? 0,
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    routes: ((json['routes'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StopRouteRef.fromJson)
        .toList(growable: false),
  );

  final String id;
  final String name;
  final double lat;
  final double lon;

  /// Solo lo llena `/stops/nearby` (distancia al punto consultado).
  final double? distanceMeters;

  /// Líneas que pasan exactamente por esta parada.
  final List<StopRouteRef> routes;
}

/// Referencia mínima de línea para el chip-bad de un resultado.
class StopRouteRef {
  const StopRouteRef({
    required this.id,
    required this.shortName,
    required this.color,
  });

  factory StopRouteRef.fromJson(Map<String, dynamic> json) => StopRouteRef(
    id: json['id'] as String? ?? '',
    shortName: json['shortName'] as String? ?? '',
    color: json['color'] as String? ?? '64748B',
  );

  final String id;
  final String shortName;
  final String color;
}
