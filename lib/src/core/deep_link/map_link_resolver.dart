import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/runtime_flags.dart';
import 'shared_location.dart';

/// Sigue un enlace corto de Google Maps (`maps.app.goo.gl/…`) hasta la URL
/// larga, que es la que trae las coordenadas.
abstract interface class MapLinkResolver {
  /// La URL final, o `null` si no se pudo seguir (sin red, host raro…).
  Future<String?> resolve(Uri shortLink);
}

/// Resolución con redirecciones manuales: solo se leen las cabeceras
/// `Location` (nunca el cuerpo) y solo mientras el salto siga en un host de
/// Google, así un enlace cualquiera no hace que la app navegue por la web.
class DioMapLinkResolver implements MapLinkResolver {
  DioMapLinkResolver(this._dio);

  final Dio _dio;

  static const _maxHops = 5;

  @override
  Future<String?> resolve(Uri shortLink) async {
    var current = shortLink;
    for (var hop = 0; hop < _maxHops; hop++) {
      if (!_isGoogleHost(current.host)) return null;
      // En cuanto la URL ya se puede leer, no hace falta seguir.
      if (hop > 0 && parseSharedLocation(current.toString()) != null) {
        return current.toString();
      }
      final Response<void> response;
      try {
        // HEAD: el destino de la redirección va en la cabecera, el cuerpo
        // (una página entera de Google Maps al final) no sirve para nada.
        response = await _dio.headUri<void>(
          current,
          options: Options(
            followRedirects: false,
            validateStatus: (status) => status != null && status < 400,
          ),
        );
      } on DioException {
        return null;
      }
      final location = response.headers.value('location');
      if (location == null) return hop == 0 ? null : current.toString();
      current = current.resolve(location);
    }
    return current.toString();
  }

  static bool _isGoogleHost(String host) {
    final h = host.toLowerCase();
    return h == 'goo.gl' ||
        h.endsWith('.goo.gl') ||
        h == 'google.com' ||
        h.endsWith('.google.com') ||
        RegExp(r'(^|\.)google\.[a-z.]+$').hasMatch(h);
  }
}

/// Sin red: lo que corre bajo `flutter test`.
class OfflineMapLinkResolver implements MapLinkResolver {
  const OfflineMapLinkResolver();

  @override
  Future<String?> resolve(Uri shortLink) async => null;
}

final mapLinkResolverProvider = Provider<MapLinkResolver>((ref) {
  if (isRunningUnderTest) return const OfflineMapLinkResolver();
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );
  ref.onDispose(dio.close);
  return DioMapLinkResolver(dio);
});

/// Lee la ubicación de un enlace entrante; si es un enlace corto de Google
/// Maps, primero lo resuelve por la red.
Future<SharedLocation?> readSharedLocation(
  String raw,
  MapLinkResolver resolver,
) async {
  final direct = parseSharedLocation(raw);
  if (direct != null) return direct;
  final short = findShortMapLink(raw);
  if (short == null) return null;
  final resolved = await resolver.resolve(short);
  return parseSharedLocation(resolved);
}
