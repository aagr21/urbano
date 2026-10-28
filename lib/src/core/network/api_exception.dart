import 'dart:convert';

import 'package:dio/dio.dart';

/// Categoría de error para dar mensajes de usuario útiles.
enum ApiErrorKind {
  network,
  timeout,
  server,
  notFound,
  unauthorized,
  client,
  canceled,
  parsing,
  unknown,
}

/// Error único que atraviesa toda la app (envelopes del contrato + fallos Dio).
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiErrorKind.unknown,
    this.details,
  });

  /// Lee `{"error": {...}}` del contrato o el status de la respuesta.
  factory ApiException.fromEnvelope(
    Map<String, dynamic> body, {
    int? fallbackStatus,
  }) {
    final raw = body['error'];
    final error = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final status = (error['statusCode'] as num?)?.toInt() ?? fallbackStatus;
    return ApiException(
      error['message'] as String? ?? 'Error del servidor',
      statusCode: status,
      kind: kindForStatus(status),
      details: error['details'],
    );
  }

  factory ApiException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    final data = _decodeBody(error.response?.data);

    if (data is Map<String, dynamic> && data['error'] is Map) {
      return ApiException.fromEnvelope(data, fallbackStatus: status);
    }

    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => ApiErrorKind.timeout,
      DioExceptionType.cancel => ApiErrorKind.canceled,
      DioExceptionType.badResponse => kindForStatus(status),
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown => ApiErrorKind.network,
    };

    return ApiException(
      messageFor(kind, status),
      statusCode: status,
      kind: kind,
    );
  }

  final String message;
  final int? statusCode;
  final ApiErrorKind kind;
  final dynamic details;

  static ApiErrorKind kindForStatus(int? status) {
    return switch (status) {
      null => ApiErrorKind.unknown,
      404 => ApiErrorKind.notFound,
      401 || 403 => ApiErrorKind.unauthorized,
      >= 500 => ApiErrorKind.server,
      >= 400 => ApiErrorKind.client,
      _ => ApiErrorKind.unknown,
    };
  }

  static String messageFor(ApiErrorKind kind, int? status) {
    return switch (kind) {
      ApiErrorKind.timeout => 'El servidor tardó demasiado en responder.',
      ApiErrorKind.notFound => 'No encontramos lo que buscabas.',
      ApiErrorKind.server =>
        'Tenemos un problema momentáneo, intenta de nuevo.',
      ApiErrorKind.unauthorized => 'No autorizado ($status).',
      _ => 'No pudimos completar la petición ($status).',
    };
  }

  static dynamic _decodeBody(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  /// Mensaje amigable en español para mostrar en la UI.
  String get friendlyMessage => switch (kind) {
    ApiErrorKind.network => 'No pudimos conectar con Urbano. Revisa tu conexión e inténtalo de nuevo.',
    ApiErrorKind.timeout =>
      'La conexión está muy lenta. Intenta de nuevo en unos segundos.',
    ApiErrorKind.notFound => 'No encontramos lo que buscabas.',
    ApiErrorKind.server =>
      'El servicio tiene un problema momentáneo. Intenta de nuevo.',
    _ => message,
  };

  /// Errores donde reintentar tiene sentido.
  bool get isRetryable =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.server;

  @override
  String toString() => 'ApiException(${kind.name}, $statusCode): $message';
}
