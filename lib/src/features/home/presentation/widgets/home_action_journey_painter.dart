import 'package:flutter/painting.dart';

import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import 'home_action_painter_helpers.dart';

/// Pintor de la ruta de viaje — colores fijos del SVG de inicio.html.
class HomeActionJourneyPainter {
  const HomeActionJourneyPainter();

  void paint(Canvas canvas) {
    // Colores fijos del SVG
    const route1 = HtmlDesignTokens.emerald500;
    const route2 = HtmlDesignTokens.amber500;
    const route3 = HtmlDesignTokens.blue600;
    const pinA1 = HtmlDesignTokens.emerald500;
    const pinA2 = HtmlDesignTokens.emerald700;
    const pinB1 = HtmlDesignTokens.cyan500;
    const pinB2 = HtmlDesignTokens.cyan700;
    const waypoint = HtmlDesignTokens.amber500;
    const waypointBg = Color(0xFFFEF3C7);
    const miniBusBody = HtmlDesignTokens.emerald700;
    const miniBusGlass = HtmlDesignTokens.blue100;
    const miniBusWheel = HtmlDesignTokens.slate800;
    const originBg = HtmlDesignTokens.emerald50;
    const destShadow = HtmlDesignTokens.cyan700;

    final path = Path()
      ..moveTo(18, 56)
      ..quadraticBezierTo(35, 56, 42, 36)
      ..quadraticBezierTo(56, 16, 72, 18)
      ..quadraticBezierTo(82, 19, 92, 18);

    // Ruta con gradiente tricolor
    drawDashed(
      canvas,
      path,
      Paint()
        ..shader = const LinearGradient(colors: [route1, route2, route3])
            .createShader(const Rect.fromLTWH(10, 10, 90, 50))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Línea punteada blanca sobre la ruta
    drawDashed(
      canvas,
      path,
      Paint()
        ..color = HtmlDesignTokens.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // Origen: pin verde
    canvas.drawCircle(const Offset(18, 56), 8, Paint()..color = originBg);
    canvas.drawCircle(
      const Offset(18, 56),
      5,
      Paint()
        ..shader = const LinearGradient(colors: [pinA1, pinA2])
            .createShader(const Rect.fromLTWH(13, 51, 10, 10)),
    );
    canvas.drawCircle(
      const Offset(18, 56),
      2,
      Paint()..color = HtmlDesignTokens.white,
    );

    // Waypoint intermedio
    canvas.drawCircle(const Offset(56, 30), 7, Paint()..color = waypointBg);
    canvas.drawCircle(const Offset(56, 30), 4.5, Paint()..color = waypoint);
    canvas.drawCircle(
      const Offset(56, 30),
      1.8,
      Paint()..color = HtmlDesignTokens.white,
    );

    // Mini micro sobre la ruta
    drawMiniBus(
      canvas,
      const Offset(52, 14),
      miniBusBody,
      miniBusGlass,
      miniBusWheel,
    );

    // Destino: pin cian con sombra
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(106, 34), width: 12, height: 5),
      Paint()..color = destShadow.withValues(alpha: 0.25),
    );
    drawPin(canvas, const Offset(106, 22), 12, pinB1, pinB2);

    // Decorative sparkles
    drawSparkle(canvas, const Offset(20, 18), 2, route1);
    drawSparkle(canvas, const Offset(100, 58), 1.5, route3);
  }
}
