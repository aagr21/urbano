// Wordmark «Urbano» de la cabecera: Plus Jakarta Sans + el recorrido al pin.

import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/extensions.dart';

/// **Wordmark de la portada**: «Urbano» como un viaje, con el mismo dibujo que
/// el ícono de la app (`tools/app_icon.py`): sale de una parada y llega a un
/// pin coral.
///
/// Tres capas:
///  * las letras en Plus Jakarta Sans ExtraBold, de un solo color plano (verde
///    profundo en claro, la tinta del tema en oscuro) — nunca partidas en
///    colores;
///  * debajo, el **recorrido**: nace en un aro hueco bajo la «U» (la parada
///    donde se sube) y se dibuja una sola vez al llegar (`Ambient(cycles: 1)`,
///    reposa trazado) hasta la punta del pin;
///  * el **pin coral** del destino, que cae con un rebote cuando el trazo lo
///    alcanza. Es el único acento cálido de la cabecera, a propósito.
///
/// El texto es un `Text('Urbano')` (los tests lo buscan así). Trazo, parada y pin viven
/// fuera del layout: la cabecera mide lo mismo que con el wordmark anterior.
class HomeWordmark extends StatelessWidget {
  const HomeWordmark({super.key});

  static const double _fontSize = 34;

  /// Caja del pin: gota de radio 5,5 con la punta 1,6 radios bajo el centro.
  static const Size _pin = Size(13, 16);

  /// Alto de la caja del trazo (la curva oscila ±2 px dentro de ella).
  static const double _stroke = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // UN solo color en toda la palabra (verde profundo en claro, la tinta del
    // tema en oscuro): partirla en colores resalta una sílaba de «Urbano».
    final ink = dark ? colors.onSurface : AppColors.primaryDark;
    final route = dark ? HtmlDesignTokens.teal300 : HtmlDesignTokens.teal600;

    final word = Text(
      Env.appName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.wordmark(
        text.headlineMedium?.copyWith(
          color: ink,
          fontSize: _fontSize,
          height: 1,
        ),
      ),
    );

    return Ambient(
      cycles: 1,
      period: const Duration(milliseconds: 1500),
      child: word,
      builder: (context, t, _, child) {
        final draw = Curves.easeInOutCubic.transform(
          (t / 0.75).clamp(0.0, 1.0),
        );
        // El pin «llega» cuando el trazo lo alcanza: cae desde arriba con rebote.
        final land = ((t - 0.62) / 0.38).clamp(0.0, 1.0);
        final pinScale = Curves.easeOutBack.transform(land);
        final pinDrop = (1 - Curves.easeOutCubic.transform(land)) * -10;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Recorrido sobre la línea base, de la parada a la punta del pin.
            Positioned(
              left: 0,
              right: _pin.width / 2,
              bottom: -_stroke / 2,
              height: _stroke,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: WordmarkRouteStrokePainter(
                    progress: draw,
                    from: route.withValues(alpha: 0.35),
                    to: route,
                    origin: route,
                    originFill: colors.surface,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: child!),
                const SizedBox(width: 2),
                // La punta del pin toca la línea base, donde termina el trazo.
                Opacity(
                  opacity: land == 0 ? 0 : 1,
                  child: Transform.translate(
                    offset: Offset(0, pinDrop),
                    child: Transform.scale(
                      scale: pinScale,
                      alignment: Alignment.bottomCenter,
                      child: const WordmarkPin(size: _pin),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Pin coral del destino: la misma gota del ícono de la app, con borde claro y
/// ojo blanco. Decorativo (el wordmark ya se lee como «Urbano»).
class WordmarkPin extends StatelessWidget {
  const WordmarkPin({super.key, required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: size, painter: const _PinPainter()),
  );
}

class _PinPainter extends CustomPainter {
  const _PinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Gota: círculo de radio r arriba y punta 1,6 r bajo su centro, abajo del
    // todo (mismas proporciones que `PIN_PATH` en tools/app_icon.py).
    final r = size.height / 2.6;
    final cx = size.width / 2;
    final cy = r;
    final tip = size.height;
    final path = Path()
      ..moveTo(cx, tip)
      ..cubicTo(cx - r * 0.3, cy + r * 1.15, cx - r, cy + r * 0.6, cx - r, cy)
      ..arcToPoint(Offset(cx + r, cy), radius: Radius.circular(r))
      ..cubicTo(cx + r, cy + r * 0.6, cx + r * 0.3, cy + r * 1.15, cx, tip)
      ..close();

    canvas.drawShadow(path, AppColors.accent, 3, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF7A55), AppColors.accent],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(Offset(cx, cy), r * 0.42, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) => false;
}

/// Recorrido bajo el wordmark: una curva suave (sube apenas y vuelve) que se
/// dibuja de izquierda a derecha hasta [progress], se aclara hacia su origen y
/// arranca en una parada —un aro hueco ([origin] con centro [originFill]),
/// como en un diagrama de metro—.
class WordmarkRouteStrokePainter extends CustomPainter {
  const WordmarkRouteStrokePainter({
    required this.progress,
    required this.from,
    required this.to,
    this.origin,
    this.originFill,
  });

  final double progress;
  final Color from;
  final Color to;

  /// Aro de la parada de origen; `null` = sin parada.
  final Color? origin;
  final Color? originFill;

  static const double _originRadius = 3.2;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.width <= 0) return;
    final y = size.height / 2;
    final start = origin == null ? 0.0 : _originRadius + 1;
    final path = Path()
      ..moveTo(start, y)
      ..cubicTo(
        size.width * 0.3,
        y + 2.2,
        size.width * 0.65,
        y - 2.2,
        size.width,
        y,
      );
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [from, to])
            .createShader(Offset.zero & size),
    );

    final ring = origin;
    if (ring != null) {
      final center = Offset(start, y);
      canvas.drawCircle(
        center,
        _originRadius,
        Paint()..color = originFill ?? Colors.transparent,
      );
      canvas.drawCircle(
        center,
        _originRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ring,
      );
    }
  }

  @override
  bool shouldRepaint(WordmarkRouteStrokePainter old) =>
      old.progress != progress ||
      old.from != from ||
      old.to != to ||
      old.origin != origin ||
      old.originFill != originFill;
}
