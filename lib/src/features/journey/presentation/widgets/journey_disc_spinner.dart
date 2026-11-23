import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';

/// Giro de carga que reemplaza la flecha del sentido mientras se pide el
/// recorrido. Va dentro del disco del chip, pintado con la tinta ya resuelta
/// (contrasta con el relleno del botón, tema claro u oscuro). La rotación la
/// mueve un [Ambient] —el kit de la casa—, así respeta «reducir animaciones»
/// (queda quieto) y acota sus vueltas bajo `flutter test` para que
/// `pumpAndSettle` converja; no es un `CircularProgressIndicator` (su ticker
/// eterno nunca converge).
class DiscSpinner extends StatelessWidget {
  const DiscSpinner({super.key, required this.color});

  final Color color;

  static const double _size = 14;

  @override
  Widget build(BuildContext context) {
    return Ambient(
      period: const Duration(milliseconds: 850),
      builder: (context, _, phase, _) => Transform.rotate(
        angle: phase * 2 * math.pi,
        child: CustomPaint(
          size: const Size.square(_size),
          painter: SpinnerArcPainter(color: color),
        ),
      ),
    );
  }
}

/// Dos arcos opuestos y redondeados: la silueta clásica de «cargando».
class SpinnerArcPainter extends CustomPainter {
  SpinnerArcPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.17;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    const sweep = math.pi * 0.62;
    canvas.drawArc(rect, 0, sweep, false, paint);
    canvas.drawArc(rect, math.pi, sweep, false, paint);
  }

  // La rotación la aplica el `Transform.rotate` del DiscSpinner; la geometría
  // del pintor es fija, así no hay que repintar por frame.
  @override
  bool shouldRepaint(SpinnerArcPainter oldDelegate) =>
      oldDelegate.color != color;
}
