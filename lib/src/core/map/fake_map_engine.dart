import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../animation/motion.dart';
import 'map_controller.dart';
import 'map_engine.dart';
import 'map_projection.dart';
import 'map_scene.dart';
import 'map_types.dart';

/// Motor de mapa **simulado**: renderiza el [MapScene] con puro Flutter
/// (fondo de tema + polilíneas proyectadas + widgets de marcador).
///
/// No toca `maplibre_gl` ni la red, por eso es el motor que usa la fachada
/// dentro de `flutter test` (`showTiles: false` también lo fuerza). Mantiene
/// la misma API que el motor real: cámara, encuadre, `moveMarker` y
/// reenvío de taps/drags de marcadores.
class FakeMapEngine extends MapEngine {
  const FakeMapEngine({super.key, required super.scene, super.controller});

  @override
  State<FakeMapEngine> createState() => FakeMapEngineState();
}

/// Estado público para que los tests puedan simular eventos de mapa
/// (`debugFireMarkerDrag`) a través de la misma frontera que usaría el
/// motor real.
class FakeMapEngineState extends State<FakeMapEngine> implements MapEngineHost {
  late MapCamera _camera;
  Size _viewport = Size.zero;
  bool _cameraResolved = false;
  bool _readyFired = false;

  /// Posiciones forzadas por `moveMarker` o por un drag simulado.
  final Map<String, LatLng> _markerOverrides = <String, LatLng>{};

  /// Última posición de escena conocida por marcador (para detectar cuándo
  /// la pantalla cambia el `point` y hay que descartar el override).
  final Map<String, LatLng> _sceneMarkerPoints = <String, LatLng>{};

  @override
  void initState() {
    super.initState();
    _camera = MapCamera(center: widget.scene.center, zoom: widget.scene.zoom);
    widget.controller?.attach(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fireReady());
  }

  @override
  void didUpdateWidget(covariant FakeMapEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    super.dispose();
  }

  void _fireReady() {
    if (!mounted || _readyFired) return;
    _readyFired = true;
    widget.scene.onMapReady?.call();
  }

  // ------------------------------------------------------------------
  // MapEngineHost
  // ------------------------------------------------------------------

  @override
  MapCamera get camera => _camera;

  @override
  Size? get viewportSize => _viewport == Size.zero ? null : _viewport;

  @override
  void moveCamera(LatLng center, double zoom, {bool animated = true}) {
    final scene = widget.scene;
    final clamped = zoom.clamp(scene.minZoom, scene.maxZoom).toDouble();
    if (_camera.center == center && _camera.zoom == clamped) return;
    setState(() => _camera = MapCamera(center: center, zoom: clamped));
    // `animated` no aplica: el simulado salta (evita timers en tests).
    widget.scene.onPositionChanged?.call(_camera, false);
  }

  @override
  void zoomBy(double delta, {bool animated = true}) =>
      moveCamera(_camera.center, _camera.zoom + delta, animated: animated);

