import '../../../core/location/place_search.dart';
import '../data/popular_places.dart';
import '../data/saved_trips.dart';
import '../data/trip_history.dart';
import '../domain/journey_place.dart';

/// Traduce cada fuente de lugares (hito popular, calle de OSM, viaje guardado,
/// historial) a un [JourneyPlace]. Una sola casa para estas conversiones: la
/// hoja de destino y las filas del historial de la portada las compartían
/// copiadas a mano.
abstract final class JourneyPlaceFactory {
  /// Hito popular de Santa Cruz; su contexto es el anillo/zona o, si falta,
  /// la categoría.
  static JourneyPlacePoi fromPoi(SantaCruzPoi poi) => JourneyPlacePoi(
    name: poi.name,
    lat: poi.lat,
    lon: poi.lon,
    subtitle: poi.ringOrZone ?? poi.category,
  );

  /// Calle o lugar sugerido por OSM.
  static JourneyPlacePoi fromSuggestion(PlaceSuggestion hit) => JourneyPlacePoi(
    name: hit.name,
    lat: hit.lat,
    lon: hit.lon,
    subtitle: hit.subtitle,
  );

  /// Origen de un viaje guardado: se trata como la ubicación de entonces.
  static JourneyPlaceLocation originOf(SavedTrip trip) => JourneyPlaceLocation(
    lat: trip.originLat,
    lon: trip.originLon,
    address: trip.originLabel,
  );

  /// Destino de un viaje guardado.
  static JourneyPlacePoi destinationOf(SavedTrip trip) => JourneyPlacePoi(
    name: trip.destinationLabel,
    lat: trip.destinationLat,
    lon: trip.destinationLon,
    subtitle: trip.destinationSubtitle,
  );

  /// Destino de una fila del historial.
  static JourneyPlacePoi fromHistory(TripHistoryEntry entry) => JourneyPlacePoi(
    name: entry.label,
    lat: entry.lat,
    lon: entry.lon,
    subtitle: entry.subtitle,
  );

  /// Posición del teléfono como origen.
  static JourneyPlaceLocation here({
    required double lat,
    required double lon,
  }) => JourneyPlaceLocation(lat: lat, lon: lon);
}
