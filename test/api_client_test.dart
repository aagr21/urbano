import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/network/api_client.dart';
import 'package:urbano/src/core/network/api_exception.dart';
import 'package:urbano/src/core/network/endpoints.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  test('desenvuelve {data, meta} en fetchPaged', () async {
    late RequestOptions seen;
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      dio: Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          seen = options;
          return _json('''
            {"data":[{"id":"101","shortName":"101","longName":"Micro 101",
                      "color":"7F8C8D","textColor":"FFFFFF","description":"",
                      "type":3,"directions":2,"stopCount":84,"tripCount":2}],
             "meta":{"page":1,"limit":20,"total":154}}
          ''');
        }),
    );

    final result = await client.fetchPaged(
      Endpoints.routes,
      query: compactQuery({'q': 'angostura', 'sort': null}),
      fromJson: (json) => json,
    );

    expect(result.items, hasLength(1));
    expect(result.items.first['id'], '101');
    expect(result.meta.total, 154);
    // El parámetro nulo se elimina de la query string.
    expect(seen.queryParameters.containsKey('sort'), isFalse);
    expect(seen.queryParameters['q'], 'angostura');
  });

  test('acepta lista directa sin envoltorio (estilo departures)', () async {
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      dio: Dio()
        ..httpClientAdapter = _FakeAdapter(
          (_) async => _json(
            '[{"tripId":"T97","directionId":0,'
            '"headsign":"Ida","time":"06:07:18","realTime":false,'
            '"headwaySeconds":300}]',
          ),
        ),
    );

    final items = await client.fetchList<Map<String, dynamic>>(
      '/routes/x/departures',
      fromJson: (json) => json,
    );
    expect(items, hasLength(1));
    expect(items.first['time'], '06:07:18');
  });

  test('convierte {error:{...}} en ApiException tipada', () async {
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      maxRetries: 0,
      dio: Dio()
        ..httpClientAdapter = _FakeAdapter(
          (_) async => _json(
            '{"error":{"statusCode":404,"message":"Route 999 not found","details":null}}',
            status: 404,
          ),
        ),
    );

    await expectLater(
      client.fetchObject(Endpoints.route('999')),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.notFound)
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Route 999 not found'),
      ),
    );
  });

  test('reintenta errores de red y luego tiene éxito', () async {
    var attempts = 0;
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      retryDelay: const Duration(milliseconds: 1),
      dio: Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          attempts++;
          if (attempts == 1) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: 'network down',
            );
          }
          return _json('{"status":"ok"}');
        }),
    );

    final result = await client.fetchObject('/stats');
    expect(result['status'], 'ok');
    expect(attempts, 2);
  });

  test('no reintenta errores 4xx', () async {
    var attempts = 0;
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      retryDelay: const Duration(milliseconds: 1),
      dio: Dio()
        ..httpClientAdapter = _FakeAdapter((options) async {
          attempts++;
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 400,
              data: {
                'error': {'statusCode': 400, 'message': 'Bad request'},
              },
            ),
          );
        }),
    );

    await expectLater(
      client.fetch('/stats'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.client),
      ),
    );
    expect(attempts, 1);
  });

  test('mensaje amigable de red en español', () {
    final error = ApiException('x', kind: ApiErrorKind.network);
    expect(error.friendlyMessage, contains('conexión'));
    expect(error.isRetryable, isTrue);
  });
}
