import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'map_projection.dart';
import 'map_types.dart';

/// Un pin arrastrable de la escena, con su posición geográfica y su forma de
/// agarre en pantalla (px).
///
/// [hitRadiusPx] es el radio isotrópico de respaldo alrededor del punto
/// ancla. Cuando llegan [headRadiusPx]/[headCenterDy]/[bodyWidthPx] (los pines
/// teardrop del mapa), el agarre se calcula con la FORMA: cabeza circular
/// ubicada [headCenterDy] por encima del punto y "cuello" hasta la punta, así
/// un toque al lado del pin (que en un radio isotrópico grande era agarrado)
/// queda en pan del mapa y el pin solo se mueve si de verdad lo tocas.
typedef DraggableEndpoint = ({
  String id,
  LatLng point,
  double hitRadiusPx,
  double? headRadiusPx,
  double? headCenterDy,
  double? bodyWidthPx,
});

/// Detecta en Dart el arrastre (y el tap) de los pines arrastrables del mapa.
///
/// Por qué existe: en algunos dispositivos el arrastre nativo de `maplibre_gl`
/// (`feature#onDrag`) no dispara eventos y el pin no responde al dedo aunque
/// el tap sí funcione. Esta capa evita depender de esa cadena nativa:
///
/// * Si el toque empieza sobre un pin, se une a la arena de Flutter y la
///   **gana de inmediato** (eager winner). En modo virtual display —que es
///   como corre la app— la vista nativa solo recibe los toques si gana la
///   arena, así que con nuestra victoria **el mapa no se desplaza** y el dedo
///   mueve el pin.
/// * Si el toque no empieza sobre un pin, **no participa** en la arena: el
///   mapa recibe el gesto tal cual, sin ninguna interferencia.
///
/// Cada posición del dedo se proyecta a coordenadas con [MapProjection]
/// usando la cámara y el viewport actuales (bearing/tilt son 0 en esta app).
/// El callback `onDragStart` se emite solo al superar la slop de Flutter
/// (`kTouchSlop`), igual que el `onMoveBegin` nativo: un toque que se levanta
/// sin superarla se reporta como [onTap] del pin, de modo que "tocar el pin
/// para cambiarlo" sigue funcionando.
///
/// Un **segundo dedo** durante la sesión es un pellizco (zoom), nunca un
/// arrastre: si el arrastre ya había arrancado, se emite `onDragEnd` con el
/// punto DE ARRANQUE (el pin vuelve a su lugar y las coordenadas no cambian),
/// y si no había arrancado no se emite nada. Así el zoom con dos dedos cerca
/// de un pin no "arrastra" el marcador ni replanifica.
class EndpointDragDetector extends StatefulWidget {
  const EndpointDragDetector({
    super.key,
    required this.camera,
    required this.viewport,
    required this.targets,
    required this.child,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onTap,
  });

  /// Cámara **viva**: getter consultado en cada evento (down/move/up).
  ///
  /// CRÍTICO: no puede congelarse en el build. El motor actualiza su cámara
  /// durante los desplazamientos del usuario sin rebuild (`_onCameraMove`
  /// solo muta el estado), así que una cámara capturada al construir queda
  /// vieja de inmediato, la proyección del pin cae en el punto equivocado de
  /// la pantalla y el arrastre "no acierta" al pin (el mapa se desplaza).
  final MapCamera Function() camera;

  /// Tamaño del área del mapa (misma caja que ocupa [child]).
  final Size viewport;

  /// Pines arrastrables con su radio de impacto.
  final List<DraggableEndpoint> targets;

  final Widget child;

  final void Function(String id, LatLng point)? onDragStart;
  final void Function(String id, LatLng point)? onDragUpdate;
  final void Function(String id, LatLng point)? onDragEnd;
  final void Function(String id)? onTap;

  @override
  State<EndpointDragDetector> createState() => _EndpointDragDetectorState();
}

