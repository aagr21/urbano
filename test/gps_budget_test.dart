import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationAccuracy;
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/location/gps_budget.dart';

/// [meters] al norte de [from] (1° de latitud ≈ 111 320 m).
LatLng _northOf(LatLng from, double meters) =>
    LatLng(from.latitude + meters / 111320, from.longitude);

const _base = LatLng(-17.7833, -63.1821);

/// Drena el evento real: el generador `async*` de [onlyRealMovement] cruza
/// varias microtareas por punto, y aquí (test puro, sin `FakeAsync`) no existe
/// el `pumpEventQueue` de los widget tests.
Future<void> _settle() async {
  for (var i = 0; i < 24; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<List<LatLng>> _drain(
  List<LatLng> fixes, {
  DateTime Function()? clock,
}) async {
  final source = StreamController<LatLng>();
  final gated = onlyRealMovement(source.stream, clock: clock ?? DateTime.now);
  final seen = <LatLng>[];
  final sub = gated.listen(seen.add);
  for (final fix in fixes) {
    source.add(fix);
  }
  await _settle();
  await sub.cancel();
  await source.close();
  return seen;
}

void main() {
  group('onlyRealMovement', () {
    test(
      'deja pasar el primer punto y el desplazamiento real; el ruido no',
      () async {
        final seen = await _drain([
          _base,
          _northOf(_base, 3),
          _northOf(_base, 12),
        ]);

        expect(seen, [
          _base,
          _northOf(_base, 12),
        ], reason: '3 m es jitter del GNSS; 12 m supera gpsMinMovementMeters');
      },
    );

    test('movimiento lento: un solo punto aguas abajo, no uno por fijación', () async {
      // 20 fijaciones de 0,5 m: hay ~10 m de avance REAL, pero la cámara no debe
      // moverse 20 veces (cada punto = reconstruir la capa y animar la cámara).
      final seen = await _drain([
        _base,
        for (var step = 1; step <= 20; step++) _northOf(_base, 0.5 * step),
      ]);

      expect(
        seen.length,
        2,
        reason:
            'el umbral se mide desde el último punto DESPACHADO: cruza una vez, '
            'no veinte',
      );
      expect(seen.first, _base);
    });

    test(
      'quietud prolongada: el latido lento igualmente refresca el punto',
      () async {
        var now = DateTime(2026, 10, 30, 8);
        final source = StreamController<LatLng>();
        addTearDown(source.close);
        final seen = <LatLng>[];
        final sub = onlyRealMovement(
          source.stream,
          clock: () => now,
        ).listen(seen.add);
        addTearDown(sub.cancel);

        source.add(_base);
        await _settle();
        expect(seen, [_base]);

        // Un rato después del latido llegan 2 m de jitter: sin latido el punto
        // quedaría congelado para siempre.
        now = now.add(gpsQuietHeartbeat + const Duration(seconds: 1));
        source.add(_northOf(_base, 2));
        await _settle();
        expect(seen, [
          _base,
          _northOf(_base, 2),
        ], reason: 'pasado el latido se deja pasar aunque no haya movimiento');

        // Y el latido vuelve a contar desde el punto recién despachado.
        now = now.add(gpsQuietHeartbeat ~/ 2);
        source.add(_northOf(_base, 4));
        await _settle();
        expect(seen, hasLength(2), reason: 'aún no toca otro latido');
      },
    );

    test('cancelar aguas abajo libera la suscripción del sensor', () async {
      final source = StreamController<LatLng>();
      addTearDown(source.close);
      final sub = onlyRealMovement(source.stream).listen((_) {});

      await _settle();
      expect(
        source.hasListener,
        isTrue,
        reason: 'el filtro se engancha al plugin',
      );
      await sub.cancel();
      // El `await for` termina con la cancelación: el plugin se queda sin
      // oyentes, que es como se suelta el listener del GPS sin temporizador.
      expect(source.hasListener, isFalse);
    });
  });

  test('los umbrales del presupuesto son los acordados', () {
    // Cambiarlos es cambiar lo que la app le pide al radio: se prueban para que
    // no se muevan "de paso".
    expect(gpsMinMovementMeters, 5);
    expect(gpsQuietHeartbeat, const Duration(seconds: 30));
    expect(gpsOneShotTimeLimit, const Duration(seconds: 15));
    expect(gpsReportInterval, const Duration(seconds: 1));
    expect(gpsOneShotSettings.accuracy, LocationAccuracy.medium);
  });
}
