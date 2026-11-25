// Piezas que flotan sobre el mapa de «Micros cerca»: placa del lugar
// y botón redondo.

import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/glass_card.dart';
import '../domain/nearby_micros.dart';

/// Placa flotante del lugar: «Micros cerca de · Plaza 24 · 12 líneas · 500 m».
class NearbyPlacePlate extends StatelessWidget {
  const NearbyPlacePlate({
    super.key,
    required this.label,
    required this.radius,
    required this.lines,
  });

  final String label;
  final int radius;
  final int? lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final count = lines;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.sm,
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.accent, colors.surface, 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.place_rounded,
              size: 20,
              color: AppColors.legible(
                AppColors.accent,
                AppColors.tint(AppColors.accent, colors.surface, 0.18),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Micros cerca de',
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null)
                CountUp(
                  value: count,
                  format: (n) => '$n',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.primary,
                  ),
                ),
              Text(
                count == null
                    ? formatNearbyDistance(radius.toDouble())
                    : '${count == 1 ? 'línea' : 'líneas'} · '
                          '${formatNearbyDistance(radius.toDouble())}',
                style: text.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botón redondo del mapa (misma talla que los controles del planificador).
class NearbyMapRoundButton extends StatelessWidget {
  const NearbyMapRoundButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surface,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: colors.shadow.withValues(alpha: 0.3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: AppControl.mapButton,
            child: Icon(icon, size: 22, color: colors.onSurface),
          ),
        ),
      ),
    );
  }
}
