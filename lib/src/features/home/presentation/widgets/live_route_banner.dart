import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Banner vivo del home: un micro recorre su corredor mientras la pantalla
/// está visible. Reemplaza al bloque estático de «el servicio hoy»: no depende
/// del backend y mantiene la portada en movimiento.
class LiveRouteBanner extends StatelessWidget {
  const LiveRouteBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = AppColors.tint(colors.primary, colors.surface, 0.08);
    final edge = AppColors.tint(colors.primary, colors.outlineVariant, 0.6);
    final ink = AppColors.legible(colors.primary, fill);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: Container(
        height: 88,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: edge),
        ),
        child: Ambient(
          // Vuelta amplia: el micro va y viene sin apuro, así el ojo lo sigue
          // sin que parezca un parpadeo sobre el texto.
          period: const Duration(milliseconds: 7000),
          builder: (context, t, phase, _) {
            return CustomPaint(
              painter: _TrackPainter(phase: phase, tint: ink),
              child: Padding(
                // El texto va arriba, el riel + micro abajo: ya no se enciman.
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.sm,
                  AppSpace.lg,
                  0,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Santa Cruz en movimiento',
                        style: context.text.titleSmall?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Tu próxima línea está a un toque',
                        style: context.text.bodySmall?.copyWith(
                          color: ink.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.phase, required this.tint});

  final double phase;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    // El riel vive al pie de la tarjeta (debajo del texto) para no tapar letras.
    final trackY = size.height - 18;
    final trackPaint = Paint()
      ..color = tint.withValues(alpha: 0.18)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(AppSpace.lg, trackY),
      Offset(size.width - AppSpace.lg, trackY),
      trackPaint,
    );

    // Paradas sobre el riel.
    for (var i = 0; i < 5; i++) {
      final x = AppSpace.lg + (size.width - AppSpace.lg * 2) * (i / 4);
      canvas.drawCircle(
        Offset(x, trackY),
        i.isEven ? 2.8 : 2.0,
        Paint()..color = tint.withValues(alpha: i.isEven ? 0.4 : 0.22),
      );
    }

    // El micro recorre de izquierda a derecha y vuelve (ida/vuelta en una fase).
    final travel = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final x = AppSpace.lg + (size.width - AppSpace.lg * 2) * travel;
    final goingRight = phase < 0.5;

    canvas.save();
    // El cuerpo del micro se apoya SOBRE el riel (la base toca la línea).
    canvas.translate(x, trackY - 14);
    if (!goingRight) {
      canvas.scale(-1, 1);
    }
    canvas.drawOval(
      const Rect.fromLTWH(-15, 15, 30, 4),
      Paint()..color = tint.withValues(alpha: 0.18),
    );
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-14, 0, 28, 15),
      const Radius.circular(4),
    );
    canvas.drawRRect(body, Paint()..color = tint.withValues(alpha: 0.28));
    canvas.drawRRect(
      body,
      Paint()
        ..color = tint.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawRect(
      const Rect.fromLTWH(-14, 5, 28, 3),
      Paint()..color = tint.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 1.5, 6, 7),
        const Radius.circular(1.5),
      ),
      Paint()..color = tint.withValues(alpha: 0.5),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-11.0 + i * 5.5, 1.5, 4, 4.5),
          const Radius.circular(1),
        ),
        Paint()..color = tint.withValues(alpha: 0.45),
      );
    }
    canvas.drawCircle(
      const Offset(13, 9),
      1.6,
      Paint()..color = tint.withValues(alpha: 0.95),
    );
    for (final wx in [-8.0, 8.0]) {
      canvas.drawCircle(
        Offset(wx, 16),
        3.2,
        Paint()..color = tint.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        Offset(wx, 16),
        1.4,
        Paint()..color = tint.withValues(alpha: 0.35),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.phase != phase || old.tint != tint;
}
