// Wordmark «Urbano» de la cabecera: Fredoka + el trazo de ruta animado.

import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/extensions.dart';

/// **Wordmark de la portada**: «Urbano» como un recorrido.
///
/// Tres capas que cuentan la marca sin decir nada:
///  * las letras en Fredoka con un degradado de verde profundo a esmeralda
///    (en oscuro, de la tinta del tema a menta), en vez de un color plano;
///  * debajo, el **trazo del recorrido**: una línea que nace bajo la «U», se
///    dibuja una sola vez al llegar (`Ambient(cycles: 1)`, reposa trazada) y
///    termina en el punto final;
///  * ese punto es la **parada**: un aro con centro de la superficie y halo,
///    el destino de la línea.
///
/// El texto sigue siendo un `Text('Urbano')` (los tests lo buscan así): el
/// degradado lo pone un `ShaderMask`, no una imagen.
class HomeWordmark extends StatelessWidget {
  const HomeWordmark({super.key});

  static const double _fontSize = 34;
  static const double _stop = 9;

  /// Alto de la caja del trazo (la curva oscila ±2 px dentro de ella).
  static const double _stroke = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final inkTop = dark ? colors.onSurface : HtmlDesignTokens.darkWordmark;
    final inkBottom = dark
        ? HtmlDesignTokens.emerald300
        : HtmlDesignTokens.emerald600;
    final route = dark
        ? HtmlDesignTokens.emerald400
        : HtmlDesignTokens.emerald500;

    final word = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [inkTop, inkTop, inkBottom],
        stops: const [0, 0.35, 1],
      ).createShader(bounds),
      child: Text(
        Env.appName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.wordmark(
          text.headlineMedium?.copyWith(
            // El color real lo pone el degradado; este solo da opacidad.
            color: inkTop,
            fontSize: _fontSize,
            height: 1,
            letterSpacing: -0.6,
          ),
        ),
      ),
    );

    return Ambient(
      cycles: 1,
      period: const Duration(milliseconds: 1400),
      child: word,
      builder: (context, t, _, child) {
        final draw = Curves.easeInOutCubic.transform(t);
        // La parada «llega» cuando el trazo la alcanza.
        final stopIn = Curves.easeOutBack.transform(
          ((t - 0.7) / 0.3).clamp(0.0, 1.0),
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // El trazo corre sobre la línea base y termina en el centro de la
            // parada. Vive fuera del layout: no empuja el lema.
            Positioned(
              left: 2,
              right: _stop / 2,
              bottom: -_stroke / 2,
              height: _stroke,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: WordmarkRouteStrokePainter(
                    progress: draw,
                    from: route.withValues(alpha: 0.12),
                    to: route,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: child!),
                const SizedBox(width: 3),
                // Centro de la parada en la línea base, igual que el trazo.
                Transform.translate(
                  offset: const Offset(0, _stop / 2),
                  child: Transform.scale(
                    scale: stopIn,
                    child: WordmarkStopDot(color: route, size: _stop),
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

/// Parada al final del trazo: aro del color de la ruta, centro de la
/// superficie (se lee igual en claro y oscuro) y un halo suave.
class WordmarkStopDot extends StatelessWidget {
  const WordmarkStopDot({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Trazo del recorrido bajo el wordmark: una curva suave (sube apenas y
/// vuelve) que se dibuja de izquierda a derecha hasta [progress] y se aclara
/// hacia su origen, como una línea que viene de lejos.
class WordmarkRouteStrokePainter extends CustomPainter {
  const WordmarkRouteStrokePainter({
    required this.progress,
    required this.from,
    required this.to,
  });

  final double progress;
  final Color from;
  final Color to;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.width <= 0) return;
    final y = size.height / 2;
    final path = Path()
      ..moveTo(0, y)
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
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: [from, to])
          .createShader(Offset.zero & size);
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(WordmarkRouteStrokePainter old) =>
      old.progress != progress || old.from != from || old.to != to;
}