  @override
  Future<void> fitBounds(
    Iterable<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(56),
    double maxZoom = 17,
    bool animated = true,
  }) async {
    final list = points.toList(growable: false);
    if (list.isEmpty || _viewport == Size.zero) return;
    final camera = MapProjection.fitBounds(
      MapBounds.fromPoints(list),
      viewport: _viewport,
      padding: padding,
      minZoom: widget.scene.minZoom,
      maxZoom: maxZoom,
    );
    moveCamera(camera.center, camera.zoom, animated: animated);
  }

  @override
  void moveMarker(String markerId, LatLng point) {
    if (!mounted) return;
    setState(() => _markerOverrides[markerId] = point);
  }

  // ------------------------------------------------------------------
  // API de tests: simula el arrastre nativo de un marcador.
  // ------------------------------------------------------------------

  /// Dispara el mismo callback que emitiría el motor MapLibre al terminar un
  /// drag (por defecto `end`), moviendo además el marcador en pantalla.
  void debugFireMarkerDrag(
    String markerId,
    LatLng point, {
    MapMarkerDragPhase phase = MapMarkerDragPhase.end,
  }) {
    if (mounted) setState(() => _markerOverrides[markerId] = point);
    final scene = widget.scene;
    switch (phase) {
      case MapMarkerDragPhase.start:
        scene.onMarkerDragStart?.call(markerId, point);
      case MapMarkerDragPhase.move:
        scene.onMarkerDragUpdate?.call(markerId, point);
      case MapMarkerDragPhase.end:
        scene.onMarkerDragEnd?.call(markerId, point);
    }
  }

  /// Emite un tap sobre un marcador, igual que el motor real: prioriza el
  /// [MapMarker.onTap] propio del marcador y si no lo tiene avisa al
  /// listener genérico de escena.
  void debugFireMarkerTap(String markerId) {
    MapMarker? marker;
    for (final m in widget.scene.markers) {
      if (m.id == markerId) {
        marker = m;
        break;
      }
    }
    final onTap = marker?.onTap;
    if (onTap != null) {
      onTap();
    } else {
      widget.scene.onMarkerTap?.call(markerId);
    }
  }

  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.width > 0 && size.height > 0) {
          _viewport = size;
          if (!_cameraResolved) {
            _cameraResolved = true;
            if (scene.cameraFit != null) _camera = scene.cameraFor(size);
          }
        }

        final camera = _camera;
        final onTap = scene.onTap;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () => onTap(
                  MapProjection.unproject(
                    Offset(size.width / 2, size.height / 2),
                    center: camera.center,
                    zoom: camera.zoom,
                    viewport: size,
                  ),
                ),
          child: ColoredBox(
            color: scene.background,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _PolylinePainter(
                    polylines: scene.polylines,
                    camera: camera,
                    viewport: size,
                  ),
                ),
                for (final pulse in scene.pulses)
                  _buildPulse(pulse, camera, size),
                for (final marker in scene.markers)
                  _buildMarker(marker, camera, size),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Aura pulsante proyectada: un [Ambient] (kit de motion: bucle continuo
  /// en la app, acotado bajo `flutter test` y respetando «reducir
  /// animaciones») pinta ondas que crecen desde [MapPulse.baseRadius] y se
  /// funden al llegar a [MapPulse.maxRadius].
  Widget _buildPulse(MapPulse pulse, MapCamera camera, Size size) {
    final pixel = MapProjection.project(
      pulse.point,
      center: camera.center,
      zoom: camera.zoom,
      viewport: size,
    );
    final diameter = pulse.maxRadius * 2;
    return Positioned(
      left: pixel.dx - pulse.maxRadius,
      top: pixel.dy - pulse.maxRadius,
      width: diameter,
      height: diameter,
      child: Ambient(
        builder: (context, _, phase, _) => CustomPaint(
          painter: _PulsePainter(progress: phase, pulse: pulse),
        ),
      ),
    );
  }

  Widget _buildMarker(MapMarker marker, MapCamera camera, Size size) {
    // La pantalla cambió el punto de escena ⇒ el override queda obsoleto.
    final scenePoint = _sceneMarkerPoints[marker.id];
    if (scenePoint == null || scenePoint != marker.point) {
      _markerOverrides.remove(marker.id);
    }
    _sceneMarkerPoints[marker.id] = marker.point;

    final point = _markerOverrides[marker.id] ?? marker.point;
    final pixel = MapProjection.project(
      point,
      center: camera.center,
      zoom: camera.zoom,
      viewport: size,
    );
    final offset = switch (marker.anchor) {
      MapMarkerAnchor.center => Offset(marker.width / 2, marker.height / 2),
      MapMarkerAnchor.top => Offset(marker.width / 2, 0),
      MapMarkerAnchor.bottom => Offset(marker.width / 2, marker.height),
    };
    return Positioned(
      left: pixel.dx - offset.dx,
      top: pixel.dy - offset.dy,
      width: marker.width,
      height: marker.height,
      child: SizedBox(
        width: marker.width,
        height: marker.height,
        child: marker.child,
      ),
    );
  }
}

