import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';

/// Micro ilustrado de perfil, pintado con el color GTFS de su línea.
///
/// El catálogo necesita una imagen por línea, no un ícono genérico repetido:
/// el bus hereda el color real del feed ([color]) y las ventanas se invierten
/// solas con [AppColors.onColor] para que una línea clara (`F1C40F`) y una
/// oscura (`2C3E50`) se lean igual de bien. Todo es `CustomPaint`: no hay
/// assets ni red, así la lista scrollea sin decodificar imágenes.
class MicroBusArt extends StatelessWidget {
  const MicroBusArt({
    super.key,
    required this.color,
    this.size = const Size(56, 38),
  });

  /// Color GTFS de la línea (sin `#`).
  final Color color;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        painter: _MicroBusPainter(
          body: color,
          glass: AppColors.onColor(color),
          sign: AppColors.accent,
          wheel: Color.lerp(color, AppColors.ink, 0.78)!,
          warm: AppColors.accent,
        ),
      ),
    );
  }
}

class _MicroBusPainter extends CustomPainter {
  const _MicroBusPainter({
    required this.body,
    required this.glass,
    required this.sign,
    required this.wheel,
    required this.warm,
  });

  final Color body;

  /// Cristales: negro o blanco según el brillo de la carrocería.
  final Color glass;
  final Color sign;
  final Color wheel;
  final Color warm;

  /// Lienzo de diseño; se escala conservando la proporción.
  static const Size _design = Size(64, 44);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / _design.width,
      size.height / _design.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - _design.width * scale) / 2,
      (size.height - _design.height * scale) / 2,
    );
    canvas.scale(scale, scale);

    // Sombra de apoyo: asienta el bus en la placa sin dibujar un piso duro.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(32, 39), width: 52, height: 7),
      Paint()..color = wheel.withValues(alpha: 0.16),
    );

    // Carrocería.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 10, 58, 23),
        const Radius.circular(7),
      ),
      Paint()..color = body,
    );

    // Banda de ventanas, partida por montantes del color del cuerpo.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 14, 38, 10),
        const Radius.circular(3),
      ),
      Paint()..color = glass.withValues(alpha: 0.9),
    );
    final mullion = Paint()
      ..color = body
      ..strokeWidth = 1.8;
    for (final x in const [17.0, 26.0, 35.0]) {
      canvas.drawLine(Offset(x, 15), Offset(x, 24), mullion);
    }

    // Parabrisas y puerta.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(48, 14, 9, 10),
        const Radius.circular(2),
      ),
      Paint()..color = glass,
    );
    canvas.drawLine(
      const Offset(44, 15),
      const Offset(44, 24),
      Paint()
        ..color = glass.withValues(alpha: 0.6)
        ..strokeWidth = 1.6,
    );

    // Cartel de destino y franja del faldón.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 11.5, 16, 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = sign,
    );
    canvas.drawRect(
      const Rect.fromLTWH(4, 29, 56, 3),
      Paint()..color = wheel.withValues(alpha: 0.18),
    );

    // Ruedas.
    for (final x in const [16.0, 48.0]) {
      canvas.drawCircle(Offset(x, 33), 5.4, Paint()..color = wheel);
      canvas.drawCircle(
        Offset(x, 33),
        2.1,
        Paint()..color = glass.withValues(alpha: 0.85),
      );
      canvas.drawCircle(Offset(x, 33), 1, Paint()..color = body);
    }

    // Faro.
    canvas.drawCircle(const Offset(60, 28), 2.2, Paint()..color = warm);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MicroBusPainter old) =>
      old.body != body ||
      old.glass != glass ||
      old.sign != sign ||
      old.wheel != wheel ||
      old.warm != warm;
}
