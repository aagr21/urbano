import 'package:latlong2/latlong.dart';

/// Resumen de ruta (`RouteSummary` del contrato).
class RouteSummary {
  const RouteSummary({
    required this.id,
    required this.shortName,
    required this.longName,
    required this.color,
    required this.textColor,
    required this.description,
    required this.type,
    required this.directionsCount,
    required this.stopCount,
    required this.tripCount,
    this.imageUrl,
  });

  factory RouteSummary.fromJson(Map<String, dynamic> json) => RouteSummary(
    id: json['id'] as String? ?? '',
    shortName: json['shortName'] as String? ?? '',
    longName: json['longName'] as String? ?? '',
    color: json['color'] as String? ?? '64748B',
    textColor: json['textColor'] as String? ?? 'FFFFFF',
    description: json['description'] as String? ?? '',
    type: (json['type'] as num?)?.toInt() ?? 3,
    directionsCount: _directionsCount(json['directions']),
    stopCount: (json['stopCount'] as num?)?.toInt() ?? 0,
    tripCount: (json['tripCount'] as num?)?.toInt() ?? 0,
    imageUrl: json['imageUrl'] as String?,
  );

  final String id;
  final String shortName;
  final String longName;
  final String color;
  final String textColor;
  final String description;

  /// Tipo GTFS (3 = bus).
  final int type;

  /// En `/routes` viene como número; en `/routes/:id` como lista de objetos.
  final int directionsCount;
  final int stopCount;
  final int tripCount;

  /// Imagen del itinerario (micros.csv en el backend) o null si no hay.
  final String? imageUrl;

  static int _directionsCount(dynamic directions) {
    if (directions is num) return directions.toInt();
    if (directions is List) return directions.length;
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shortName': shortName,
    'longName': longName,
    'color': color,
    'textColor': textColor,
    'description': description,
    'type': type,
    'directions': directionsCount,
    'stopCount': stopCount,
    'tripCount': tripCount,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
}

/// Dirección de una ruta (Ida/Vuelta).
class RouteDirection {
  const RouteDirection({
    required this.directionId,
    required this.headsign,
    required this.tripId,
    required this.firstDeparture,
    required this.lastDeparture,
    required this.headwaySeconds,
    required this.stopCount,
  });

  factory RouteDirection.fromJson(Map<String, dynamic> json) => RouteDirection(
    directionId: (json['directionId'] as num?)?.toInt() ?? 0,
    headsign: json['headsign'] as String? ?? '',
    tripId: json['tripId'] as String? ?? '',
    firstDeparture: json['firstDeparture'] as String?,
    lastDeparture: json['lastDeparture'] as String?,
    headwaySeconds: (json['headwaySeconds'] as num?)?.toInt(),
    stopCount: (json['stopCount'] as num?)?.toInt() ?? 0,
  );

  final int directionId;
  final String headsign;
  final String tripId;
  final String? firstDeparture;
  final String? lastDeparture;
  final int? headwaySeconds;
  final int stopCount;

  Map<String, dynamic> toJson() => {
    'directionId': directionId,
    'headsign': headsign,
    'tripId': tripId,
    'firstDeparture': firstDeparture,
    'lastDeparture': lastDeparture,
    'headwaySeconds': headwaySeconds,
    'stopCount': stopCount,
  };
}

/// GeoJSON `LineString` del recorrido (`shape`).
class RouteShape {
  const RouteShape({this.id, required this.points});

  factory RouteShape.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final coordinates = geometry is Map<String, dynamic>
        ? geometry['coordinates']
        : null;
    return RouteShape(
      id: (json['properties'] is Map<String, dynamic>)
          ? (json['properties'] as Map<String, dynamic>)['id'] as String?
          : null,
      points: _parsePoints(coordinates),
    );
  }

  final String? id;
  final List<LatLng> points;

  static List<LatLng> _parsePoints(dynamic coordinates) {
    if (coordinates is! List) return const [];
    final points = <LatLng>[];
    for (final item in coordinates) {
      if (item is List && item.length >= 2) {
        final lon = item[0];
        final lat = item[1];
        if (lon is num && lat is num) {
          points.add(LatLng(lat.toDouble(), lon.toDouble()));
        }
      }
    }
    return points;
  }

  Map<String, dynamic> toJson() => {
    'type': 'Feature',
    'properties': {if (id != null) 'id': id},
    'geometry': {
      'type': 'LineString',
      'coordinates': [
        for (final p in points) [p.longitude, p.latitude],
      ],
    },
  };
}

