import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius;
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

/// Tile unificado para destinos recientes: muestra el destino con el ícono
/// apropiado según si proviene de un viaje guardado (origen→destino) o del
/// historial (solo destino).
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
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final (
      String title,
      String? subtitle,
      int? duration,
      DateTime lastUsed,
    ) = switch (item) {
      RecentDestinationSavedTrip(:final trip) => (
        trip.destinationLabel,
        trip.originLabel,
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

    final trailing = duration != null && duration > 0
        ? '$duration min'
        : _timeAgo(lastUsed);

    // Colores degradados según sheet.html: cada item usa un gradiente diferente
    final gradient = _gradientForItem(item);
    final shadowColor = gradient[0].withValues(alpha: 0.25);

    // Píldora de tiempo — colores según el gradiente
    final pillBg = gradient[0].withValues(alpha: 0.1);
    final pillInk = dark
        ? HtmlDesignTokens.slate200
        : gradient[0].withValues(alpha: 1.0);
    final pillBorder = gradient[0].withValues(alpha: 0.5);

    return PressScale(
      scale: 0.97,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark ? HtmlDesignTokens.slate800 : HtmlDesignTokens.white,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(
              color: dark ? AppColors.lineDark : HtmlDesignTokens.slate200,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: dark
                    ? Colors.black.withValues(alpha: 0.1)
                    : HtmlDesignTokens.slate900.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icono con gradiente
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: dark
                                  ? HtmlDesignTokens.slate50
                                  : HtmlDesignTokens.slate900,
                            ),
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: gradient[0],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: dark
                              ? HtmlDesignTokens.slate400
                              : HtmlDesignTokens.slate500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Píldora de duración/tiempo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: pillBorder, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 9, color: pillInk),
                    const SizedBox(width: 4),
                    Text(
                      trailing,
                      style: text.labelSmall?.copyWith(
                        color: pillInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Botón eliminar
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: dark
                      ? HtmlDesignTokens.slate500
                      : HtmlDesignTokens.slate400,
                ),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Retorna un gradiente de colores según el tipo de item, como sheet.html.
  List<Color> _gradientForItem(RecentDestinationItem item) {
    // Usamos un hash del key para seleccionar un gradiente consistente
    final hash = item.key.hashCode.abs();
    return const <List<Color>>[
      // Esmeralda → teal
      [HtmlDesignTokens.emerald600, HtmlDesignTokens.teal500],
      // Ámbar → rosa
      [HtmlDesignTokens.amber500, HtmlDesignTokens.rose500],
      // Índigo → violeta
      [HtmlDesignTokens.indigo600, HtmlDesignTokens.purple500],
      // Cyan → azul
      [HtmlDesignTokens.cyan500, HtmlDesignTokens.blue500],
      // Rosa → fucsia
      [HtmlDesignTokens.pink500, HtmlDesignTokens.fuchsia500],
    ][hash % 5];
  }

  static String _timeAgo(DateTime dt) {
    final days = DateTime.now().difference(dt).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'ayer';
    return 'hace $days d';
  }
}
