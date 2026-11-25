import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/runtime_flags.dart';

/// Sugerencias de calles y lugares de **Santa Cruz de la Sierra** mientras se
/// escribe, con datos de OpenStreetMap.
///
/// Proveedor: **Photon** (komoot), gratuito y hecho para «buscar mientras
/// escribes». No se usa Nominatim para esto: su política de uso prohíbe el
/// autocompletado contra el servidor público (sí se usa para la dirección
/// inversa, ver `reverse_geocoding.dart`). Los resultados se acotan a la caja
/// de la ciudad y se ordenan por cercanía al punto que se pase.
///
/// Atribución obligatoria de los datos: «© OpenStreetMap» (la muestra la UI
/// junto a las sugerencias, ver [osmAttribution]).

/// Texto de atribución de los datos de OSM, para mostrar con las sugerencias.
const String osmAttribution = 'Sugerencias de © OpenStreetMap';

/// Centro de Santa Cruz (plaza 24 de Septiembre): sesgo por defecto.
const LatLng santaCruzCenter = LatLng(-17.7833, -63.1821);

/// Caja de la mancha urbana (minLon, minLat, maxLon, maxLat).
const String _santaCruzBbox = '-63.32,-17.95,-63.03,-17.62';

/// Qué es una sugerencia: decide el ícono y cómo se describe.
enum PlaceKind { street, area, stop, poi }

/// Una sugerencia ya limpia, lista para pintar y para usarse como punto.
@immutable
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.name,
    required this.lat,
    required this.lon,
    required this.kind,
    this.detail,
  });

  final String name;

  /// Segunda línea: barrio/zona, o la calle de un lugar.
  final String? detail;
  final double lat;
  final double lon;
  final PlaceKind kind;

  IconData get icon => switch (kind) {
    PlaceKind.street => Icons.add_road_rounded,
    PlaceKind.area => Icons.holiday_village_rounded,
    PlaceKind.stop => Icons.directions_bus_rounded,
    PlaceKind.poi => Icons.place_rounded,
  };

  /// Detalle con su tipo cuando no hay barrio («Calle», «Barrio»…).
  String get subtitle =>
      detail ??
      switch (kind) {
        PlaceKind.street => 'Calle',
        PlaceKind.area => 'Barrio o zona',
        PlaceKind.stop => 'Parada',
        PlaceKind.poi => 'Lugar',
      };
}

/// Interpreta la respuesta GeoJSON de Photon: descarta el ruido (pastos,
/// límites administrativos, ríos), acota a Santa Cruz y quita duplicados
/// (una sugerencia por nombre: tramos de una calle, la parada y el lugar).
List<PlaceSuggestion> parsePhotonResults(Object? json, {int limit = 6}) {
  if (json is! Map) return const [];
  final features = json['features'];
  if (features is! List) return const [];

  const noise = {'landuse', 'natural', 'boundary', 'waterway', 'power'};
  final out = <PlaceSuggestion>[];
  final seen = <String>{};

  for (final feature in features) {
    if (feature is! Map) continue;
    final props = feature['properties'];
    final geometry = feature['geometry'];
    if (props is! Map || geometry is! Map) continue;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) continue;
    final lon = (coords[0] as num?)?.toDouble();
    final lat = (coords[1] as num?)?.toDouble();
    if (lat == null || lon == null) continue;

    final name = (props['name'] as String?)?.trim() ?? '';
    final key = props['osm_key'] as String? ?? '';
    final value = props['osm_value'] as String? ?? '';
    final city = props['city'] as String? ?? props['county'] as String? ?? '';
    if (name.isEmpty || noise.contains(key)) continue;
    if (city.isNotEmpty && !city.toLowerCase().contains('santa cruz')) {
      continue;
    }

    final kind = switch ((key, value)) {
      ('highway', 'bus_stop') => PlaceKind.stop,
      ('highway', _) => PlaceKind.street,
      ('place', _) => PlaceKind.area,
      _ => PlaceKind.poi,
    };
    final district =
        (props['district'] ?? props['locality'] ?? props['suburb']) as String?;
    final street = props['street'] as String?;
    final detail = switch (kind) {
      PlaceKind.poi || PlaceKind.stop => [
        if (street != null && street != name) street,
        ?district,
      ].join(' · '),
      _ => district ?? '',
    };

    // La misma calle llega en varios tramos (y cruza barrios), el mall llega
    // también como parada y el barrio como lugar: una sugerencia por nombre,
    // la primera (Photon ya las trae por relevancia y cercanía).
    if (!seen.add(name.toLowerCase())) continue;

    out.add(
      PlaceSuggestion(
        name: name,
        lat: lat,
        lon: lon,
        kind: kind,
        detail: detail.isEmpty ? null : detail,
      ),
    );
    if (out.length >= limit) break;
  }
  return out;
}

