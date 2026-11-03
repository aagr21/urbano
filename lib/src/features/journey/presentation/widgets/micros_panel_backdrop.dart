import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/utils/extensions.dart';

/// Fondo vivo del cajón: dos manchas suaves (el verde agua de la marca y el
/// coral del atardecer) que derivan **muy** despacio tras el encabezado, más
/// una guía de color en el borde superior. Es UN solo [Ambient] para todo el
/// panel y va dentro de un [IgnorePointer]: el listado y sus toques no se
/// enteran del movimiento ni del color.
class MicrosPanelBackdrop extends StatelessWidget {
  const MicrosPanelBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IgnorePointer(
      child: ClipRect(
        child: Ambient(
          period: const Duration(seconds: 12),
          builder: (_, _, phase, _) {
            // Deriva senoidal: la mancha se va y vuelve sin saltos de bucle.
            final drift = math.sin(phase * 2 * math.pi);
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -70 + drift * 18,
                  top: -110,
                  child: _aura(colors.primary, 250, 0.16),
                ),
                Positioned(
                  right: -80 - drift * 14,
                  top: -60,
                  child: _aura(colors.tertiary, 200, 0.1),
                ),
                // Filo de color: el panel se lee «de Urbano» desde el borde.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          Color.lerp(colors.primary, colors.secondary, 0.8)!,
                          colors.tertiary,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Mancha radial del fondo (barata: un degradado, sin blur).
  Widget _aura(Color color, double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ),
    ),
  );
}
