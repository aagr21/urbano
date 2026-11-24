import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius, AppSpace;
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../data/saved_trips.dart';
import '../../data/trip_history.dart';

/// Tipo unificado para destinos recientes: puede provenir de savedTrips
/// (viaje completo origen→destino) o de history (solo destino).
sealed class RecentDestinationItem {
  const RecentDestinationItem({required this.key, required this.lastUsed});
  final String key;
  final DateTime lastUsed;

  factory RecentDestinationItem.savedTrip(SavedTrip trip) =
      RecentDestinationSavedTrip;
  factory RecentDestinationItem.historyEntry(TripHistoryEntry entry) =
      RecentDestinationHistoryEntry;
}

class RecentDestinationSavedTrip extends RecentDestinationItem {
  RecentDestinationSavedTrip(this.trip)
    : super(key: trip.key, lastUsed: trip.lastUsed);
  final SavedTrip trip;
}

class RecentDestinationHistoryEntry extends RecentDestinationItem {
  RecentDestinationHistoryEntry(this.entry)
    : super(key: entry.key, lastUsed: entry.lastUsed);
  final TripHistoryEntry entry;
}

/// Fila de destino reciente.
///
/// Un solo acento por tipo (teal para el viaje guardado, esmeralda para el
/// historial) en vez del degradado aleatorio por fila: la lista se lee como
/// una sola familia y no como cinco tarjetas distintas.
class RecentDestinationTile extends StatelessWidget {
  const RecentDestinationTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final RecentDestinationItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final (title, subtitle, duration, lastUsed) = switch (item) {
      RecentDestinationSavedTrip(:final trip) => (
        trip.destinationLabel,
        'Desde ${trip.originLabel}',
        trip.durationMinutes,
        trip.lastUsed,
      ),
      RecentDestinationHistoryEntry(:final entry) => (
        entry.label,
        entry.subtitle,
        entry.durationMinutes,
        entry.lastUsed,
      ),
    };

    final isSavedTrip = item is RecentDestinationSavedTrip;
    final accent = isSavedTrip
        ? HtmlDesignTokens.teal600
        : HtmlDesignTokens.emerald600;
    final plate = AppColors.tint(accent, colors.surface, dark ? 0.24 : 0.12);
    final plateInk = AppColors.legible(accent, plate);
    final trailing = duration != null && duration > 0
        ? '$duration min'
        : _timeAgo(lastUsed);

    return PressScale(
      scale: 0.98,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpace.sm),
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(color: colors.outlineVariant, width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: plate,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  isSavedTrip ? Icons.alt_route_rounded : Icons.place_rounded,
                  size: 17,
                  color: plateInk,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: colors.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: colors.outlineVariant, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 11,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trailing,
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: colors.outline,
                ),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final days = DateTime.now().difference(dt).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'ayer';
    return 'hace $days d';
  }
}
