import 'package:flutter/painting.dart';

import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;

/// Pintor del megáfono de denuncias — colores fijos del SVG de inicio.html.
class HomeActionComplaintsPainter {
  const HomeActionComplaintsPainter();

  void paint(Canvas canvas) {
    // Colores fijos del SVG
    const horn1 = HtmlDesignTokens.teal600;
    const horn2 = HtmlDesignTokens.teal700;
    const horn3 = HtmlDesignTokens.teal800;
    const bell1 = HtmlDesignTokens.orangeA700;
    const bell2 = HtmlDesignTokens.orange400;
    const bell3 = HtmlDesignTokens.orange700;
    const handle1 = HtmlDesignTokens.amber300;
    const handle2 = HtmlDesignTokens.amber500;
    const handleGrip = Color(0xFFD97706);
    const backCap = HtmlDesignTokens.emerald950;
    const glare = Color(0x38FFFFFF);
    const wave1 = HtmlDesignTokens.orange400;
    const wave2 = HtmlDesignTokens.emerald500;
    const wave3 = HtmlDesignTokens.sky500;
    const sparkle1 = HtmlDesignTokens.amber400;
    const sparkle2 = HtmlDesignTokens.rose500;
    const sparkle3 = HtmlDesignTokens.emerald500;
    const groundShadow = Color(0xFF042F24);
    const bellStroke = HtmlDesignTokens.amber200Light;

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(54, 74), width: 60, height: 8),
      Paint()..color = groundShadow.withValues(alpha: 0.1),
    );

    // Handle with gradient
    final handlePath = Path()
      ..moveTo(37, 48)
      ..lineTo(33, 63)
      ..quadraticBezierTo(32, 66, 38, 68)
      ..lineTo(41, 65)
      ..lineTo(45, 46)
      ..close();
    canvas.drawPath(
      handlePath,
      Paint()
        ..shader = const LinearGradient(colors: [handle1, handle2])
            .createShader(const Rect.fromLTWH(32, 46, 14, 24)),
    );
    // Handle grip base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(33, 62, 7, 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = handleGrip,
    );

    // Back cap
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(32, 38), width: 10, height: 18),
      Paint()..color = backCap,
    );

    // Main cone with gradient
    final cone = Path()
      ..moveTo(32, 29)
      ..lineTo(62, 20)
      ..lineTo(62, 56)
      ..lineTo(32, 45)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(colors: [horn1, horn2, horn3])
            .createShader(const Rect.fromLTWH(32, 20, 30, 36)),
    );

    // Specular highlight on cone
    final gleam = Path()
      ..moveTo(34, 31)
      ..lineTo(60, 23)
      ..lineTo(60, 30)
      ..lineTo(34, 38)
      ..close();
    canvas.drawPath(gleam, Paint()..color = glare);

    // Front bell flare with gradient
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(63, 38), width: 10, height: 36),
      Paint()
        ..shader = const LinearGradient(colors: [bell1, bell2, bell3])
            .createShader(const Rect.fromLTWH(58, 20, 10, 36)),
    );
    // Bell stroke highlight
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(63, 38), width: 10, height: 36),
      Paint()
        ..color = bellStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Sound waves - 3 colors from HTML
    final waveColors = [wave1, wave2, wave3];
    for (int i = 0; i < 3; i++) {
      final radius = 20.0 + i * 9.0;
      final color = waveColors[i];
      // Glow
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(68, 38), radius: radius),
        -0.55,
        1.1,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 - i * 0.8
          ..strokeCap = StrokeCap.round,
      );
      // Wave
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(68, 38), radius: radius),
        -0.55,
        1.1,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 - i * 0.4
          ..strokeCap = StrokeCap.round,
      );
    }

    // Energetic sparkles
    canvas.drawCircle(const Offset(86, 16), 2, Paint()..color = sparkle1);
    canvas.drawCircle(const Offset(104, 38), 1.5, Paint()..color = sparkle2);
    canvas.drawCircle(const Offset(78, 60), 1.8, Paint()..color = sparkle3);
  }
}
