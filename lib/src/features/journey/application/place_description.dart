import '../domain/journey_place.dart';

/// Texto con el que se rotula un lugar del planeador en historial y guardados.
typedef PlaceDescription = ({String label, String? subtitle});

/// Deriva el rótulo y el contexto de un [JourneyPlace].
///
/// Vive aquí (y no en cada controlador) porque historial y viajes guardados
/// deben rotular exactamente igual: mismo nombre, mismo fallback de
/// coordenadas, mismo "Lugar de Santa Cruz".
PlaceDescription describePlace(JourneyPlace place) {
  return switch (place) {
    JourneyPlacePoi(:final name, :final subtitle) => (
      label: name,
      subtitle: subtitle == null || subtitle.trim().isEmpty
          ? 'Lugar de Santa Cruz'
          : subtitle,
    ),
    JourneyPlacePoint(:final address, :final lat, :final lon) => (
      label: address ?? '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
      subtitle: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
    ),
    JourneyPlaceLocation(:final address, :final lat, :final lon) => (
      label: address ?? 'Mi ubicación',
      subtitle: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
    ),
  };
}

/// Ordena de más reciente a más antiguo y recorta a [maxEntries].
List<T> sortedByLastUsed<T>(
  List<T> items,
  DateTime Function(T item) lastUsed, {
  required int maxEntries,
}) {
  final list = [...items]..sort((a, b) => lastUsed(b).compareTo(lastUsed(a)));
  return list.length <= maxEntries ? list : list.sublist(0, maxEntries);
}
