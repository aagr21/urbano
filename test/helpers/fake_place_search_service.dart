import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/location/place_search.dart';

/// Buscador de calles en memoria: devuelve las sugerencias cuyo nombre
/// contiene lo escrito (sin red) y anota cada consulta.
class FakePlaceSearchService implements PlaceSearchService {
  FakePlaceSearchService(this.places);

  final List<PlaceSuggestion> places;
  final List<String> queries = [];

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    LatLng near = santaCruzCenter,
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    final q = query.toLowerCase();
    return [
      for (final place in places)
        if (place.name.toLowerCase().contains(q)) place,
    ];
  }
}

/// Calles y lugares reales de Santa Cruz para los tests.
const santaCruzSuggestions = [
  PlaceSuggestion(
    name: 'Avenida Monseñor Rivero',
    lat: -17.7742,
    lon: -63.1823,
    kind: PlaceKind.street,
    detail: 'Centro',
  ),
  PlaceSuggestion(
    name: 'Ventura Mall',
    lat: -17.7569,
    lon: -63.1984,
    kind: PlaceKind.poi,
    detail: 'Avenida Antonio Vaca Diez',
  ),
  PlaceSuggestion(
    name: 'Plaza 24 de Septiembre',
    lat: -17.7833,
    lon: -63.1821,
    kind: PlaceKind.poi,
    detail: 'Centro',
  ),
];
