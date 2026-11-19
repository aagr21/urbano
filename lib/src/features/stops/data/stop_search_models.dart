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

  factory StopHit.fromJson(Map<String, dynamic> json) {
    // Dedup: el feed declara la MISMA línea una vez por orientación, así que
    // las duplicaciones SON el sentido. Colapsarlas tirando la segunda perdería
    // la información de ida/vuelta; se une el `directionIds` de todas las
    // apariciones y se conserva la primera (orden y color del feed).
    final byId = <String, StopRouteRef>{};
    for (final raw
        in ((json['routes'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()) {
      final route = StopRouteRef.fromJson(raw);
      final seen = byId[route.id];
      byId[route.id] = seen == null ? route : seen.mergedWith(route);
    }
    return StopHit(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      routes: byId.values.toList(growable: false),
    );
  }

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
///
/// `longName`, `imageUrl` y `directionIds` llegaron al contrato de `/stops`
/// para que la tarjeta de un lugar pueda decir TRAYECTO, FOTO y en qué SENTIDO
/// para ahí ese micro sin pagar un `/routes/:id` por línea (N+1). Son opcionales
/// porque el feed viejo y los fixtures de test pueden no traerlos.
class StopRouteRef {
  const StopRouteRef({
    required this.id,
    required this.shortName,
    required this.color,
    this.longName,
    this.imageUrl,
    this.directionIds = const <int>[],
  });

  factory StopRouteRef.fromJson(Map<String, dynamic> json) => StopRouteRef(
    id: json['id'] as String? ?? '',
    shortName: json['shortName'] as String? ?? '',
    color: json['color'] as String? ?? '64748B',
    longName: json['longName'] as String?,
    imageUrl: json['imageUrl'] as String?,
    directionIds: _directionIds(json['directionIds']),
  );

  final String id;
  final String shortName;
  final String color;

  /// Trayecto escrito (`route_long_name`); `null` si el feed no lo tiene.
  final String? longName;

  /// Foto real del micro (`backend/micros.csv`); `null` si la línea no tiene.
  final String? imageUrl;

  /// Sentidos que sirven ESTA parada (0 = ida, 1 = vuelta). Vacío = desconocido
  /// (payload antiguo): la UI debe asumir ambos sin afirmarlo.
  final List<int> directionIds;

  /// Une dos apariciones de la misma línea: sentidos en unón ordenada y el
  /// primer dato no nulo de cada campo visual.
  StopRouteRef mergedWith(StopRouteRef other) => StopRouteRef(
    id: id,
    shortName: shortName,
    color: color,
    longName: longName ?? other.longName,
    imageUrl: imageUrl ?? other.imageUrl,
    directionIds: <int>{...directionIds, ...other.directionIds}.toList()
      ..sort(),
  );

  static List<int> _directionIds(Object? raw) {
    if (raw is! List) return const <int>[];
    final ids = raw.whereType<num>().map((e) => e.toInt()).toSet();
    final sorted = ids.toList()..sort();
    return List<int>.unmodifiable(sorted);
  }
}
