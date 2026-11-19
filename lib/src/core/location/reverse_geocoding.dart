import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// `true` dentro de `flutter test` (el runner exporta `FLUTTER_TEST=true`).
bool get _runningUnderTest => Platform.environment.containsKey('FLUTTER_TEST');

/// Modelo de dirección inversa desde Nominatim (OSM).
class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    required this.displayName,
    required this.road,
    required this.suburb,
    required this.neighbourhood,
    required this.city,
    required this.state,
    required this.country,
    required this.postcode,
  });

  final String displayName;
  final String? road;
  final String? suburb;
  final String? neighbourhood;
  final String? city;
  final String? state;
  final String? country;
  final String? postcode;

  /// Formato legible: "Calle X, Zona Y, Ciudad"
  String get formatted {
    final parts = <String>[];
    if (road != null && road!.isNotEmpty) parts.add(road!);
    if (neighbourhood != null && neighbourhood!.isNotEmpty) {
      parts.add(neighbourhood!);
    }
    if (suburb != null && suburb!.isNotEmpty) parts.add(suburb!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (parts.isEmpty) return displayName;
    return parts.join(', ');
  }

  /// Versión corta: solo calle + zona/barrio
  String get shortFormatted {
    final parts = <String>[];
    if (road != null && road!.isNotEmpty) {
      parts.add(road!);
    }
    if (neighbourhood != null && neighbourhood!.isNotEmpty) {
      parts.add(neighbourhood!);
    } else if (suburb != null && suburb!.isNotEmpty) {
      parts.add(suburb!);
    }
    if (parts.isEmpty) {
      // Fallback: primera parte del display_name
      final commaIdx = displayName.indexOf(',');
      return commaIdx > 0 ? displayName.substring(0, commaIdx) : displayName;
    }
    return parts.join(', ');
  }

  factory ReverseGeocodeResult.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    return ReverseGeocodeResult(
      displayName: json['display_name'] as String? ?? '',
      road: address['road'] as String?,
      suburb: address['suburb'] as String?,
      neighbourhood: address['neighbourhood'] as String?,
      city: address['city'] as String?,
      state: address['state'] as String?,
      country: address['country'] as String?,
      postcode: address['postcode'] as String?,
    );
  }
}

/// Servicio de geocodificación inversa usando OSM Nominatim.
///
/// Límites de uso justo de Nominatim:
/// - Máx 1 request/segundo
/// - Incluir User-Agent identificativo
/// - Cachear resultados cuando sea posible
class ReverseGeocodingService {
  ReverseGeocodingService({String? userAgent, http.Client? httpClient})
    : _userAgent = userAgent ?? 'UrbanoApp/1.0 (contacto@urbano.app)',
      _httpClient = httpClient ?? http.Client();

  final String _userAgent;
  final http.Client _httpClient;

  static const _baseUrl = 'https://nominatim.openstreetmap.org/reverse';
  static const _rateLimitMs = 1100; // 1 req/seg + margen

  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, ReverseGeocodeResult> _cache = {};
  final Map<String, Completer<ReverseGeocodeResult>> _pending = {};

  /// Obtiene la dirección para una coordenada.
  ///
  /// Usa cache y deduplicación de requests concurrentes a la misma coordenada.
  Future<ReverseGeocodeResult?> reverseGeocode(
    LatLng point, {
    String language = 'es',
    bool useCache = true,
  }) async {
    // En tests no hacemos requests de red reales
    if (_runningUnderTest) return null;

    final key =
        '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';

    // Cache hit
    if (useCache && _cache.containsKey(key)) {
      return _cache[key];
    }

    // Deduplicar requests concurrentes a la misma coordenada
    if (_pending.containsKey(key)) {
      return _pending[key]!.future;
    }

    final completer = Completer<ReverseGeocodeResult>();
    _pending[key] = completer;

    try {
      // Rate limiting
      final sinceLast = DateTime.now().difference(_lastRequest).inMilliseconds;
      if (sinceLast < _rateLimitMs) {
        await Future.delayed(Duration(milliseconds: _rateLimitMs - sinceLast));
      }
      _lastRequest = DateTime.now();

      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'format': 'json',
          'lat': point.latitude.toString(),
          'lon': point.longitude.toString(),
          'accept-language': language,
          'addressdetails': '1',
          'zoom': '18', // nivel de detalle: calle
        },
      );

      final response = await _httpClient
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final result = ReverseGeocodeResult.fromJson(data);
        if (useCache) _cache[key] = result;
        completer.complete(result);
        return result;
      } else {
        completer.completeError(
          Exception('Nominatim error: ${response.statusCode}'),
        );
        return null;
      }
    } catch (e) {
      completer.completeError(e);
      return null;
    } finally {
      _pending.remove(key);
    }
  }

  /// Limpia el cache.
  void clearCache() => _cache.clear();

  void dispose() => _httpClient.close();
}

/// Provider global del servicio de geocodificación inversa.
///
/// Se usa `Provider` (no `StateNotifierProvider`) porque el servicio
/// es stateless salvo el cache interno.
final reverseGeocodingServiceProvider = Provider<ReverseGeocodingService>((
  ref,
) {
  final service = ReverseGeocodingService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provider que resuelve la dirección de un punto de forma asíncrona.
///
/// Devuelve `AsyncValue<ReverseGeocodeResult?>` para integrarse con
/// `AsyncValueView` y mostrar loading/error automáticamente.
final reverseGeocodeProvider =
    FutureProvider.family<ReverseGeocodeResult?, LatLng>((ref, point) async {
      final service = ref.watch(reverseGeocodingServiceProvider);
      return service.reverseGeocode(point);
    });
