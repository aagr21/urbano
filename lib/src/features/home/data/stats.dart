/// `GET /stats` — datos del dashboard/home.
class Stats {
  const Stats({
    required this.routes,
    required this.stops,
    required this.trips,
    required this.shapes,
    required this.service,
    required this.firstDeparture,
    required this.lastDeparture,
    required this.headwaySeconds,
  });

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
    routes: (json['routes'] as num?)?.toInt() ?? 0,
    stops: (json['stops'] as num?)?.toInt() ?? 0,
    trips: (json['trips'] as num?)?.toInt() ?? 0,
    shapes: (json['shapes'] as num?)?.toInt() ?? 0,
    service: json['service'] is Map<String, dynamic>
        ? ServiceWindow.fromJson(json['service'] as Map<String, dynamic>)
        : const ServiceWindow.empty(),
    firstDeparture: json['firstDeparture'] as String? ?? '',
    lastDeparture: json['lastDeparture'] as String? ?? '',
    headwaySeconds: (json['headwaySeconds'] as num?)?.toInt() ?? 0,
  );

  final int routes;
  final int stops;
  final int trips;
  final int shapes;
  final ServiceWindow service;
  final String firstDeparture;
  final String lastDeparture;
  final int headwaySeconds;

  Map<String, dynamic> toJson() => {
    'routes': routes,
    'stops': stops,
    'trips': trips,
    'shapes': shapes,
    'service': service.toJson(),
    'firstDeparture': firstDeparture,
    'lastDeparture': lastDeparture,
    'headwaySeconds': headwaySeconds,
  };
}

/// Ventana de servicio del feed GTFS.
class ServiceWindow {
  const ServiceWindow({
    required this.start,
    required this.end,
    required this.days,
  });

  const ServiceWindow.empty() : this(start: '', end: '', days: '');

  factory ServiceWindow.fromJson(Map<String, dynamic> json) => ServiceWindow(
    start: json['start'] as String? ?? '',
    end: json['end'] as String? ?? '',
    days: json['days'] as String? ?? '',
  );

  final String start;
  final String end;
  final String days;

  Map<String, dynamic> toJson() => {'start': start, 'end': end, 'days': days};
}

/// `GET /health` — versión del API/backend.
class HealthInfo {
  const HealthInfo({
    required this.status,
    required this.db,
    required this.uptime,
    required this.version,
  });

  factory HealthInfo.fromJson(Map<String, dynamic> json) => HealthInfo(
    status: json['status'] as String? ?? 'unknown',
    db: json['db'] as String? ?? 'unknown',
    uptime: (json['uptime'] as num?)?.toDouble() ?? 0,
    version: json['version'] as String? ?? '—',
  );

  final String status;
  final String db;
  final double uptime;
  final String version;

  bool get isOk => status == 'ok';
}
