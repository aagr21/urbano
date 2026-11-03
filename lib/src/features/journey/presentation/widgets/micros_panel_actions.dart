import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import 'micros_panel_motion.dart';

/// Acciones rápidas del panel: «Activar todas» (con el tinte de marca: es la
/// acción buena) y «Limpiar» (esta última solo cobra sentido —y color de
/// daño— cuando hay algo que limpiar).
class MicrosPanelActions extends StatelessWidget {
  const MicrosPanelActions({
    super.key,
    required this.activeCount,
    required this.locked,
    required this.animation,
    required this.onActivateAll,
    required this.onClearAll,
  });

  /// Recorridos dibujados AHORA en el mapa.
  final int activeCount;

  /// Hay un toggle en vuelo: las acciones esperan.
  final bool locked;

  /// Tramo de la entrada del panel que le toca a esta sección.
  final Animation<double> animation;

  final VoidCallback onActivateAll;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Relleno de "Activar todas": el acento al 12% con su tinta legible
    // encima (medida contra la mezcla, no contra la superficie).
    final addFill = Color.lerp(colors.surface, colors.primary, 0.12)!;
    return microsRise(
      animation,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locked ? null : onActivateAll,
                style: OutlinedButton.styleFrom(
                  backgroundColor: addFill,
                  foregroundColor: AppColors.legible(colors.primary, addFill),
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.35),
                  ),
                ),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Activar todas'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locked || activeCount == 0 ? null : onClearAll,
                style: OutlinedButton.styleFrom(
                  // `colors.error` (no `Colors.red.shade700`): en el tema
                  // oscuro el token es un rojo luminoso; un rojo oscuro sobre
                  // la superficie oscura sería letra oscura sobre fondo oscuro.
                  foregroundColor: activeCount == 0 ? null : colors.error,
                ),
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Limpiar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
