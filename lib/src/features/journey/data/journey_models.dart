import 'package:latlong2/latlong.dart';

/// Modelo de respuesta de `GET /journey`.
enum JourneyType { direct, transfer }

extension JourneyTypeX on JourneyType {
  String get label => switch (this) {
    JourneyType.direct => 'Directo',
    JourneyType.transfer => '1 transbordo',
  };
}

enum JourneyLegKind { walk, bus, transfer }

/// Parada referenciada en un tramo de caminata o de micro
/// (`walkToStop`, `walkFromStop`, `fromStop`, `toStop`).
class JourneyStopRef {
  const JourneyStopRef({
    required this.id,
    required this.name,
    this.distanceMeters,
    this.lat,
    this.lon,
  });

  factory JourneyStopRef.fromJson(Map<String, dynamic> json) => JourneyStopRef(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
    lat: (json['lat'] as num?)?.toDouble(),
    lon: (json['lon'] as num?)?.toDouble(),
  );

  final String id;
  final String name;
  final int? distanceMeters;

  /// Posición de la parada (nula si el backend no la envía).
  final double? lat;
  final double? lon;

  /// Posición como `LatLng` o `null` si no está completa.
  LatLng? get position =>
      lat == null || lon == null ? null : LatLng(lat!, lon!);

  bool get hasPosition => lat != null && lon != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'distanceMeters': distanceMeters,
    'lat': lat,
    'lon': lon,
  };
}

/// Parsea una geometría GeoJSON `LineString` (`[lon, lat]`) a `LatLng`.
///
/// Devuelve `null` si el formato no es el esperado o hay menos de 2 puntos
/// válidos (el caller degrada a línea recta `fromStop` → `toStop`).
List<LatLng>? parseLineString(dynamic raw) {
  if (raw is! Map<String, dynamic>) return null;
  if (raw['type'] != 'LineString') return null;
  final coordinates = raw['coordinates'];
  if (coordinates is! List) return null;
  final points = <LatLng>[];
  for (final entry in coordinates) {
    if (entry is List &&
        entry.length >= 2 &&
        entry[0] is num &&
        entry[1] is num) {
      points.add(
        LatLng((entry[1] as num).toDouble(), (entry[0] as num).toDouble()),
      );
    }
  }
  return points.length >= 2 ? points : null;
}

/// Tramo del viaje: caminata, micro o transbordo.
class JourneyLeg {
  const JourneyLeg({
    required this.kind,
    this.durationMinutes,
    this.distanceMeters,
    this.routeId,
    this.routeShortName,
    this.routeColor,
    this.tripId,
    this.fromStopId,
    this.toStopId,
    this.departAt,
    this.arriveAt,
    this.stops,
    this.fromStop,
    this.toStop,
    this.geometry,
  });

  factory JourneyLeg.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String? ?? 'bus';
    return JourneyLeg(
      kind: switch (rawKind) {
        'walk' => JourneyLegKind.walk,
        'transfer' => JourneyLegKind.transfer,
        _ => JourneyLegKind.bus,
      },
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      routeId: json['routeId'] as String?,
      routeShortName: json['routeShortName'] as String?,
      routeColor: json['routeColor'] as String?,
      tripId: json['tripId'] as String?,
      fromStopId: json['fromStopId'] as String?,
      toStopId: json['toStopId'] as String?,
      departAt: json['departAt'] as String?,
      arriveAt: json['arriveAt'] as String?,
      stops: (json['stops'] as num?)?.toInt(),
      fromStop: json['fromStop'] is Map<String, dynamic>
          ? JourneyStopRef.fromJson(json['fromStop'] as Map<String, dynamic>)
          : null,
      toStop: json['toStop'] is Map<String, dynamic>
          ? JourneyStopRef.fromJson(json['toStop'] as Map<String, dynamic>)
          : null,
      geometry: parseLineString(json['geometry']),
    );
  }

  final JourneyLegKind kind;
  final int? durationMinutes;
  final int? distanceMeters;
  final String? routeId;
  final String? routeShortName;
  final String? routeColor;
  final String? tripId;
  final String? fromStopId;
  final String? toStopId;
  final String? departAt;
  final String? arriveAt;
  final int? stops;

  /// Parada de subida del tramo de micro (con `lat`/`lon`).
  final JourneyStopRef? fromStop;

  /// Parada de bajada del tramo de micro (con `lat`/`lon`).
  final JourneyStopRef? toStop;

  /// Tramo exacto del shape recortado entre `fromStop` y `toStop`
  /// (`null` si la ruta no tiene geometría).
  final List<LatLng>? geometry;

  bool get isBus => kind == JourneyLegKind.bus;
  bool get isWalk => kind == JourneyLegKind.walk;

  /// Puntos dibujables del tramo: la `geometry` si existe; si no, la línea
  /// recta `fromStop` → `toStop` (degrada cuando no hay shape).
  List<LatLng>? get mapPoints {
    final shape = geometry;
    if (shape != null && shape.length >= 2) return shape;
    final from = fromStop?.position;
    final to = toStop?.position;
    if (from != null && to != null) return [from, to];
    return null;
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'durationMinutes': durationMinutes,
    'distanceMeters': distanceMeters,
    'routeId': routeId,
    'routeShortName': routeShortName,
    'routeColor': routeColor,
    'tripId': tripId,
    'fromStopId': fromStopId,
    'toStopId': toStopId,
    'departAt': departAt,
    'arriveAt': arriveAt,
    'stops': stops,
    if (fromStop != null) 'fromStop': fromStop!.toJson(),
    if (toStop != null) 'toStop': toStop!.toJson(),
    'geometry': geometry == null
        ? null
        : {
            'type': 'LineString',
            'coordinates': [
              for (final point in geometry!) [point.longitude, point.latitude],
            ],
          },
  };
}

