import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';

/// Ilustración plana de un acceso de la portada.
///
/// La referencia dibuja cada cuadro con una pieza propia (el micro, la ruta,
/// el pin, el megáfono) en vez de un ícono genérico dentro de un disco: el
/// lienzo de la portada se lee como un mapa ilustrado y no como una lista de
/// botones. Todo se pinta aquí, sin imágenes ni red, así el home arranca igual
/// en cualquier teléfono.
///
/// La paleta sale del tema ([ColorScheme]): en claro el cuerpo es el verde
/// agua profundo y los detalles claros; en oscuro el cuerpo es el primario
/// apagado con detalles oscuros dentro de la pieza, y la tinta de lo que se
/// dibuja sobre la tarjeta (aros, líneas) es el blanco de `onSurface`. Ninguna
/// pieza deja tinta oscura sobre fondo oscuro.
enum HomeActionArt { micros, journey, places, complaints }

class HomeActionIllustration extends StatelessWidget {
  const HomeActionIllustration(
    this.art, {
    super.key,
    this.size = const Size(124, 84),
  });

  final HomeActionArt art;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // La base es la tarjeta de grafito (o el blanco en claro); los detalles de
    // la pieza se invierten con el tema para que nunca queden oscuros sobre
    // oscuro.
    final base = colors.surface;
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        painter: _ArtPainter(
          art: art,
          body: colors.primary,
          detail: colors.onPrimary,
          ink: colors.onSurface,
          soft: AppColors.tint(colors.primary, base, 0.14),
          line: AppColors.tint(colors.primary, base, 0.34),
          warm: AppColors.accent,
          aqua: colors.primary,
          coral: AppColors.accent,
          accent: dark ? colors.secondary : AppColors.aqua,
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  const _ArtPainter({
    required this.art,
    required this.body,
    required this.detail,
    required this.ink,
    required this.soft,
    required this.line,
    required this.warm,
    required this.aqua,
    required this.coral,
    required this.accent,
  });

  final HomeActionArt art;
  final Color body;
  final Color detail;
  final Color ink;
  final Color soft;
  final Color line;
  final Color warm;
  final Color aqua;
  final Color coral;
  final Color accent;

  /// Lienzo de diseño: todas las coordenadas de abajo viven aquí y se escalan
  /// al tamaño real conservando la proporción.
  static const Size _design = Size(124, 84);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / _design.width,
      size.height / _design.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - _design.width * scale) / 2,
      (size.height - _design.height * scale) / 2,
    );
    canvas.scale(scale, scale);
    switch (art) {
      case HomeActionArt.micros:
        _paintMicros(canvas);
      case HomeActionArt.journey:
        _paintJourney(canvas);
      case HomeActionArt.places:
        _paintPlaces(canvas);
      case HomeActionArt.complaints:
        _paintComplaints(canvas);
    }
    canvas.restore();
  }

  // ── Micro: de perfil, con las ventanas encendidas ────────────────────────
  void _paintMicros(Canvas canvas) {
    // Velocity lines with gradient
    final speedPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          line.withValues(alpha: 0.3),
          line,
          line.withValues(alpha: 0.3),
        ],
      ).createShader(const Rect.fromLTWH(0, 25, 124, 15))
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(3, 30), const Offset(13, 30), speedPaint);
    canvas.drawLine(const Offset(7, 41), const Offset(15, 41), speedPaint);

    // Glow behind bus
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 12, 102, 56),
        const Radius.circular(15),
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [aqua.withValues(alpha: 0.15), Colors.transparent],
        ).createShader(const Rect.fromLTWH(14, 12, 102, 56)),
    );

    // Carrocería con gradiente
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 16, 94, 48),
        const Radius.circular(13),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [body, Color.lerp(body, aqua, 0.3)!, body],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(const Rect.fromLTWH(18, 16, 94, 48)),
    );

    // Banda de ventanas: cuatro cristales con brillo
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 24, 78, 20),
        const Radius.circular(5),
      ),
      Paint()..color = detail,
    );

    // Window glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 26, 74, 16),
        const Radius.circular(4),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            detail.withValues(alpha: 0.8),
            detail.withValues(alpha: 0.3),
          ],
        ).createShader(const Rect.fromLTWH(28, 26, 74, 16)),
    );

    final mullion = Paint()
      ..color = body
      ..strokeWidth = 2.6;
    for (final x in const [45.5, 65.0, 84.5]) {
      canvas.drawLine(Offset(x, 25), Offset(x, 43), mullion);
    }

    // Cartel de destino y puerta - coral
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 17, 27, 5),
        const Radius.circular(2.5),
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [coral, Color.lerp(coral, Colors.orange, 0.3)!],
        ).createShader(const Rect.fromLTWH(30, 17, 27, 5)),
    );

    // Door highlight
    canvas.drawLine(
      const Offset(88, 47),
      const Offset(88, 60),
      Paint()
        ..color = detail
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // Faldón, ruedas y faro
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 59, 78, 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = ink.withValues(alpha: 0.18),
    );
    _wheel(canvas, const Offset(38, 66), 8);
    _wheel(canvas, const Offset(92, 66), 8);

    // Headlight with glow
    canvas.drawCircle(
      const Offset(106, 55),
      5,
      Paint()
        ..shader = RadialGradient(
          colors: [coral.withValues(alpha: 0.4), Colors.transparent],
        ).createShader(const Rect.fromLTWH(101, 50, 10, 10)),
    );
    canvas.drawCircle(const Offset(106, 55), 3.2, Paint()..color = warm);
  }

  void _wheel(Canvas canvas, Offset center, double radius) {
    // Tire
    canvas.drawCircle(center, radius, Paint()..color = ink);
    // Rim
    canvas.drawCircle(center, radius * 0.36, Paint()..color = detail);
    // Hub
    canvas.drawCircle(center, radius * 0.18, Paint()..color = aqua);
  }

  // ── Viaje: ruta punteada que sale del origen y termina en el pin ─────────
  void _paintJourney(Canvas canvas) {
    final path = Path()
      ..moveTo(14, 66)
      ..quadraticBezierTo(48, 68, 60, 46)
      ..quadraticBezierTo(74, 22, 106, 28);

    // Path glow
    _dashed(
      canvas,
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [aqua.withValues(alpha: 0.2), coral.withValues(alpha: 0.2)],
        ).createShader(const Rect.fromLTWH(0, 20, 124, 50))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    _dashed(
      canvas,
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );

    // Paradas intermedias with pulse effect
    for (final stop in const [Offset(38, 63), Offset(76, 34)]) {
      canvas.drawCircle(stop, 4, Paint()..color = line.withValues(alpha: 0.3));
      canvas.drawCircle(stop, 2.8, Paint()..color = line);
      canvas.drawCircle(stop, 1.4, Paint()..color = aqua);
    }

    // Origen: aro claro con el punto de marca adentro.
    canvas.drawCircle(
      const Offset(14, 66),
      7,
      Paint()..color = detail.withValues(alpha: 0.3),
    );
    canvas.drawCircle(const Offset(14, 66), 5.4, Paint()..color = detail);
    canvas.drawCircle(const Offset(14, 66), 3.4, Paint()..color = body);

    // Destino: el pin con glow
    _pin(canvas, const Offset(106, 28), 12.5, glowColor: coral);

    // La unidad, sobre el tramo medio del recorrido.
    _miniBus(canvas, const Offset(52, 50));
  }

  void _miniBus(Canvas canvas, Offset center) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -7, 26, 14),
        const Radius.circular(4),
      ),
      Paint()
        ..shader = LinearGradient(colors: [body, Color.lerp(body, aqua, 0.4)!])
            .createShader(const Rect.fromLTWH(-13, -7, 26, 14)),
    );
    final glass = Paint()..color = detail;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9, -4, 8, 6),
        const Radius.circular(1.5),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1, -4, 8, 6),
        const Radius.circular(1.5),
      ),
      glass,
    );
    canvas.drawCircle(const Offset(-7, 8), 2.6, Paint()..color = ink);
    canvas.drawCircle(const Offset(7, 8), 2.6, Paint()..color = ink);
    canvas.restore();
  }

  // ── Lugares: pin sobre la mancha de la ciudad ────────────────────────────
  void _paintPlaces(Canvas canvas) {
    // Ground shadow with gradient
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(62, 76), width: 78, height: 10),
      Paint()
        ..shader = RadialGradient(
          colors: [ink.withValues(alpha: 0.12), Colors.transparent],
        ).createShader(const Rect.fromLTWH(23, 71, 78, 10)),
    );

    // Bloque de mapa con su retícula - enhanced with gradient
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 44, 84, 30),
        const Radius.circular(8),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [soft, Color.lerp(soft, aqua, 0.15)!, soft],
        ).createShader(const Rect.fromLTWH(20, 44, 84, 30)),
    );

    final grid = Paint()
      ..color = line
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(28, 58), const Offset(96, 58), grid);
    canvas.drawLine(const Offset(44, 47), const Offset(44, 70), grid);
    canvas.drawLine(const Offset(76, 47), const Offset(76, 70), grid);

    // Manzanas with more detail
    _drawBuilding(canvas, const Offset(30, 62), 9, 8);
    _drawBuilding(canvas, const Offset(84, 48), 9, 8);

    // Small accent buildings
    _drawBuilding(
      canvas,
      const Offset(52, 52),
      6,
      12,
      color: line.withValues(alpha: 0.5),
    );
    _drawBuilding(
      canvas,
      const Offset(68, 48),
      5,
      14,
      color: line.withValues(alpha: 0.5),
    );

    _pin(canvas, const Offset(62, 60), 16, glowColor: aqua);
  }

  void _drawBuilding(
    Canvas canvas,
    Offset pos,
    double w,
    double h, {
    Color? color,
  }) {
    final c = color ?? line;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pos.dx, pos.dy, w, h),
        const Radius.circular(2),
      ),
      Paint()..color = c,
    );
    // Windows
    final winPaint = Paint()..color = detail.withValues(alpha: 0.6);
    final cols = (w / 3).floor().clamp(1, 3);
    final rows = (h / 4).floor().clamp(1, 2);
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              pos.dx + 1 + i * (w / cols),
              pos.dy + 1 + j * (h / rows),
              (w / cols) - 1.5,
              (h / rows) - 1.5,
            ),
            const Radius.circular(0.5),
          ),
          winPaint,
        );
      }
    }
  }

  // ── Denuncias: megáfono con su onda ──────────────────────────────────────
  void _paintComplaints(Canvas canvas) {
    // Mango detrás del cono with gradient
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 42, 16, 28),
        const Radius.circular(8),
      ),
      Paint()
        ..shader = LinearGradient(colors: [body, Color.lerp(body, coral, 0.3)!])
            .createShader(const Rect.fromLTWH(32, 42, 16, 28)),
    );

    // Cono with gradient
    final cone = Path()
      ..moveTo(34, 34)
      ..lineTo(74, 18)
      ..lineTo(74, 58)
      ..lineTo(34, 46)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = LinearGradient(colors: [body, Color.lerp(body, coral, 0.4)!])
            .createShader(const Rect.fromLTWH(34, 18, 40, 40)),
    );

    // Brillo del cono.
    final gleam = Path()
      ..moveTo(40, 37)
      ..lineTo(70, 24)
      ..lineTo(70, 30)
      ..lineTo(40, 42)
      ..close();
    canvas.drawPath(gleam, Paint()..color = detail.withValues(alpha: 0.26));

    // Boca with gradient
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(75, 38), width: 11, height: 41),
      Paint()
        ..shader = RadialGradient(
          colors: [detail, Color.lerp(detail, aqua, 0.3)!],
        ).createShader(const Rect.fromLTWH(69.5, 17.5, 11, 41)),
    );

    // Onda de sonido with colors
    final waveColors = [line, aqua, coral];
    for (int i = 0; i < 3; i++) {
      final radius = 17.0 + i * 9.0;
      final wavePaint = Paint()
        ..color = waveColors[i % waveColors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4 - i * 0.4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(80, 38), radius: radius),
        -0.55,
        1.1,
        false,
        wavePaint,
      );
    }

    // Accent dot
    canvas.drawCircle(const Offset(106, 14), 3.2, Paint()..color = warm);
  }

  // ── Piezas compartidas ───────────────────────────────────────────────────

  /// Pin de mapa: cabeza redonda unida a la punta por una unión limpia.
  void _pin(Canvas canvas, Offset tip, double radius, {Color? glowColor}) {
    final head = tip - Offset(0, radius * 0.9);
    final circle = Path()
      ..addOval(Rect.fromCircle(center: head, radius: radius));
    final tail = Path()
      ..moveTo(head.dx - radius * 0.66, head.dy + radius * 0.6)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(head.dx + radius * 0.66, head.dy + radius * 0.6)
      ..close();
    final pinPath = Path.combine(PathOperation.union, circle, tail);

    // Glow
    if (glowColor != null) {
      canvas.drawPath(
        pinPath,
        Paint()
          ..shader = RadialGradient(
            colors: [glowColor.withValues(alpha: 0.3), Colors.transparent],
          ).createShader(Rect.fromCircle(center: head, radius: radius * 1.5)),
      );
    }

    canvas.drawPath(pinPath, Paint()..color = body);
    canvas.drawCircle(head, radius * 0.36, Paint()..color = detail);
  }

  /// Traza [path] en guiones: la ruta se lee como recorrido, no como borde.
  void _dashed(Canvas canvas, Path path, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.art != art ||
      old.body != body ||
      old.detail != detail ||
      old.ink != ink ||
      old.soft != soft ||
      old.line != line ||
      old.warm != warm ||
      old.aqua != aqua ||
      old.coral != coral ||
      old.accent != accent;
}
