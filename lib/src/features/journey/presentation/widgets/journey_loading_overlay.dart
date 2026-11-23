import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Overlay de pantalla completa que aparece mientras el backend calcula el
/// viaje: reemplaza la tarjeta compacta del panel de estado para que la carga
/// se lea como una fase de la app, no como un recuadro gris sobre el mapa.
///
/// Reutiliza los mismos elementos visuales que `SplashGate` (anillos de Santa
/// Cruz, girófono, barra de progreso) pero adaptados al contexto del planeador:
/// fondo semitransparente para que el mapa siga visible, mensaje contextual y
/// tarjeta de cristal central.
class JourneyLoadingOverlay extends StatelessWidget {
  const JourneyLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Container(
      color: colors.surfaceDim.withValues(alpha: 0.45),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Anillos de Santa Cruz + girófono.
                const _SantaCruzRings(),
                const SizedBox(height: 24),
                // Mensaje de carga.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LiveDot(color: colors.secondary, size: 7),
                    const SizedBox(width: 10),
                    Text(
                      'Buscando conexiones…',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Subtítulo.
                Text(
                  'Calculando las mejores rutas',
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                // Barra de progreso animada.
                SizedBox(
                  width: 160,
                  height: 4,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.outlineVariant.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                      Ambient(
                        period: const Duration(milliseconds: 1400),
                        builder: (context, t, phase, child) => Align(
                          alignment: Alignment(-1 + 2 * phase, 0),
                          child: child,
                        ),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            gradient: LinearGradient(
                              colors: [
                                colors.secondary.withValues(alpha: 0),
                                colors.secondary,
                                colors.secondary.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Anillos concéntricos de Santa Cruz con un micro que circula, adaptados al
/// overlay de carga: más compactos que `HomeRouteLattice` y con tintes del
/// tema actual.
class _SantaCruzRings extends StatelessWidget {
  const _SantaCruzRings();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 140,
      height: 140,
      child: Ambient(
        period: const Duration(milliseconds: 4000),
        builder: (context, t, phase, _) => CustomPaint(
          painter: _RingsPainter(progress: phase, tint: colors.secondary),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.progress, required this.tint});

  final double progress;
  final Color tint;

  /// Radios relativos al lado mayor.
  static const List<double> _radii = [0.3, 0.45, 0.6, 0.75];

  /// Centro del lienzo.
  static const Offset _center = Offset(0.5, 0.5);

  /// Ángulo de inicio (izquierda).
  static const double _startAngle = math.pi * 0.75;

  /// Recorrido del arco (270°).
  static const double _sweepAngle = math.pi * 1.5;

  /// Anillo por el que circula el micro.
  static const int _lane = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final side = size.longestSide;
    final center = Offset(size.width * _center.dx, size.height * _center.dy);

    // 1 · Anillos concéntricos.
    for (var r = 0; r < _radii.length; r++) {
      final radius = _radii[r] * side;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final isLane = r == _lane;
      canvas.drawArc(
        rect,
        _startAngle,
        _sweepAngle,
        false,
        Paint()
          ..color = tint.withValues(alpha: isLane ? 0.4 : 0.2)
          ..strokeWidth = isLane ? 3.0 : 2.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );

      // Paradas marcadas en el anillo.
      final stops = 4 + r;
      for (var s = 0; s <= stops; s++) {
        final angle = _startAngle + _sweepAngle * (s / stops);
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        canvas.drawCircle(
          point,
          isLane && s.isEven ? 3.0 : 2.0,
          Paint()
            ..color = tint.withValues(alpha: (isLane && s.isEven) ? 0.6 : 0.3),
        );
      }
    }

    // 2 · El micro: recorre el anillo del corredor.
    final laneRadius = _radii[_lane] * side;
    final travel = _startAngle + _sweepAngle * progress;
    final unit =
        center + Offset(math.cos(travel), math.sin(travel)) * laneRadius;

    // Estela del micro.
    for (var k = 5; k >= 1; k--) {
      final trailAngle = travel - k * 0.06;
      final trail =
          center +
          Offset(math.cos(trailAngle), math.sin(trailAngle)) * laneRadius;
      canvas.drawCircle(
        trail,
        2.4 - k * 0.25,
        Paint()..color = tint.withValues(alpha: 0.35 * (1 - k / 6)),
      );
    }

    // Cuerpo del micro.
    canvas.save();
    canvas.translate(unit.dx, unit.dy);
    canvas.rotate(math.atan2(math.cos(travel), -math.sin(travel)));
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 14, height: 7),
      const Radius.circular(2.4),
    );
    canvas.drawRRect(body, Paint()..color = tint.withValues(alpha: 0.3));
    canvas.drawRRect(
      body,
      Paint()
        ..color = tint.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // Faro al frente.
    canvas.drawCircle(
      const Offset(5, 0),
      1.0,
      Paint()..color = tint.withValues(alpha: 0.95),
    );
    canvas.restore();

    // 3 · Girófono central (dial rotatorio).
    _drawDial(canvas, center, side * 0.12, tint, progress);
  }

  void _drawDial(
    Canvas canvas,
    Offset center,
    double radius,
    Color tint,
    double progress,
  ) {
    // Fondo del girófono.
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = tint.withValues(alpha: 0.08),
    );

    // Arco de progreso.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = tint.withValues(alpha: 0.7)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Punto luminoso en el extremo del arco.
    final angle = -math.pi / 2 + math.pi * 2 * progress;
    final dot = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(dot, 3.0, Paint()..color = tint);
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.progress != progress || old.tint != tint;
}