class _EndpointDragDetectorState extends State<EndpointDragDetector>
    implements GestureArenaMember {
  String? _activeId;
  int? _activePointer;

  /// TODOS los punteros abajo, no solo el del arrastre activo.
  ///
  /// Un zoom real suele empezar con el primer dedo en el MAPA y el segundo
  /// dedo cayendo sobre un pin: sin este rastro, el segundo down no sabría
  /// que hay un pellizco en curso, reclamaría el pin y lo arrastraría
  /// ("los marcadores se mueven y recalcula al hacer zoom").
  final Set<int> _pointers = {};

  /// Posición del `down` y última posición conocida (locales a esta caja).
  Offset _downLocal = Offset.zero;
  Offset _lastLocal = Offset.zero;

  /// Desplazamiento máximo desde el `down` (para distinguir tap de arrastre).
  double _maxMove = 0;

  /// Offset dedo→punta del pin en el `down`: evita que el pin "salte" al
  /// centro del dedo al empezar a arrastrar.
  Offset _grabOffset = Offset.zero;

  /// Punto del pin en el momento del `down`: así `onDragStart` reporta la
  /// posición original, igual que el `onMoveBegin` nativo.
  late LatLng _startPoint;

  /// `true` cuando la slop se superó y [EndpointDragDetector.onDragStart] ya
  /// se emitió (hasta entonces el recorrido puede terminar en tap).
  bool _dragStarted = false;

  @override
  void dispose() {
    // Si el widget muere a mitad de arrastre, cierra el recorrido para no
    // dejar al consumidor (planner) esperando el final del drag.
    if (_activeId != null) {
      final id = _activeId!;
      final point = _pointFor(_lastLocal);
      _activeId = null;
      if (_dragStarted) {
        widget.onDragEnd?.call(id, point);
      }
    }
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Arena de gestos
  // ------------------------------------------------------------------

  @override
  void acceptGesture(int pointer) {
    // Victoria confirmada por la arena: no hay nada que hacer, el arrastre
    // ya está en marcha (o el recorrido terminó en tap).
  }

  @override
  void rejectGesture(int pointer) {
    // Caso límite: otro miembro ganó la arena para este puntero. Cierra como
    // arrastre para no dejar una secuencia a medias (el mapa manda).
    if (pointer == _activePointer && _activeId != null) {
      _end(asTap: false);
    }
  }

  // ------------------------------------------------------------------
  // Manejo de punteros
  // ------------------------------------------------------------------

  void _handleDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_activeId != null) {
      // Segundo dedo: es un PELLIZCO (zoom), no un arrastre. Si el primer
      // dedo ya arrancó el arrastre, se CANCELA devolviendo el pin a su punto
      // de arranque: así un zoom accidental sobre/desde un pin no cambia las
      // coordenadas ni "recalcula" el viaje.
      _abortForPinch();
      return;
    }
    if (_pointers.length > 1) {
      // Pellizco YA en curso (el primer dedo cayó fuera o encima de otro
      // pin): este down es la segunda punta del zoom. NO se reclama el pin:
      // el gesto entero le pertenece al mapa.
      return;
    }
    final target = _targetAt(event.localPosition);
    if (target == null) {
      // Fuera de un pin: no entramos en la arena y el mapa decide el gesto.
      return;
    }
    GestureBinding.instance.gestureArena
        .add(event.pointer, this)
        .resolve(GestureDisposition.accepted);
    _activeId = target.id;
    _activePointer = event.pointer;
    _downLocal = event.localPosition;
    _lastLocal = event.localPosition;
    _maxMove = 0;
    _dragStarted = false;
    _grabOffset = event.localPosition - _project(target.point);
    _startPoint = target.point;
  }

  void _handleMove(PointerMoveEvent event) {
    if (_activeId == null || event.pointer != _activePointer) return;
    _lastLocal = event.localPosition;
    final move = (event.localPosition - _downLocal).distance;
    if (move > _maxMove) _maxMove = move;
    if (!_dragStarted) {
      if (_maxMove <= kTouchSlop) return;
      _dragStarted = true;
      widget.onDragStart?.call(_activeId!, _startPoint);
      return;
    }
    widget.onDragUpdate?.call(_activeId!, _pointFor(event.localPosition));
  }

  void _handleUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (_activeId == null || event.pointer != _activePointer) return;
    _lastLocal = event.localPosition;
    _end(asTap: _maxMove <= kTouchSlop);
  }

  void _handleCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (_activeId == null || event.pointer != _activePointer) return;
    _end(asTap: false);
  }

  /// Segundo dedo durante la sesión: pellizco de zoom. Si el arrastre ya
  /// había arrancado, emite `onDragEnd` con el punto DE ARRANQUE (el pin
  /// vuelve y las coordenadas no cambian); si no, no emite nada.
  void _abortForPinch() {
    if (kDebugMode && _activeId != null) {
      debugPrint('[drag] cancel pinch id=$_activeId');
    }
    _end(asTap: false, pointOverride: _dragStarted ? _startPoint : null);
  }

  void _end({required bool asTap, LatLng? pointOverride}) {
    final id = _activeId;
    if (id == null) return;
    final started = _dragStarted;
    final point = pointOverride ?? _pointFor(_lastLocal);
    _activeId = null;
    _activePointer = null;
    _dragStarted = false;
    if (started) {
      widget.onDragEnd?.call(id, point);
    } else if (asTap) {
      widget.onTap?.call(id);
    }
    // Si se cortó (segundo dedo / cancelación) antes de superar la slop, no
    // era ni un arrastre ni un tap válido: no se emite nada. La arena de este
    // recorrido quedó resuelta al ganarla en el down.
  }

  // ------------------------------------------------------------------
  // Proyección
  // ------------------------------------------------------------------

  /// Tolerancia de agarre alrededor de la forma del pin (borde del dedo).
  static const _gripPad = 8.0;

  bool _contains(DraggableEndpoint target, Offset local) {
    if (target.headRadiusPx == null) {
      // Compatibilidad: radio isotrópico alrededor del punto ancla.
      return (_project(target.point) - local).distance <= target.hitRadiusPx;
    }
    final tip = _project(target.point);
    final dx = (local.dx - tip.dx).abs();
    // Positivo cuando el toque queda por ENCIMA de la punta (el pin crece
    // hacia arriba desde su ancla en la punta).
    final dy = tip.dy - local.dy;
    final headRadius = target.headRadiusPx!;
    final headCenterDy = target.headCenterDy ?? 0;
    // Cabeza del pin (círculo donde el usuario apunta naturalmente).
    final headDy = dy - headCenterDy;
    final headDist = math.sqrt(dx * dx + headDy * headDy);
    if (headDist <= headRadius + _gripPad) return true;
    // Cuello/punta: rect que baja hasta el ancla.
    final bodyWidth = (target.bodyWidthPx ?? headRadius * 2) / 2 + _gripPad;
    if (dx <= bodyWidth && dy >= -_gripPad && dy <= headCenterDy) return true;
    return false;
  }

  DraggableEndpoint? _targetAt(Offset local) {
    if (widget.viewport.isEmpty || widget.targets.isEmpty) return null;
    DraggableEndpoint? best;
    var bestDistance = double.infinity;
    for (final target in widget.targets) {
      final distance = (_project(target.point) - local).distance;
      if (_contains(target, local) && distance < bestDistance) {
        best = target;
        bestDistance = distance;
      }
    }
    return best;
  }

  MapCamera get _camera => widget.camera();

  Offset _project(LatLng point) => MapProjection.project(
    point,
    center: _camera.center,
    zoom: _camera.zoom,
    viewport: widget.viewport,
  );

  /// Coordenada bajo [local] compensando el agarre inicial.
  LatLng _pointFor(Offset local) => MapProjection.unproject(
    local - _grabOffset,
    center: _camera.center,
    zoom: _camera.zoom,
    viewport: widget.viewport,
  );

  // ------------------------------------------------------------------
  // Widget
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: _handleUp,
      onPointerCancel: _handleCancel,
      child: widget.child,
    );
  }
}
