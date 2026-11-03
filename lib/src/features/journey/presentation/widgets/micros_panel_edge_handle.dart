import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Tirador del borde derecho del cajón: vive flotando sobre el mapa, invita al
/// arrastre horizontal y cierra el panel al tocarlo.
class MicrosPanelEdgeHandle extends StatelessWidget {
  const MicrosPanelEdgeHandle({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      elevation: 4,
      borderRadius: const BorderRadius.horizontal(
        right: Radius.circular(AppRadius.tile),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(AppRadius.tile),
        ),
        child: SizedBox(
          width: 16,
          height: 44,
          child: Center(
            // Color explícito: el tirador vive flotando sobre el mapa y
            // heredaría el IconTheme de la página, que en oscuro es claro y
            // en claro es oscuro según el tema.
            child: Icon(
              Icons.chevron_left_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