/// Opción de viaje (directa o con transbordo), ordenada por duración.
class JourneyOption {
  const JourneyOption({
    required this.type,
    required this.departAt,
    required this.arriveAt,
    required this.durationMinutes,
    this.walkToStop,
    this.walkFromStop,
    required this.legs,
  });

  factory JourneyOption.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? 'direct';
    return JourneyOption(
      type: rawType == 'transfer' ? JourneyType.transfer : JourneyType.direct,
      departAt: json['departAt'] as String? ?? '',
      arriveAt: json['arriveAt'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      walkToStop: json['walkToStop'] is Map<String, dynamic>
          ? JourneyStopRef.fromJson(json['walkToStop'] as Map<String, dynamic>)
          : null,
      walkFromStop: json['walkFromStop'] is Map<String, dynamic>
          ? JourneyStopRef.fromJson(
              json['walkFromStop'] as Map<String, dynamic>,
            )
          : null,
      legs: json['legs'] is List
          ? (json['legs'] as List)
                .whereType<Map<String, dynamic>>()
                .map(JourneyLeg.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  final JourneyType type;
  final String departAt;
  final String arriveAt;
  final int durationMinutes;
  final JourneyStopRef? walkToStop;
  final JourneyStopRef? walkFromStop;
  final List<JourneyLeg> legs;

  List<JourneyLeg> get busLegs => legs
      .where((leg) => leg.kind == JourneyLegKind.bus)
      .toList(growable: false);

  /// Tramos de caminata en orden (acceso, transbordos a pie, egreso).
  List<JourneyLeg> get walkLegs => legs
      .where((leg) => leg.kind == JourneyLegKind.walk)
      .toList(growable: false);

  /// `true` si la respuesta trae datos dibujables en el mapa (geometría de
  /// algún tramo de micro o posición de las paradas de caminata).
  bool get hasMapData =>
      busLegs.any((leg) => leg.mapPoints != null) ||
      (walkToStop?.hasPosition ?? false) ||
      (walkFromStop?.hasPosition ?? false);

  /// Paradas relevantes para el mapa: extremos de caminata + subida/baja de
  /// cada tramo de micro (sin duplicados por id).
  Iterable<JourneyStopRef> get stopRefs sync* {
    final seen = <String>{};
    JourneyStopRef? yieldUnique(JourneyStopRef? ref) {
      if (ref == null || ref.id.isEmpty || !seen.add(ref.id)) return null;
      return ref;
    }

    final to = yieldUnique(walkToStop);
    if (to != null) yield to;
    final from = yieldUnique(walkFromStop);
    if (from != null) yield from;
    for (final leg in busLegs) {
      final board = yieldUnique(leg.fromStop);
      if (board != null) yield board;
      final alight = yieldUnique(leg.toStop);
      if (alight != null) yield alight;
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'departAt': departAt,
    'arriveAt': arriveAt,
    'durationMinutes': durationMinutes,
    if (walkToStop != null) 'walkToStop': walkToStop!.toJson(),
    if (walkFromStop != null) 'walkFromStop': walkFromStop!.toJson(),
    'legs': legs.map((leg) => leg.toJson()).toList(),
  };
}
