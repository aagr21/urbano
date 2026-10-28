import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../map/map_tile.dart';
import '../theme/app_theme.dart';

/// Miniatura de una capa del mapa, dibujada a mano (sin red ni imágenes).
///
/// El selector de capas necesita que cada opción se *vea*, no solo que se nombre:
/// esto pinta un mini-mapa con la paleta del [MapTile] — retícula de calles,
/// manzanas, un parque, un canal y un recorrido de micro — para que «Mapa»,
/// «Satélite» y «Oscuro» se distingieran de un vistazo. Se usa en dos tamaños:
/// la vista grande de la tarjeta y la pastilla del modo automático.
class MapLayerPreview extends StatelessWidget {
  const MapLayerPreview({super.key, required this.tile, this.showRoute = true});

  /// Capa cuya paleta se imita.
  final MapTile tile;

  /// Si dibuja el recorrido de micro (se apaga en las miniaturas diminutas).
  final bool showRoute;

  @override
  Widget build(BuildContext context) => CustomPaint(
    // Sin tamaño propio: ocupa lo que le regale el padre (Stack/Card).
    painter: _LayerPreviewPainter(tile: tile, showRoute: showRoute),
    size: Size.infinite,
  );
}

class _LayerPreviewPainter extends CustomPainter {
  const _LayerPreviewPainter({required this.tile, required this.showRoute});

  final MapTile tile;
  final bool showRoute;

  @override
  void paint(Canvas canvas, Size size) {
    final p = tile.preview;
    final rect = Offset.zero & size;
    canvas.clipRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.sm)),
    );
    canvas.drawRect(rect, Paint()..color = p.canvas);

    switch (tile) {
      case MapTile.googleSatellite:
        _paintSatellite(canvas, size, p);
      case MapTile.osm:
      case MapTile.googleRoadmap:
      case MapTile.dark:
        _paintStreetGrid(canvas, size, p);
    }

    if (showRoute) _paintRoute(canvas, size, p);
  }

  /// Retícula urbana: manzanas, calles blancas, avenida en diagonal, parque y
  /// canal. Es la misma geometría para las tres capas vectoriales; lo que cambia
  /// es la paleta, que es justamente lo que se quiere comparar.
  void _paintStreetGrid(Canvas canvas, Size size, MapLayerPreviewPalette p) {
    final w = size.width;
    final h = size.height;

    // Manzanas: un solo relleno bajo toda la retícula.
    canvas.drawRect(
      Rect.fromLTRB(0, 0, w, h).deflate(-1),
      Paint()..color = p.block,
    );

    final street = Paint()
      ..color = p.street
      ..strokeWidth = math.max(1.2, w * 0.018)
      ..strokeCap = StrokeCap.round;

    // Calles horizontales y verticales (3 × 4, con algún desvío para que no
    // parezca una cuadrícula perfecta).
    for (final fy in const [0.22, 0.46, 0.74]) {
      final y = h * fy;
      canvas.drawLine(Offset(0, y), Offset(w, y + h * 0.04), street);
    }
    for (final fx in const [0.18, 0.42, 0.63, 0.86]) {
      final x = w * fx;
      canvas.drawLine(Offset(x, 0), Offset(x + w * 0.03, h), street);
    }

    // Parque y canal, en esquinas opuestas.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, h * 0.56, w * 0.24, h * 0.3),
        const Radius.circular(AppRadius.sm),
      ),
      Paint()..color = p.park,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.62, 0)
        ..cubicTo(w * 0.56, h * 0.36, w * 0.86, h * 0.52, w * 0.78, h),
      Paint()
        ..color = p.water
        ..strokeWidth = math.max(2.5, w * 0.045)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Avenida: más ancha y en diagonal, la que da carácter al dibujo.
    canvas.drawLine(
      Offset(-w * 0.1, h * 0.9),
      Offset(w * 0.95, -h * 0.12),
      Paint()
        ..color = p.arterial
        ..strokeWidth = math.max(3, w * 0.06)
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Satélite: manchas de vegetación, terreno y agua, con calles apenas visibles
  /// como hilos claros. No hay retícula: se lee como foto aérea.
  void _paintSatellite(Canvas canvas, Size size, MapLayerPreviewPalette p) {
    final w = size.width;
    final h = size.height;

    void blob(double cx, double cy, double rx, double ry, Color color) =>
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * cx, h * cy),
            width: w * rx * 2,
            height: h * ry * 2,
          ),
          Paint()..color = color,
        );

    blob(0.2, 0.25, 0.32, 0.3, p.park);
    blob(0.78, 0.7, 0.36, 0.32, p.park);
    blob(0.55, 0.2, 0.26, 0.22, p.block);
    blob(0.16, 0.78, 0.24, 0.22, p.block);
    blob(0.9, 0.12, 0.22, 0.2, p.water);

    // Trama urbana: manzanas tenues que sugieren barrios sin dibujarlos.
    final grid = Paint()
      ..color = p.street.withValues(alpha: 0.22)
      ..strokeWidth = math.max(0.8, w * 0.008);
    for (var i = 1; i < 6; i++) {
      final y = h * i / 6;
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
      final x = w * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }

    // Una vía ancha cruzando en diagonal.
    canvas.drawLine(
      Offset(0, h * 0.68),
      Offset(w, h * 0.12),
      Paint()
        ..color = p.arterial.withValues(alpha: 0.55)
        ..strokeWidth = math.max(2, w * 0.035)
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Recorrido de micro con paradas: es lo que el usuario va a ver sobre la capa,
  /// así que también sirve para comprobar que la tinta de la ruta se lee bien.
  void _paintRoute(Canvas canvas, Size size, MapLayerPreviewPalette p) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.86)
      ..lineTo(w * 0.32, h * 0.56)
      ..lineTo(w * 0.54, h * 0.6)
      ..lineTo(w * 0.72, h * 0.3)
      ..lineTo(w * 0.94, h * 0.24);

    // Halo del color de la ruta: la miniatura es oscura o saturada y la línea
    // fina desaparecería.
    canvas.drawPath(
      path,
      Paint()
        ..color = p.route.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(4, w * 0.075)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = p.route
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, w * 0.028)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final stop = Paint()..color = Colors.white;
    for (final o in [
      const Offset(0.08, 0.86),
      const Offset(0.54, 0.6),
      const Offset(0.94, 0.24),
    ]) {
      canvas.drawCircle(
        Offset(w * o.dx, h * o.dy),
        math.max(1.6, w * 0.02),
        stop,
      );
    }
  }

  @override
  bool shouldRepaint(_LayerPreviewPainter old) =>
      old.tile != tile || old.showRoute != showRoute;
}
