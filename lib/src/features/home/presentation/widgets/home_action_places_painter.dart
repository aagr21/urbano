import 'package:flutter/painting.dart';

import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import 'home_action_painter_helpers.dart';

/// Pintor del radar con pin — colores fijos del SVG de inicio.html.
class HomeActionPlacesPainter {
  const HomeActionPlacesPainter();

  void paint(Canvas canvas) {
    // Colores fijos del SVG
    const radarBg1 = HtmlDesignTokens.emerald50Light;
    const radarBg2 = HtmlDesignTokens.emerald100mid;
    const radarStroke = HtmlDesignTokens.emerald200;
    const radarWave = HtmlDesignTokens.emerald500;
    const center1 = HtmlDesignTokens.emerald500;
    const center2 = HtmlDesignTokens.emerald800;
    const stopPole = HtmlDesignTokens.emerald700;
    const stopSign = HtmlDesignTokens.teal700;
    const stopInner = HtmlDesignTokens.white;
    const pinOrange = HtmlDesignTokens.orange400;
    const pinShadow = HtmlDesignTokens.emerald800;
    const groundShadow = Color(0xFF042F24);

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(62, 76), width: 84, height: 12),
      Paint()..color = groundShadow.withValues(alpha: 0.12),
    );

    // Radar base plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 20, 80, 38),
        const Radius.circular(14),
      ),
      Paint()
        ..shader = const LinearGradient(colors: [radarBg1, radarBg2])
            .createShader(const Rect.fromLTWH(22, 20, 80, 38)),
    );
    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 20, 80, 38),
        const Radius.circular(14),
      ),
      Paint()
        ..color = radarStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Concentric radar waves
    canvas.drawCircle(
      const Offset(62, 39),
      24,
      Paint()
        ..color = radarWave.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Dashed outer ring
    drawDashed(
      canvas,
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(62, 39), radius: 24)),
      Paint()
        ..color = radarWave.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(
      const Offset(62, 39),
      16,
      Paint()
        ..color = radarWave.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    canvas.drawCircle(
      const Offset(62, 39),
      9,
      Paint()..color = radarStroke.withValues(alpha: 0.5),
    );

    // Center hub marker
    canvas.drawCircle(
      const Offset(62, 39),
      6.5,
      Paint()
        ..shader = const LinearGradient(colors: [center1, center2])
            .createShader(const Rect.fromLTWH(55.5, 32.5, 13, 13)),
    );
    canvas.drawCircle(
      const Offset(62, 39),
      2.5,
      Paint()..color = HtmlDesignTokens.white,
    );

    // Bus stop totem at left
    canvas.save();
    canvas.translate(28, 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 3, 24),
        const Radius.circular(1.5),
      ),
      Paint()..color = stopPole,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, 1, 9, 9),
        const Radius.circular(2),
      ),
      Paint()..color = stopSign,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1.5, 2.5, 6, 6),
        const Radius.circular(1.2),
      ),
      Paint()..color = stopInner,
    );
    // Mini bus glyph
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-0.5, 4, 4, 3.5),
        const Radius.circular(0.5),
      ),
      Paint()..color = stopSign,
    );
    canvas.restore();

    // Floating map marker pin at top right
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(88, 42), width: 8, height: 3),
      Paint()..color = pinShadow.withValues(alpha: 0.2),
    );
    drawPin(
      canvas,
      const Offset(88, 30),
      7,
      pinOrange,
      HtmlDesignTokens.orange700,
    );

    // Decorative sparkles
    drawSparkle(canvas, const Offset(24, 16), 1.5, center1);
    drawSparkle(canvas, const Offset(100, 22), 1.8, center2);
  }
}
