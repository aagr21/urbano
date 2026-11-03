/// Punto geográfico del origen/destino del viaje.
typedef JourneyPoint = ({double lat, double lon});

/// Selección de origen/destino ("mi ubicación", punto del mapa o un POI).
sealed class JourneyPlace {
  const JourneyPlace();

  String get label;
}

class JourneyPlaceLocation extends JourneyPlace {
  const JourneyPlaceLocation({required this.lat, required this.lon});

  final double lat;
  final double lon;

  @override
  String get label => 'Mi ubicación';
}

/// Punto elegido en el mapa (selector de origen/destino).
///
/// El origen/destino es SIEMPRE el punto marcado por el usuario, nunca una
/// parada GTFS: el planificador usa la parada más cercana solo como punto de
/// subida/baja y calcula la caminata hasta el punto exacto.
class JourneyPlacePoint extends JourneyPlace {
  const JourneyPlacePoint({required this.lat, required this.lon});

  final double lat;
  final double lon;

  @override
  String get label =>
      'Punto en el mapa · ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
}

/// Hito o lugar de interés común en Santa Cruz (mercado, plaza, hospital, etc.).
class JourneyPlacePoi extends JourneyPlace {
  const JourneyPlacePoi({
    required this.name,
    required this.lat,
    required this.lon,
    this.subtitle,
  });

  final String name;
  final String? subtitle;
  final double lat;
  final double lon;

  @override
  String get label => name;
}

/// Punto geográfico del lugar elegido, o `null` si no hay lugar.
extension JourneyPlacePointX on JourneyPlace? {
  JourneyPoint? get pointOrNull => switch (this) {
    null => null,
    JourneyPlaceLocation(:final lat, :final lon) => (lat: lat, lon: lon),
    JourneyPlacePoint(:final lat, :final lon) => (lat: lat, lon: lon),
    JourneyPlacePoi(:final lat, :final lon) => (lat: lat, lon: lon),
  };
}
