import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/urbano_glyph.dart';
import '../../../journey/data/trip_history.dart';

/// Contenido de una fila del historial: el ícono del recorrido, el destino con
/// su contexto, la píldora de cuándo se usó («Hoy», «Ayer»…) y, si se da
/// [onRemove], la X que lo borra del historial. Lo comparten la portada y la
/// hoja «Ver todos»; cada lista decide cómo responde al toque.
class RecentTripRowContent extends StatelessWidget {
  const RecentTripRowContent({super.key, required this.entry, this.onRemove});

  final TripHistoryEntry entry;

  /// Borra la fila del historial. Sin él no hay X (la hoja «Ver todos»).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleInk = colors.onSurface;
    final subInk = colors.onSurfaceVariant;
    final plate = AppColors.tint(
      colors.primary,
      colors.surface,
      dark ? 0.18 : 0.10,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm + 2,
        onRemove == null ? AppSpace.md : AppSpace.xs,
        AppSpace.sm + 2,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(AppSpace.sm),
            decoration: BoxDecoration(color: plate, shape: BoxShape.circle),
            child: UrbanoGlyph(
              UrbanoGlyphKind.journey,
              color: dark ? colors.primary : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleInk,
                  ),
                ),
                if (entry.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: subInk),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          TripDurationPill(
            label: tripHistoryPillLabel(entry, now: DateTime.now()),
          ),
          if (onRemove != null)
            IconButton(
              key: ValueKey('recent-trip-remove-${entry.key}'),
              onPressed: onRemove,
              tooltip: 'Quitar del historial',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 22, color: subInk),
            ),
        ],
      ),
    );
  }
}

/// Píldora de cuándo se usó el destino: blanca con filete y reloj.
class TripDurationPill extends StatelessWidget {
  const TripDurationPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? colors.onSurface : const Color(0xFF4A4F4C);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm + 2,
        vertical: AppSpace.xs + 1,
      ),
      decoration: BoxDecoration(
        color: dark ? colors.surfaceContainerHigh : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: dark ? AppColors.lineDark : colors.outlineVariant,
        ),
        boxShadow: dark
            ? null
            : AppTheme.softShadow(
                color: Colors.black,
                opacity: 0.05,
                blur: 6,
                dy: 2,
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 14, color: ink),
          const SizedBox(width: AppSpace.xs),
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
