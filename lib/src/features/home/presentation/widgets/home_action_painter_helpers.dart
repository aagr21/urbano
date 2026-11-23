import 'package:flutter/painting.dart';

import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;

/// Funciones auxiliares compartidas entre los pintores de ilustraciones.

/// Traza [path] en guiones: la ruta se lee como recorrido, no como borde.
void drawDashed(Canvas canvas, Path path, Paint paint) {
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

/// Mini micro con colores fijos (del HTML).
void drawMiniBus(
  Canvas canvas,
  Offset center,
  Color busBody,
  Color glass,
  Color wheel,
) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(-0.15);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-9, -5.5, 18, 11),
      const Radius.circular(3),
    ),
    Paint()..color = busBody,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-7, -3.5, 4, 4),
      const Radius.circular(1),
    ),
    Paint()..color = glass,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-1, -3.5, 4, 4),
      const Radius.circular(1),
    ),
    Paint()..color = glass,
  );
  canvas.drawCircle(const Offset(-4, 5.5), 1.8, Paint()..color = wheel);
  canvas.drawCircle(const Offset(5, 5.5), 1.8, Paint()..color = wheel);
  canvas.restore();
}

/// Pin con gradiente (del HTML).
void drawPin(Canvas canvas, Offset tip, double radius, Color c1, Color c2) {
  final head = tip - Offset(0, radius * 0.9);
  final circle = Path()..addOval(Rect.fromCircle(center: head, radius: radius));
  final tail = Path()
    ..moveTo(head.dx - radius * 0.66, head.dy + radius * 0.6)
    ..lineTo(tip.dx, tip.dy)
    ..lineTo(head.dx + radius * 0.66, head.dy + radius * 0.6)
    ..close();
  final pinPath = Path.combine(PathOperation.union, circle, tail);
  canvas.drawPath(
    pinPath,
    Paint()
      ..shader = LinearGradient(colors: [c1, c2])
          .createShader(Rect.fromCircle(center: head, radius: radius)),
  );
  canvas.drawCircle(
    head,
    radius * 0.36,
    Paint()..color = HtmlDesignTokens.white,
  );
  canvas.drawCircle(head, radius * 0.18, Paint()..color = c2);
}

/// Sparkle con color fijo.
void drawSparkle(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawCircle(
    center,
    radius * 2,
    Paint()..color = color.withValues(alpha: 0.2),
  );
  canvas.drawCircle(center, radius, Paint()..color = color);
  canvas.drawCircle(
    center,
    radius * 0.4,
    Paint()..color = HtmlDesignTokens.white.withValues(alpha: 0.8),
  );
}