/// Puerto del buscador: inyectable para que los tests nunca toquen la red.
abstract interface class PlaceSearchService {
  Future<List<PlaceSuggestion>> search(
    String query, {
    LatLng near = santaCruzCenter,
    CancelToken? cancelToken,
  });
}

/// Implementación con Photon (photon.komoot.io).
class PhotonPlaceSearchService implements PlaceSearchService {
  PhotonPlaceSearchService([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://photon.komoot.io',
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              // Identificación del cliente, sin datos de la persona.
              headers: const {'User-Agent': 'Urbano-SantaCruz/1.0'},
            ),
          );

  final Dio _dio;

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    LatLng near = santaCruzCenter,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Object?>(
      '/api/',
      queryParameters: {
        'q': query,
        // Se piden de más: el filtro de ruido y duplicados descarta varios.
        'limit': 12,
        'lat': near.latitude,
        'lon': near.longitude,
        'bbox': _santaCruzBbox,
      },
      cancelToken: cancelToken,
    );
    return parsePhotonResults(response.data);
  }
}

/// Sin red: lo que se usa bajo `flutter test` salvo que el test lo reemplace.
class _OfflinePlaceSearchService implements PlaceSearchService {
  const _OfflinePlaceSearchService();

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    LatLng near = santaCruzCenter,
    CancelToken? cancelToken,
  }) async => const [];
}

final placeSearchServiceProvider = Provider<PlaceSearchService>(
  (ref) => isRunningUnderTest
      ? const _OfflinePlaceSearchService()
      : PhotonPlaceSearchService(),
);

/// Mínimo de letras antes de consultar (con menos, todo coincide).
const int placeSearchMinChars = 3;

/// Pausa tras la última tecla antes de consultar: una consulta por idea, no
/// por letra. Bajo tests no hay pausa (un `Timer` pendiente rompe `pump()`).
Duration get placeSearchDebounce =>
    isRunningUnderTest ? Duration.zero : const Duration(milliseconds: 350);

/// Sugerencias para un texto. `autoDispose`: al seguir escribiendo, la
/// consulta anterior se cancela (su `CancelToken`) antes de salir a la red.
final placeSearchProvider = FutureProvider.autoDispose
    .family<List<PlaceSuggestion>, String>((ref, query) async {
      final q = query.trim();
      if (q.length < placeSearchMinChars) return const [];

      var disposed = false;
      final cancel = CancelToken();
      ref.onDispose(() {
        disposed = true;
        cancel.cancel();
      });

      final pause = placeSearchDebounce;
      if (pause > Duration.zero) await Future<void>.delayed(pause);
      if (disposed) return const [];

      final results = await ref
          .watch(placeSearchServiceProvider)
          .search(q, cancelToken: cancel);
      // Volver sobre lo mismo (borrar y reescribir) no repite la consulta.
      // Bajo tests no: el `Timer` de 2 minutos quedaría pendiente.
      if (!isRunningUnderTest) {
        final link = ref.keepAlive();
        final timer = Timer(const Duration(minutes: 2), link.close);
        ref.onDispose(timer.cancel);
      }
      return results;
    });