/// Pinta las polilíneas del escenario proyectadas con la cámara actual.
class _PolylinePainter extends CustomPainter {
  const _PolylinePainter({
    required this.polylines,
    required this.camera,
    required this.viewport,
  });

  final List<MapPolyline> polylines;
  final MapCamera camera;
  final Size viewport;

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in polylines) {
      if (line.points.length < 2) continue;
      final pixels = <Offset>[
        for (final point in line.points)
          MapProjection.project(
            point,
            center: camera.center,
            zoom: camera.zoom,
            viewport: viewport,
          ),
      ];

      if (line.outline) {
        canvas.drawPath(
          _path(pixels),
          Paint()
            ..color = line.outlineColor.withValues(alpha: line.opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = line.width + 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..isAntiAlias = true,
        );
      }

      final paint = Paint()
        ..color = line.color.withValues(alpha: line.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = line.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      if (line.dashed) {
        _drawDashed(canvas, pixels, paint);
      } else {
        canvas.drawPath(_path(pixels), paint);
      }
    }
  }

  static Path _path(List<Offset> pixels) {
    final path = Path()..moveTo(pixels.first.dx, pixels.first.dy);
    for (var i = 1; i < pixels.length; i++) {
      path.lineTo(pixels[i].dx, pixels[i].dy);
    }
    return path;
  }

  /// Trazo discontinuo en espacio de pantalla (10 px pintado / 8 px hueco).
  static void _drawDashed(Canvas canvas, List<Offset> pixels, Paint paint) {
    const on = 10.0;
    const off = 8.0;
    var pattern = 0.0;
    for (var i = 0; i < pixels.length - 1; i++) {
      final a = pixels[i];
      final b = pixels[i + 1];
      final delta = b - a;
      final length = delta.distance;
      if (length <= 0) continue;
      final direction = delta / length;
      var position = 0.0;
      while (position < length) {
        final phase = pattern % (on + off);
        final remaining = phase < on ? on - phase : (on + off) - phase;
        final step = math.min(remaining, length - position);
        if (phase < on) {
          canvas.drawLine(
            a + direction * position,
            a + direction * (position + step),
            paint,
          );
        }
        position += step;
        pattern += step;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PolylinePainter oldDelegate) =>
      oldDelegate.polylines != polylines ||
      oldDelegate.camera != camera ||
      oldDelegate.viewport != viewport;
}

/// Pinta las ondas de un [MapPulse] en el motor simulado.
///
/// El box local mide `maxRadius * 2` (ver `_buildPulse`), así que el centro
/// del pulso cae justo en el centro del lienzo. Van DOS ondas escalonadas
/// media vuelta entre sí —como el halo de Google Maps— que nacen en
/// [MapPulse.baseRadius] con opacidad máxima y mueren en [MapPulse.maxRadius]
/// con opacidad 0. El punto central NO se pinta aquí: llega como marcador de
/// la escena.
class _PulsePainter extends CustomPainter {
  const _PulsePainter({required this.progress, required this.pulse});

  /// Fase de la vuelta actual (0..1), provista por [Ambient].
  final double progress;
  final MapPulse pulse;

  /// Tres ondas simultáneas desfasadas un tercio de vuelta: con halos tan
  /// delgados sería fácil que el halo muriera entre dos crestas.
  static const int _waves = 3;

  /// Opacidad con la que nace cada onda. < del halo de Google Maps
  /// (~0.4 al nacer cerca del punto); 0.26 era invisible sobre tiles.
  static const double _peakOpacity = 0.38;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var wave = 0; wave < _waves; wave++) {
      final t = (progress + wave / _waves) % 1.0;
      final radius =
          pulse.baseRadius + (pulse.maxRadius - pulse.baseRadius) * t;
      final color = pulse.color.withValues(alpha: _peakOpacity * (1 - t));
      // Relleno DIFUSO, no un aro: el disco es plano por dentro y se
      // desvanece en el borde, que es lo que hace que se lea como el halo de
      // Google Maps y no como una onda dibujada.
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color, color.withValues(alpha: 0)],
            stops: const [0, 0.6, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}
