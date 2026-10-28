import 'package:flutter/material.dart';

import '../animation/motion.dart';

/// Efecto `one-shot` sobre fotos al entrar al viewport: un destello
/// translúcido cruza diagonalmente la imagen una vez (`Ambient.cycles: 1`)
/// y un zoom sutil de Ken Burns (1.08 → 1) se relaja. `phi` decorativos que
/// terminan a t=1 y no se repiten — nunca consume presupuesto idle en ciclo.
/// El uso de [Ambient] garantiza el respetado de `disableAnimations`.
class PhotoShine extends StatelessWidget {
  const PhotoShine({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Ambient(
      cycles: 1,
      period: const Duration(milliseconds: 1800),
      // El subtree costante viaja en el `child` del Ambient (no se
      // reconstruye por frame) y el builder pinta los overlays encima solo
      // mientras dura la pasada; al llegar a t=1 queda el child pelado.
      child: child,
      builder: (context, t, phase, child) {
        if (t >= 1 || child == null) return child ?? const SizedBox.shrink();
        return Transform.scale(
          // Ken Burns one-shot: zoom-out sutil 1.08 → 1. Es solo pintura (no
          // toca el layout), así la fila puede tener altura intrínseca.
          scale: 1 + 0.08 * (1 - t),
          child: Stack(
            // LOOSE, nunca `expand`: [PhotoShine] puede montarse en contextos
            // de altura no acotada (filas de listas) donde `expand` intenta
            // forzar altura infinita y tumba el layout con RenderBox
            // was not laid out. El child mide el Stack; el shine lo cubre.
            alignment: Alignment.topLeft,
            children: [
              child,
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _ShinePainter(progress: t),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Banda diagonal de brillo blanco que recorre la imagen con el progreso
/// global `t` de [Ambient] — al llegar a t=1 ya salió del recuadro y queda
/// pintada fuera (invisible en reposo).
class _ShinePainter extends CustomPainter {
  const _ShinePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // La banda cruza de -0.7 a +1.7 del ancho: sale en ambos extremos.
    final x = -size.width * 0.7 + size.width * 2.4 * progress;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(-0.28)
      ..translate(-size.width / 2, -size.height / 2);

    final band = Rect.fromLTWH(
      x,
      -size.height,
      size.width * 0.42,
      size.height * 3,
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white24,
          Colors.white54,
          Colors.transparent,
        ],
        stops: [0, 0.35, 0.55, 1],
      ).createShader(band);
    canvas.drawRect(band, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShinePainter old) => old.progress != progress;
}
