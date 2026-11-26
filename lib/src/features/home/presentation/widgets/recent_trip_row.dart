import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../../journey/data/trip_history.dart';
import 'recent_trips_route_indicator.dart';

/// Contenido de una fila del historial (indicador de ruta, destino, contexto
/// y la píldora de duración). Lo comparten la portada y la hoja «Ver todos»;
/// cada lista decide cómo responde al toque.
class RecentTripRowContent extends StatelessWidget {
  const RecentTripRowContent({super.key, required this.entry});

  final TripHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final titleInk = colors.onSurface;
    final subInk = colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm + 2,
        AppSpace.md,
        AppSpace.sm + 2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: RouteDotIndicator(
              ink: titleInk,
              lineColor: subInk.withValues(alpha: 0.3),
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
                    style: text.bodySmall?.copyWith(
                      color: subInk,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          TripDurationPill(
            label: tripHistoryPillLabel(entry, now: DateTime.now()),
          ),
        ],
      ),
    );
  }
}

/// Píldora de duración al pie de cada fila: gris claro con ícono de reloj.
class TripDurationPill extends StatelessWidget {
  const TripDurationPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark
        ? colors.onSurface.withValues(alpha: 0.1)
        : HtmlDesignTokens.slate100;
    final ink = dark ? colors.onSurface : HtmlDesignTokens.slate500;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm + 2,
        vertical: AppSpace.xs + 1,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 12, color: ink),
          const SizedBox(width: AppSpace.xs),
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
