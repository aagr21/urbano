import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';

/// Fondo del header: **los anillos de Santa Cruz pintados**, con un micro que
/// circula por uno de ellos.
///
/// La ciudad se entiende por anillos y avenidas radiales, así que la textura de
/// marca no es un degradado con manchas brillantes (el disfoto típico de una UI
/// generada): son arcos concéntricos con paradas y una unidad que recorre su
/// corredor. Se dibuja con un solo [CustomPainter] y [Ambient], sin imágenes ni
/// blur, y el recorrido es continuo: el header es lo primero que se mira y tiene
/// que verse rodando.
///
/// Todo se pinta en blancos translúcidos: la cabecera es un degradado saturado y
/// sobre fondo oscuro solo van trazos claros.
class HomeRouteLattice extends StatelessWidget {
  const HomeRouteLattice({super.key, this.tint = Colors.white});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Ambient(
        period: const Duration(milliseconds: 2200),
        builder: (context, t, phase, _) => CustomPaint(
          // Vueltas seguidas: la unidad rueda por su corredor mientras la
          // pantalla esté en pantalla.
          painter: _RingLatticePainter(progress: phase, tint: tint),
        ),
      ),
    );
  }
}

class _RingLatticePainter extends CustomPainter {
  const _RingLatticePainter({required this.progress, required this.tint});

  /// 0..1 del recorrido de la unidad (una vuelta continua).
  final double progress;
  final Color tint;

  /// El centro de los anillos queda fuera del lienzo, abajo a la derecha: así
  /// los arcos entran por el borde izquierdo y suben hacia la esquina superior,
  /// que es como se leen los anillos desde el norte de la ciudad.
  static const Offset _center = Offset(1.16, 1.02);

  /// Radios relativos al lado mayor del lienzo.
  static const List<double> _radii = [0.46, 0.66, 0.9, 1.18];

  static const double _startAngle = math.pi;
  static const double _sweepAngle = math.pi / 2;

  /// El corredor por el que rueda la unidad.
  static const int _lane = 1;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final side = size.longestSide;
    final center = Offset(size.width * _center.dx, size.height * _center.dy);

    // 1 · Avenidas radiales: trama muy tenue para que el fondo se lea mapa.
    final avenues = Paint()
      ..color = tint.withValues(alpha: 0.07)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 5; i++) {
      final angle = _startAngle + _sweepAngle * (0.08 + 0.22 * i);
      final outer = _radii.last * side;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * outer * 0.34,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        avenues,
      );
    }

    // 2 · Anillos: línea de ruta gruesa, con paradas marcadas.
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
          ..color = tint.withValues(alpha: isLane ? 0.3 : 0.15)
          ..strokeWidth = isLane ? 3.4 : 2.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );

      final stops = 3 + r;
      for (var s = 0; s <= stops; s++) {
        final angle = _startAngle + _sweepAngle * (s / stops);
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        final transfer = isLane && s.isEven;
        canvas.drawCircle(
          point,
          transfer ? 3.4 : 2.4,
          Paint()..color = tint.withValues(alpha: transfer ? 0.5 : 0.28),
        );
        if (transfer) {
          // Parada de transbordo: anillo hueco, como en un diagrama de metro.
          canvas.drawCircle(
            point,
            3.4,
            Paint()
              ..color = tint.withValues(alpha: 0.65)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
      }
    }

    // 3 · La unidad: recorre su corredor de un borde al otro y sale del lienzo,
    //    así que en reposo (progress = 1) no queda nada flotando en pantalla.
    final laneRadius = _radii[_lane] * side;
    final travel = _startAngle - 0.14 + (_sweepAngle + 0.36) * progress;
    final unit =
        center + Offset(math.cos(travel), math.sin(travel)) * laneRadius;

    // Estela: las muestras previas se adelgazan hacia atrás, como un rastro de
    // velocidad en un diagrama de flujo.
    for (var k = 6; k >= 1; k--) {
      final trailAngle = travel - k * 0.055;
      final trail =
          center +
          Offset(math.cos(trailAngle), math.sin(trailAngle)) * laneRadius;
      canvas.drawCircle(
        trail,
        2.6 - k * 0.3,
        Paint()..color = tint.withValues(alpha: 0.3 * (1 - k / 7)),
      );
    }

    canvas.save();
    canvas.translate(unit.dx, unit.dy);
    // Tangente a la circunferencia: derivada de (cos θ, sin θ).
    canvas.rotate(math.atan2(math.cos(travel), -math.sin(travel)));
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 15, height: 7.4),
      const Radius.circular(2.6),
    );
    // Cápsula translúcida con contorno luminoso y faro al frente: todo claro
    // sobre el degradado oscuro, y a 15 px una cápsula rayada se lee micro.
    canvas.drawRRect(body, Paint()..color = tint.withValues(alpha: 0.2));
    canvas.drawRRect(
      body,
      Paint()
        ..color = tint.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.drawCircle(
      const Offset(5.6, 0),
      1.1,
      Paint()..color = tint.withValues(alpha: 0.95),
    );
    canvas.drawLine(
      const Offset(-4.5, 0),
      const Offset(-0.5, 0),
      Paint()
        ..color = tint.withValues(alpha: 0.5)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingLatticePainter old) =>
      old.progress != progress || old.tint != tint;
}
