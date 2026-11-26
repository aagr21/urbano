import '../../../core/location/place_search.dart';
import '../data/popular_places.dart';

/// Qué elegir cuando el usuario pulsa Enter en un campo de origen/destino.
sealed class EndpointSubmit {
  const EndpointSubmit();
}

/// El primer hito popular que coincide con lo escrito.
final class SubmitPoi extends EndpointSubmit {
  const SubmitPoi(this.poi);
  final SantaCruzPoi poi;
}

/// Lo escrito pide «Mi ubicación» (solo origen).
final class SubmitGps extends EndpointSubmit {
  const SubmitGps();
}

/// La primera calle/lugar de OSM ya llegada para lo escrito.
final class SubmitSuggestion extends EndpointSubmit {
  const SubmitSuggestion(this.hit);
  final PlaceSuggestion hit;
}

/// Nada que elegir: el campo se queda como está.
final class SubmitNothing extends EndpointSubmit {
  const SubmitNothing();
}

/// Prioridad al pulsar Enter: hito popular → «Mi ubicación» → primera
/// sugerencia de OSM. Pura: la hoja le pasa lo que ya tiene a la vista.
EndpointSubmit resolveEndpointSubmit({
  required List<SantaCruzPoi> popular,
  required bool wantsGps,
  required PlaceSuggestion? firstOnline,
}) {
  if (popular.isNotEmpty) return SubmitPoi(popular.first);
  if (wantsGps) return const SubmitGps();
  if (firstOnline != null) return SubmitSuggestion(firstOnline);
  return const SubmitNothing();
}
