import 'package:dio/dio.dart';

import 'api_exception.dart';

/// `meta` del envoltorio `{data, meta}`.
class Meta {
  const Meta({this.page, this.limit, this.total});

  factory Meta.fromJson(Map<String, dynamic>? json) => Meta(
    page: (json?['page'] as num?)?.toInt(),
    limit: (json?['limit'] as num?)?.toInt(),
    total: (json?['total'] as num?)?.toInt(),
  );

  final int? page;
  final int? limit;
  final int? total;

  int get safeTotal => total ?? 0;
}

/// Lista paginada: items + meta.
class Paged<T> {
  const Paged({required this.items, required this.meta});

  final List<T> items;
  final Meta meta;
}

/// Quita claves nulas/vacías de un mapa de query params.
Map<String, dynamic> compactQuery(Map<String, dynamic> params) => {
  for (final entry in params.entries)
    if (entry.value != null && entry.value != '')
      entry.key: entry.value as Object,
};

/// Cliente HTTP liviano sobre Dio.
///
/// - Maneja el envoltorio `{data, meta}` y los errores `{error: {...}}`.
/// - Reintenta errores transitorios (red/timeout/5xx) con backoff.
/// - Todos los métodos lanzan [ApiException].
class ApiClient {
  ApiClient({
    required this.baseUrl,
    Dio? dio,
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 250),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 12),
               receiveTimeout: const Duration(seconds: 20),
               headers: const {'Accept': 'application/json'},
             ),
           );

  final String baseUrl;
  final Dio _dio;
  final int maxRetries;
  final Duration retryDelay;

  /// Payload suelto (objeto, lista o lo que venga), ya desenvuelto.
  Future<dynamic> fetch(String path, {Map<String, dynamic>? query}) async {
    final (payload, _) = await _request(path, query: query);
    return payload;
  }

  /// Objeto plano (ej: `/stats`), desenvuelto del envoltorio si existe.
  Future<Map<String, dynamic>> fetchObject(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final (payload, _) = await _request(path, query: query);
    if (payload is Map<String, dynamic>) return payload;
    throw ApiException(
      'Respuesta inesperada del servidor',
      kind: ApiErrorKind.parsing,
    );
  }

  /// Lista (ej: `/routes`, `/stops/nearby`), desenvuelta.
  Future<List<T>> fetchList<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    final (payload, _) = await _request(path, query: query);
    final list = payload is List ? payload : const <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  /// Lista + `meta` del envoltorio.
  Future<Paged<T>> fetchPaged<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    final (payload, meta) = await _request(path, query: query);
    final list = payload is List ? payload : const <dynamic>[];
    return Paged<T>(
      items: list
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(growable: false),
      meta: Meta.fromJson(meta),
    );
  }

  void close() => _dio.close(force: true);

  // ---------------------------------------------------------------------------

  Future<(dynamic, Map<String, dynamic>?)> _request(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    Object? last;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _dio.get<dynamic>(path, queryParameters: query);
        return _decode(response.data);
      } on DioException catch (error) {
        final api = ApiException.fromDio(error);
        last = api;
        if (!api.isRetryable || attempt == maxRetries) {
          throw api;
        }
        await Future<void>.delayed(retryDelay * (attempt + 1));
      }
    }
    throw last ?? ApiException('Error desconocido');
  }

  /// Aplica el contrato: `{data, meta}` / `{error}` / lista directa.
  (dynamic, Map<String, dynamic>?) _decode(dynamic body) {
    if (body is List) return (body, null);
    if (body is! Map<String, dynamic>) return (body, null);

    if (body['error'] is Map) {
      throw ApiException.fromEnvelope(body);
    }

    final rawMeta = body['meta'];
    final meta = rawMeta is Map<String, dynamic> ? rawMeta : null;

    if (body.containsKey('data')) {
      return (body['data'], meta);
    }
    return (body, meta);
  }
}
