import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Píldora etiquetada que entra al modo pantalla completa del mapa. Vive a
/// la IZQUIERDA de la columna de controles (nunca encima: esos px de reserva
/// ya están contados para la franja de mapa del planeador).
class MapCompletePill extends StatelessWidget {
  const MapCompletePill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return PressScale(
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        elevation: 3,
        shadowColor: Colors.black38,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fit_screen_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'Mapa completo',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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
