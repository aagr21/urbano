import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/glass_card.dart';

/// Píldora inferior que resume el viaje y abre/cierra el panel de
/// origen/destino. Es el único control persistente de la zona baja.
class JourneyPlannerTrigger extends StatelessWidget {
  const JourneyPlannerTrigger({
    super.key,
    required this.originLabel,
    required this.destinationLabel,
    required this.panelOpen,
    required this.onTap,
  });

  /// Etiqueta del lugar de origen o `null` si aún no se fijó.
  final String? originLabel;

  /// Etiqueta del lugar de destino o `null` si aún no se fijó.
  final String? destinationLabel;

  /// `true` con el panel de origen/destino desplegado (gira la flecha).
  final bool panelOpen;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    final hasBoth = originLabel != null && destinationLabel != null;
    final hasAny = originLabel != null || destinationLabel != null;

    final title = hasBoth
        ? '$originLabel  →  $destinationLabel'
        : (originLabel ?? destinationLabel ?? '¿A dónde vas?');
    final subtitle = hasBoth
        ? 'Tu viaje'
        : (hasAny
              ? 'Toca para completar el viaje'
              : 'Marca origen y destino para viajar');

    return GlassCard(
      key: const ValueKey('planner-trigger'),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      radius: AppRadius.pill,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasAny ? Icons.route_rounded : Icons.search_rounded,
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // La flecha gira al abrir/cerrar: refuerza el gesto del panel.
          AnimatedRotation(
            turns: panelOpen ? 0.5 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
