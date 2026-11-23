import 'package:flutter/material.dart';

/// Indicador de ruta minimalista: dos puntos conectados por una línea vertical.
///
/// Reemplaza los pins verde/rojo con línea punteada por un diseño más limpio
/// que usa colores neutros del tema.
class RouteDotIndicator extends StatelessWidget {
  const RouteDotIndicator({
    super.key,
    required this.ink,
    required this.lineColor,
  });

  final Color ink;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(40, 40),
      painter: RouteDotPainter(ink: ink, lineColor: lineColor),
    );
  }
}

class RouteDotPainter extends CustomPainter {
  const RouteDotPainter({required this.ink, required this.lineColor});

  final Color ink;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * 0.5;
    final originY = size.height * 0.2;
    final destY = size.height * 0.8;
    const double dotRadius = 3.0;

    // Línea vertical conectora.
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x, originY + dotRadius),
      Offset(x, destY - dotRadius),
      linePaint,
    );

    // Punto de origen (relleno sólido).
    final dotPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, originY), dotRadius, dotPaint);

    // Punto de destino (anillo hueco para diferenciarlo).
    final ringPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(Offset(x, destY), dotRadius, ringPaint);
  }

  @override
  bool shouldRepaint(RouteDotPainter old) =>
      old.ink != ink || old.lineColor != lineColor;
}
