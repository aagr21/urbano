import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/map/endpoint_drag_detector.dart';
import 'package:urbano/src/core/map/map_projection.dart';
import 'package:urbano/src/core/map/map_types.dart';

/// Tests de la capa de arrastre/tap de pines en Dart.
///
/// Son los que garantizan que las coordenadas del campo cambian DURANTE el
/// arrastre sin depender del gesto nativo de `maplibre_gl` (que en algunos
/// dispositivos no llega a disparar `feature#onDrag`).
///
/// El `child` incluye un `GestureDetector` que representa a la vista del mapa:
/// si el detector gana la arena (toque sobre el pin), ese competidor NO debe
/// recibir nada; si el toque queda lejos, él sí debe recibirlo.
void main() {
  const center = LatLng(-17.783, -63.182);
  const zoom = 15.0;
  const viewport = Size(800, 600);

  /// `project(center)` con esta cámara y ratio: la punta del pin.
  const pinTip = Offset(400, 300);

  late List<({String id, LatLng point})> starts;
  late List<({String id, LatLng point})> updates;
  late List<({String id, LatLng point})> ends;
  late List<String> taps;
  late List<String> mapa;

  /// Cámara "viva" entregada al detector: los tests la mutan sin rebuild para
  /// simular desplazamientos del usuario (como el motor real lo hace).
  late MapCamera cameraNow;

  LatLng unproject(Offset pixel) => MapProjection.unproject(
    pixel,
    center: center,
    zoom: zoom,
    viewport: viewport,
  );

  void expectPoint(Offset pixel, LatLng actual) {
    final expected = unproject(pixel);
    expect(actual.latitude, closeTo(expected.latitude, 1e-9));
    expect(actual.longitude, closeTo(expected.longitude, 1e-9));
  }

  Widget buildDetector() {
    return MaterialApp(
      home: EndpointDragDetector(
        camera: () => cameraNow,
        viewport: viewport,
        targets: [
          // Sin campos de cabeza → radio isotrópico de respaldo.
          (
            id: 'origin',
            point: center,
            hitRadiusPx: 52.0,
            headRadiusPx: null,
            headCenterDy: null,
            bodyWidthPx: null,
          ),
        ],
        onDragStart: (id, point) => starts.add((id: id, point: point)),
        onDragUpdate: (id, point) => updates.add((id: id, point: point)),
        onDragEnd: (id, point) => ends.add((id: id, point: point)),
        onTap: taps.add,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => mapa.add('down'),
          onTap: () => mapa.add('tap'),
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
  }

  /// Pin teardrop 40×56 (como lo construye el motor real): cabeza circular de
  /// radio 32 centrada 36 px sobre la punta y cuello del ancho del pin.
  Widget buildShapedDetector() {
    return MaterialApp(
      home: EndpointDragDetector(
        camera: () => cameraNow,
        viewport: viewport,
        targets: [
          (
            id: 'origin',
            point: center,
            hitRadiusPx: 36.0,
            headRadiusPx: 32.0,
            headCenterDy: 36.0,
            bodyWidthPx: 40.0,
          ),
        ],
        onDragStart: (id, point) => starts.add((id: id, point: point)),
        onDragUpdate: (id, point) => updates.add((id: id, point: point)),
        onDragEnd: (id, point) => ends.add((id: id, point: point)),
        onTap: taps.add,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => mapa.add('down'),
          onTap: () => mapa.add('tap'),
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
  }

  setUp(() {
    starts = [];
    updates = [];
    ends = [];
    taps = [];
    mapa = [];
    cameraNow = const MapCamera(center: center, zoom: zoom);
  });

  testWidgets('al arrastrar el pin emite start/update/end con coordenadas '
      'proyectadas y el mapa no recibe el toque', (tester) async {
    await tester.pumpWidget(buildDetector());

    final gesture = await tester.startGesture(pinTip);
    await tester.pump();
    // Todavía sin superar la slop: nada emitido y la arena ya ganada.
    expect(starts, isEmpty);
    expect(mapa, isEmpty);

    await gesture.moveBy(const Offset(30, 0)); // > kTouchSlop (18 px)
    await tester.pump();
    expect(starts, hasLength(1));
    expect(starts.single.id, 'origin');
    expectPoint(pinTip, starts.single.point); // punto original del pin

    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    expect(updates, hasLength(1));
    expectPoint(const Offset(450, 310), updates.single.point);

    await gesture.moveBy(const Offset(-5, 25));
    await tester.pump();
    expect(updates, hasLength(2));
    expectPoint(const Offset(445, 335), updates.last.point);
    expect(mapa, isEmpty); // la vista del mapa jamás vio el arrastre

    await gesture.up();
    await tester.pump();
    expect(ends, hasLength(1));
    expect(ends.single.id, 'origin');
    expectPoint(const Offset(445, 335), ends.single.point);
    expect(taps, isEmpty);
    expect(mapa, isEmpty);
  });

  testWidgets('un toque sobre el pin sin moverlo se reporta como tap del pin '
      'y no llega al mapa', (tester) async {
    await tester.pumpWidget(buildDetector());

    final gesture = await tester.startGesture(pinTip);
    await tester.pump();
    await gesture.moveBy(const Offset(5, 5)); // ≤ kTouchSlop
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(taps, ['origin']);
    expect(starts, isEmpty);
    expect(updates, isEmpty);
    expect(ends, isEmpty);
    expect(mapa, isEmpty);
  });

  testWidgets('un toque lejos del pin no lo reclama: el mapa recibe el gesto', (
    tester,
  ) async {
    await tester.pumpWidget(buildDetector());

    final gesture = await tester.startGesture(const Offset(120, 120));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(mapa, ['down', 'tap']);
    expect(taps, isEmpty);
    expect(starts, isEmpty);
    expect(updates, isEmpty);
    expect(ends, isEmpty);
  });

  testWidgets('el arrastre conserva el agarre: el pin no salta bajo el dedo', (
    tester,
  ) async {
    await tester.pumpWidget(buildDetector());

    // Dedo 20 px sobre la punta (cuerpo del pin).
    final gesture = await tester.startGesture(pinTip - const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(starts, hasLength(1));
    expectPoint(pinTip, starts.single.point); // origen, no la posición del dedo

    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    expect(updates, hasLength(1));
    // La punta queda 20 px bajo el dedo: mismo offset que al agarrar.
    expectPoint(const Offset(450, 310), updates.single.point);

    await gesture.up();
    await tester.pump();
    expect(ends, hasLength(1));
    expectPoint(const Offset(450, 310), ends.single.point);
    expect(taps, isEmpty);
  });

  testWidgets(
    'un segundo dedo es un PELLIZCO: cancela el arrastre y el pin vuelve a '
    'su punto de arranque (el zoom no cambia coordenadas ni replanifica)',
    (tester) async {
      await tester.pumpWidget(buildDetector());

      final first = await tester.startGesture(pinTip);
      await first.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(starts, hasLength(1));
      expect(updates, isEmpty); // la slop se supera con ese mismo move

      final second = await tester.startGesture(const Offset(700, 500));
      await tester.pump();
      expect(ends, hasLength(1)); // cerrado como arrastre, pero en el ARRANQUE
      expectPoint(pinTip, ends.single.point);
      expect(taps, isEmpty);

      await first.up();
      await second.up();
      await tester.pump();
      expect(ends, hasLength(1)); // el up del primer dedo no duplica nada
      expect(starts, hasLength(1));
      expect(taps, isEmpty);
    },
  );

  testWidgets(
    'un segundo dedo ANTES de superar la slop no emite nada (no es tap ni '
    'arrastre): el pellizco no marca el pin',
    (tester) async {
      await tester.pumpWidget(buildDetector());

      final first = await tester.startGesture(pinTip);
      await tester.pump(); // down sobre el pin, aún sin slop

      final second = await tester.startGesture(const Offset(700, 500));
      await first.moveBy(const Offset(20, 4)); // > kTouchSlop con el pinch vivo
      await tester.pump();

      expect(starts, isEmpty);
      expect(updates, isEmpty);
      expect(ends, isEmpty);
      expect(taps, isEmpty);

      await first.up();
      await second.up();
      await tester.pump();
      expect(starts, isEmpty);
      expect(taps, isEmpty);
      expect(ends, isEmpty);
    },
  );

  testWidgets('con la forma de pin, un toque al LADO del pin no lo agarra: '
      'es pan del mapa (antes el radio isotrópico lo reclamaba)', (
    tester,
  ) async {
    await tester.pumpWidget(buildShapedDetector());

    // 40 px a la derecha de la punta: fuera de la cabeza (dist 53.8 > 40) y
    // del cuello (semiancho 20 + pad 8 = 28).
    final gesture = await tester.startGesture(pinTip + const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(mapa, ['down', 'tap']);
    expect(starts, isEmpty);
    expect(ends, isEmpty);
    expect(taps, isEmpty);
  });

  testWidgets('con la forma de pin, agarrar por la CABEZA funciona con agarre '
      'compensado (el pin no salta bajo el dedo)', (tester) async {
    await tester.pumpWidget(buildShapedDetector());

    // Centro de la cabeza: 36 px sobre la punta.
    final gesture = await tester.startGesture(pinTip - const Offset(0, 36));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0)); // > kTouchSlop
    await tester.pump();
    expect(starts, hasLength(1));
    expectPoint(pinTip, starts.single.point);

    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(updates, hasLength(1));
    // La punta sigue 36 px bajo el dedo: mismo offset que al agarrar.
    expectPoint(const Offset(450, 300), updates.single.point);

    await gesture.up();
    await tester.pump();
    expect(ends, hasLength(1));
    expectPoint(const Offset(450, 300), ends.single.point);
    expect(mapa, isEmpty);
  });

  testWidgets(
    'ZOOM EN ORDEN REAL: el primer dedo cae en el MAPA y el SEGUNDO sobre '
    'el pin — no se reclama ni emite nada (regresión del recálculo)',
    (tester) async {
      await tester.pumpWidget(buildDetector());

      // Punta del pellizco lejos del pin…
      final map = await tester.startGesture(const Offset(120, 120));
      await tester.pump();
      // …y la otra punta cayendo ENCIMA del pin. Debe quedar en el zoom, no
      // arrancar un arrastre del pin.
      final pin = await tester.startGesture(pinTip);
      await tester.pump();

      // Las dos puntas se separan (zoom) superando la slop.
      await map.moveBy(const Offset(-80, 0));
      await pin.moveBy(const Offset(80, 0));
      await tester.pump();

      await map.up();
      await pin.up();
      await tester.pump();

      expect(starts, isEmpty);
      expect(updates, isEmpty);
      expect(ends, isEmpty);
      expect(taps, isEmpty);
    },
  );

  testWidgets(
    'tras abortar por pellizco, un dedo NUEVO sobre el pin no lo reclama '
    '(el pellizco sigue vivo hasta que todos los dedos se levantan)',
    (tester) async {
      await tester.pumpWidget(buildDetector());

      final first = await tester.startGesture(pinTip);
      await first.moveBy(const Offset(30, 0)); // arrastre arrancado
      await tester.pump();
      expect(starts, hasLength(1));

      // Segundo dedo: cancela el arrastre al punto de arranque.
      final second = await tester.startGesture(const Offset(700, 500));
      await tester.pump();
      expect(ends, hasLength(1));
      expectPoint(pinTip, ends.single.point);

      // Tercer dedo (o el reemplazo del que se iba a levantar) sobre el pin:
      // mientras queden otros dedos, NO se reclama de nuevo.
      final third = await tester.startGesture(pinTip + const Offset(5, 5));
      await tester.pump();
      await third.moveBy(const Offset(40, 0)); // > kTouchSlop
      await tester.pump();

      expect(starts, hasLength(1)); // solo el arrastre original
      expect(ends, hasLength(1)); // solo la cancelación del pellizco

      await first.up();
      await second.up();
      await third.up();
      await tester.pump();
      expect(starts, hasLength(1));
      expect(ends, hasLength(1));
    },
  );

  testWidgets(
    'la cámara se lee EN EL EVENTO: un desplazamiento del mapa sin rebuild '
    'no impide agarrar el pin (regresión)',
    (tester) async {
      await tester.pumpWidget(buildDetector());

      // El usuario desplaza el mapa: el motor real muta su cámara en cada
      // frame SIN rebuild (por eso el detector recibe un getter, no un valor).
      // Con la cámara vieja el pin se proyectaba en (400, 300); con la nueva
      // cae 150 px a la izquierda (250, 300).
      const panned = MapCamera(
        center: LatLng(-17.783, -63.1755627),
        zoom: zoom,
      );
      cameraNow = panned;
      final newTip = MapProjection.project(
        center,
        center: panned.center,
        zoom: panned.zoom,
        viewport: viewport,
      );
      expect(newTip.dx, closeTo(250, 1e-3));
      expect(newTip.dy, closeTo(300, 1e-3));

      final gesture = await tester.startGesture(newTip);
      await tester.pump();
      expect(starts, isEmpty); // sin superar la slop aún, pero sobre el pin

      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(starts, hasLength(1)); // el getter vivo hizo el hit
      final startP = starts.single.point;
      expect(startP.latitude, closeTo(center.latitude, 1e-9));
      expect(startP.longitude, closeTo(center.longitude, 1e-9));

      await gesture.up();
      await tester.pump();
      expect(ends, hasLength(1));
      expect(taps, isEmpty);
      expect(mapa, isEmpty);
    },
  );
}
