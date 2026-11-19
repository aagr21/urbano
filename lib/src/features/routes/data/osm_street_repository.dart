import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/runtime_flags.dart';
import '../../../core/utils/simple_cache.dart';

/// Calles y avenidas que atraviesa un recorrido, según OpenStreetMap.
///
/// La fuente es **Overpass** (no Nominatim): una sola consulta devuelve las
/// vías principales cuyo centro cae dentro del recuadro del trazado. Después se
/// filtran por cercanía a la polilínea y se ordenan en el sentido del recorrido
/// (de origen a destino), que es como se lee el detalle.
abstract class OsmStreetRepository {
  Future<List<String>> streetsAlong(List<LatLng> points);
}

class OverpassStreetRepository implements OsmStreetRepository {
  OverpassStreetRepository(this._dio)
    : _cache = SimpleCache(ttl: const Duration(minutes: 45));

  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  /// Tipos de vía que valen como «calle principal». Se dejan fuera las
  /// peatonales, de servicio y los caminos sin nombre.
  static const _highways = 'motorway|trunk|primary|secondary|tertiary';

  /// Distancia máxima del centro de la vía a la polilínea.
  static const _maxOffsetMeters = 170.0;

  final Dio _dio;
  final SimpleCache _cache;

  @override
  Future<List<String>> streetsAlong(List<LatLng> points) async {
    // Bajo `flutter test` no se toca la red: el detalle muestra solo lo que ya
    // trae el feed y ninguna prueba depende de Overpass.
    if (isRunningUnderTest || points.length < 2) return const [];

    final box = _Box.of(points);
    if (box == null) return const [];
    final key =
        'streets|${box.south.toStringAsFixed(4)},${box.west.toStringAsFixed(4)},'
        '${box.north.toStringAsFixed(4)},${box.east.toStringAsFixed(4)}';
    final cached = _cache.read<List<String>>(key);
    if (cached != null) return cached;

    try {
      final response = await _dio.get<dynamic>(
        _endpoint,
        queryParameters: {'data': box.query},
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 18),
        ),
      );
      final raw = response.data;
      final data = raw is String ? jsonDecode(raw) : raw;
      final streets = _parse(data, points);
      _cache.write(key, streets);
      return streets;
    } catch (_) {
      // Sin red/CDN lento: el detalle sigue con la sección GTFS de «Pasa por».
      return const [];
    }
  }

  List<String> _parse(dynamic data, List<LatLng> points) {
    if (data is! Map<String, dynamic>) return const [];
    final elements = data['elements'];
    if (elements is! List) return const [];

    final firstSeen = <String, int>{};
    final occurrences = <String, int>{};

    for (final element in elements) {
      if (element is! Map<String, dynamic>) continue;
      final tags = element['tags'];
      if (tags is! Map<String, dynamic>) continue;
      final name = (tags['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final center = element['center'];
      if (center is! Map<String, dynamic>) continue;
      final lat = (center['lat'] as num?)?.toDouble();
      final lon = (center['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final index = _nearestIndex(LatLng(lat, lon), points);
      if (index < 0) continue;
      firstSeen[name] ??= index;
      occurrences[name] = (occurrences[name] ?? 0) + 1;
    }

    if (firstSeen.isEmpty) return const [];
    final ranked = firstSeen.keys.toList()
      ..sort((a, b) {
        final byFrequency = occurrences[b]!.compareTo(occurrences[a]!);
        if (byFrequency != 0) return byFrequency;
        return firstSeen[a]!.compareTo(firstSeen[b]!);
      });
    final selected = ranked.take(10).toList()
      ..sort((a, b) => firstSeen[a]!.compareTo(firstSeen[b]!));
    return selected;
  }

  /// Índice del vértice más cercano a [point], o `-1` si la vía pasa lejos.
  int _nearestIndex(LatLng point, List<LatLng> points) {
    const distance = Distance();
    var bestIndex = -1;
    var best = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final meters = distance.as(LengthUnit.Meter, point, points[i]);
      if (meters < best) {
        best = meters;
        bestIndex = i;
      }
    }
    return best <= _maxOffsetMeters ? bestIndex : -1;
  }
}

/// Recuadro del trazado con un margen pequeño para capturar las vías que
/// corren pegadas al borde de la caja.
class _Box {
  const _Box({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  static const _margin = 0.002;

  static _Box? of(List<LatLng> points) {
    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    // Una caja desmedida (trazado corrupto) no se consulta: mejor vacío que
    // pedirle a Overpass media ciudad.
    if ((north - south) > 0.6 || (east - west) > 0.6) return null;
    return _Box(
      south: south - _margin,
      west: west - _margin,
      north: north + _margin,
      east: east + _margin,
    );
  }

  String get query =>
      '[out:json][timeout:20];'
      'way["highway"~"^(${OverpassStreetRepository._highways})\$"]["name"]'
      '(${south.toStringAsFixed(6)},${west.toStringAsFixed(6)},'
      '${north.toStringAsFixed(6)},${east.toStringAsFixed(6)});'
      'out center tags;';
}

/// Dio propio de Overpass: el cliente del backend no comparte host ni política
/// de reintentos con la API de Urbano.
final osmDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 18),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final osmStreetRepositoryProvider = Provider<OsmStreetRepository>(
  (ref) => OverpassStreetRepository(ref.watch(osmDioProvider)),
);