/// Detalle completo de ruta (`RouteDetail` = resumen + bbox/dir/shape).
class RouteDetail extends RouteSummary {
  const RouteDetail({
    required super.id,
    required super.shortName,
    required super.longName,
    required super.color,
    required super.textColor,
    required super.description,
    required super.type,
    required super.directionsCount,
    required super.stopCount,
    required super.tripCount,
    super.imageUrl,
    required this.bbox,
    required this.directions,
    required this.shape,
  });

  factory RouteDetail.fromJson(Map<String, dynamic> json) {
    final summary = RouteSummary.fromJson(json);
    final rawDirections = json['directions'];
    final rawShape = json['shape'];
    return RouteDetail(
      id: summary.id,
      shortName: summary.shortName,
      longName: summary.longName,
      color: summary.color,
      textColor: summary.textColor,
      description: summary.description,
      type: summary.type,
      directionsCount: summary.directionsCount,
      stopCount: summary.stopCount,
      tripCount: summary.tripCount,
      imageUrl: summary.imageUrl,
      bbox:
          (json['bbox'] as List?)
              ?.whereType<num>()
              .map((v) => v.toDouble())
              .toList(growable: false) ??
          const [],
      directions: rawDirections is List
          ? rawDirections
                .whereType<Map<String, dynamic>>()
                .map(RouteDirection.fromJson)
                .toList(growable: false)
          : const [],
      shape: rawShape is Map<String, dynamic>
          ? RouteShape.fromJson(rawShape)
          : null,
    );
  }

  /// `[west, south, east, north]`.
  final List<double> bbox;
  final List<RouteDirection> directions;
  final RouteShape? shape;

  /// Dirección por id (o la primera por defecto).
  RouteDirection? directionById(int? directionId) {
    if (directions.isEmpty) return null;
    for (final direction in directions) {
      if (direction.directionId == directionId) return direction;
    }
    return directions.first;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'bbox': bbox,
    'directions': directions.map((d) => d.toJson()).toList(),
    if (shape != null) 'shape': shape!.toJson(),
  };
}

/// Referencia ligera a ruta (en listados de paradas).
class RouteRef {
  const RouteRef({
    required this.id,
    required this.shortName,
    required this.color,
    this.textColor,
  });

  factory RouteRef.fromJson(Map<String, dynamic> json) => RouteRef(
    id: json['id'] as String? ?? '',
    shortName: json['shortName'] as String? ?? json['id'] as String? ?? '',
    color: json['color'] as String? ?? '64748B',
    textColor: json['textColor'] as String?,
  );

  final String id;
  final String shortName;
  final String color;
  final String? textColor;

  Map<String, dynamic> toJson() => {
    'id': id,
    'shortName': shortName,
    'color': color,
    if (textColor != null) 'textColor': textColor,
  };
}

/// Próxima salida (`/routes/:id/departures`).
class Departure {
  const Departure({
    required this.tripId,
    required this.directionId,
    required this.headsign,
    required this.time,
    required this.realTime,
    required this.headwaySeconds,
  });

  factory Departure.fromJson(Map<String, dynamic> json) => Departure(
    tripId: json['tripId'] as String? ?? '',
    directionId: (json['directionId'] as num?)?.toInt() ?? 0,
    headsign: json['headsign'] as String? ?? '',
    time: json['time'] as String? ?? '',
    realTime: json['realTime'] as bool? ?? false,
    headwaySeconds: (json['headwaySeconds'] as num?)?.toInt(),
  );

  final String tripId;
  final int directionId;
  final String headsign;
  final String time;
  final bool realTime;
  final int? headwaySeconds;

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'directionId': directionId,
    'headsign': headsign,
    'time': time,
    'realTime': realTime,
    'headwaySeconds': headwaySeconds,
  };
}

/// Parada del recorrido (`/routes/:id/stops?directionId=`), EN ORDEN de
/// tránsito. De ella se derivan los «lugares principales» que muestra el
/// detalle (calles/vías de referencia, no cada esquina).
class RouteStop {
  const RouteStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.sequence,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble() ?? 0,
    lon: (json['lon'] as num?)?.toDouble() ?? 0,
    sequence: (json['sequence'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String name;
  final double lat;
  final double lon;
  final int sequence;
}
