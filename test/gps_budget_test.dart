import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationAccuracy;
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/location/gps_budget.dart';

/// [meters] al norte de [from] (1° de latitud ≈ 111 320 m).
LatLng _northOf(LatLng from, double meters) =>
    LatLng(from.latitude + meters / 111320, from.longitude);

const _base = LatLng(-17.7833, -63.1821);

/// Drena el evento real: el controlador de [trackedFixes] cruza varias
/// microtareas por punto, y aquí (test puro, sin `FakeAsync`) no existe el
/// `pumpEventQueue` de los widget tests.
Future<void> _settle() async {
  for (var i = 0; i < 24; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<List<TrackedFix>> _drain(
  List<LatLng> fixes, {
  DateTime Function()? clock,
}) async {
  final source = StreamController<LatLng>();
  final gated = trackedFixes(source.stream, clock: clock ?? DateTime.now);
  final seen = <TrackedFix>[];
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
  group('trackedFixes', () {
    test('el punto propio avanza con cada fijación; la cámara solo con '
        'desplazamiento real', () async {
      final seen = await _drain([
        _base,
        _northOf(_base, 3),
        _northOf(_base, 12),
      ]);

      expect(
        seen.map((fix) => fix.point),
        [_base, _northOf(_base, 3), _northOf(_base, 12)],
        reason:
            'el punto de «mi ubicación» no puede esperar 5 m: si no, el '
            'usuario camina y el mapa parece congelado',
      );
      expect(seen.map((fix) => fix.moved), [
        true,
        false,
        true,
      ], reason: '3 m es jitter del GNSS; 12 m supera gpsMinMovementMeters');
    });

    test('caminata lenta: el punto sube en cada paso y la cámara una vez', () async {
      // 20 fijaciones de 1,4 m (caminata a paso normal, 1 fix/s): ~28 m de
      // avance REAL. El punto propio las sigue todas (es lo que se ve avanzar,
      // con el umbral de 1 m que descarta repeticiones); la cámara, no: cada
      // movimiento suyo re-anima la vista nativa.
      final seen = await _drain([
        _base,
        for (var step = 1; step <= 20; step++) _northOf(_base, 1.4 * step),
      ]);

      expect(
        seen.length,
        21,
        reason:
            'el punto propio avanza con la caminata (fijación a fijación), no '
            'se queda esperando los 5 m de la cámara',
      );
      expect(
        seen.where((fix) => fix.moved).length,
        6,
        reason:
            'la cámara se mueve al entrar y cada ~5 m recorridos, no veinte '
            'veces',
      );
      expect(seen.first.point, _base);
    });

    test('quietud: las repeticiones se descartan, el latido refresca', () async {
      var now = DateTime(2026, 10, 30, 8);
      final source = StreamController<LatLng>();
      addTearDown(source.close);
      final seen = <TrackedFix>[];
      final sub = trackedFixes(
        source.stream,
        clock: () => now,
      ).listen(seen.add);
      addTearDown(sub.cancel);

      source.add(_base);
      await _settle();
      expect(seen.map((fix) => fix.point), [_base]);

      // Ruido submétrico con el móvil quieto: es la MISMA posición.
      now = now.add(const Duration(seconds: 1));
      source.add(_northOf(_base, 0.4));
      await _settle();
      expect(seen, hasLength(1), reason: 'por debajo de gpsMinDrawMeters');

      // Un rato después del latido llegan 2 m de jitter: sin latido el punto
      // quedaría congelado para siempre.
      now = now.add(gpsQuietHeartbeat + const Duration(seconds: 1));
      source.add(_northOf(_base, 2));
      await _settle();
      expect(seen.map((fix) => fix.point), [_base, _northOf(_base, 2)]);
      expect(seen.last.moved, isTrue, reason: 'el latido re-ancla la cámara');

      // Y el latido vuelve a contar desde el punto recién despachado: 2 m de
      // avance real mueven el punto pero NO la cámara (aún no hay 5 m desde la
      // última vez que la cámara se movió).
      now = now.add(gpsQuietHeartbeat ~/ 2);
      source.add(_northOf(_base, 4));
      await _settle();
      expect(seen, hasLength(3), reason: 'el punto sí avanza 2 m');
      expect(
        seen.last.moved,
        isFalse,
        reason: 'la cámara espera a gpsMinMovementMeters',
      );
    });

    test('cancelar aguas abajo libera la suscripción del sensor', () async {
      final source = StreamController<LatLng>();
      addTearDown(source.close);
      final sub = trackedFixes(source.stream).listen((_) {});

      await _settle();
      expect(
        source.hasListener,
        isTrue,
        reason: 'el filtro se engancha al plugin',
      );
      await sub.cancel();
      expect(source.hasListener, isFalse);
    });
  });

  test('los umbrales del presupuesto son los acordados', () {
    // Cambiarlos es cambiar lo que la app le pide al radio y lo que el usuario
    // ve moverse: se prueban para que no se muevan "de paso".
    expect(gpsMinMovementMeters, 5);
    expect(gpsMinDrawMeters, 1);
    expect(gpsQuietHeartbeat, const Duration(seconds: 30));
    expect(gpsOneShotTimeLimit, const Duration(seconds: 15));
    expect(gpsReportInterval, const Duration(seconds: 1));
    expect(gpsOneShotSettings.accuracy, LocationAccuracy.medium);
  });

  test(
    'el seguimiento NO le pide filtro de distancia al proveedor: el punto se '
    'congelaba con el usuario avanzando',
    () {
      final settings = gpsTrackingSettings();
      expect(settings.distanceFilter, 0);
      expect(settings.accuracy, LocationAccuracy.high);
    },
  );
}
