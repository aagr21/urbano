import 'package:flutter/painting.dart';

import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;

/// Pintor del micro de perfil — colores fijos del SVG de inicio.html.
class HomeActionMicrosPainter {
  const HomeActionMicrosPainter();

  void paint(Canvas canvas) {
    // Colores fijos del SVG de inicio.html
    const busBody1 = HtmlDesignTokens.microBodyStart;
    const busBody2 = HtmlDesignTokens.microBodyMid;
    const busBody3 = HtmlDesignTokens.microBodyEnd;
    const busRoof1 = HtmlDesignTokens.white;
    const busRoof2 = HtmlDesignTokens.slate200;
    const glass1 = HtmlDesignTokens.blue50;
    const glass2 = HtmlDesignTokens.blue200;
    const glassBg = HtmlDesignTokens.blue900;
    const stripe1 = HtmlDesignTokens.orangeA700;
    const stripe2 = HtmlDesignTokens.amberA500;
    const speed1 = HtmlDesignTokens.amber200Light;
    const speed2 = HtmlDesignTokens.amber300Light;
    const shadow = Color(0xFF042F24);
    const headlight = HtmlDesignTokens.amber200;
    const taillight = HtmlDesignTokens.red500;
    const tire = HtmlDesignTokens.slate800;
    const rim = HtmlDesignTokens.slate500;
    const hub = HtmlDesignTokens.slate50;
    const displayBg = HtmlDesignTokens.blackSoft;
    const displayDot = HtmlDesignTokens.green400;
    const acVent = HtmlDesignTokens.slate300;
    const glare = Color(0x73FFFFFF);

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(62, 76), width: 90, height: 9),
      Paint()..color = shadow.withValues(alpha: 0.18),
    );

    // Velocity lines (warm tones from HTML)
    final v1 = Paint()
      ..color = speed1
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final v2 = Paint()
      ..color = speed2
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final v3 = Paint()
      ..color = speed1
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, 30), const Offset(14, 30), v1);
    canvas.drawLine(const Offset(2, 41), const Offset(10, 41), v2);
    canvas.drawLine(const Offset(6, 50), const Offset(15, 50), v3);

    // Main bus body gradient
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 16, 80, 42),
        const Radius.circular(12),
      ),
      Paint()
        ..shader = const LinearGradient(colors: [busBody1, busBody2, busBody3])
            .createShader(const Rect.fromLTWH(18, 16, 80, 42)),
    );

    // Bus top cap / AC unit
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(35, 12, 40, 5),
        const Radius.circular(2.5),
      ),
      Paint()
        ..shader = const LinearGradient(colors: [busRoof1, busRoof2])
            .createShader(const Rect.fromLTWH(35, 12, 40, 5)),
    );
    // AC vents
    final vent = Paint()..color = acVent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(42, 13, 7, 3),
        const Radius.circular(1.5),
      ),
      vent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(52, 13, 7, 3),
        const Radius.circular(1.5),
      ),
      vent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(62, 13, 7, 3),
        const Radius.circular(1.5),
      ),
      vent,
    );

    // Vibrant racing accent stripe
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18, 45, 80, 5), Radius.zero),
      Paint()
        ..shader = const LinearGradient(colors: [stripe1, stripe2])
            .createShader(const Rect.fromLTWH(18, 45, 80, 5)),
    );

    // Window section background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 22, 70, 17),
        const Radius.circular(5),
      ),
      Paint()..color = glassBg,
    );

    // Glass panes with gradient
    final glassShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [glass1, glass2],
    ).createShader(const Rect.fromLTWH(22, 22, 70, 17));
    final glassPaint = Paint()..shader = glassShader;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 23, 13, 15),
        const Radius.circular(3.5),
      ),
      glassPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 23, 15, 15),
        const Radius.circular(3.5),
      ),
      glassPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(58, 23, 15, 15),
        const Radius.circular(3.5),
      ),
      glassPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(76, 23, 16, 15),
        const Radius.circular(3.5),
      ),
      glassPaint,
    );

    // Glass glare sheen
    final glarePaint = Paint()..color = glare;
    final glare1 = Path()
      ..moveTo(25, 24)
      ..lineTo(32, 24)
      ..lineTo(26, 37)
      ..lineTo(20, 37)
      ..close();
    canvas.drawPath(glare1, glarePaint);
    final glare2 = Path()
      ..moveTo(41, 24)
      ..lineTo(48, 24)
      ..lineTo(42, 37)
      ..lineTo(36, 37)
      ..close();
    canvas.drawPath(glare2, glarePaint);

    // Route indicator display
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(42, 17.5, 26, 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = displayBg,
    );
    final dotPaint = Paint()..color = displayDot;
    for (final x in const [46.0, 49.0, 52.0, 55.0, 58.0]) {
      canvas.drawCircle(Offset(x, 19), 0.75, dotPaint);
    }

    // Headlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(94, 52, 4, 4),
        const Radius.circular(1.5),
      ),
      Paint()..color = headlight,
    );

    // Tail light
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 52, 3, 4),
        const Radius.circular(1),
      ),
      Paint()..color = taillight,
    );

    // Wheels
    _wheel(canvas, const Offset(38, 66), 9, tire, rim, hub);
    _wheel(canvas, const Offset(80, 66), 9, tire, rim, hub);
  }

  void _wheel(
    Canvas canvas,
    Offset center,
    double radius,
    Color tire,
    Color rim,
    Color hub,
  ) {
    canvas.drawCircle(center, radius, Paint()..color = tire);
    canvas.drawCircle(center, radius * 0.61, Paint()..color = rim);
    canvas.drawCircle(center, radius * 0.28, Paint()..color = hub);
  }
}
