import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../journey/data/trip_history.dart';
import 'recent_trips_route_indicator.dart';

/// Hoja «Ver todos»: el historial completo, con el mismo bloque agrupado de la
/// portada. Tocar una fila cierra la hoja y replanifica ese destino.
///
/// Lleva un buscador con lupa (filtra por nombre/subtítulo, sin distinguir
/// mayúsculas) y pagina de 8 en 8 cuando hay más de una
/// página.
class AllTripsSheet extends StatefulWidget {
  const AllTripsSheet({
    super.key,
    required this.entries,
    required this.onSelect,
  });

  final List<TripHistoryEntry> entries;
  final ValueChanged<TripHistoryEntry> onSelect;

  static const int _pageSize = 8;

  @override
  State<AllTripsSheet> createState() => _AllTripsSheetState();
}

class _AllTripsSheetState extends State<AllTripsSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TripHistoryEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.entries;
    return widget.entries
        .where(
          (entry) =>
              entry.label.toLowerCase().contains(q) ||
              (entry.subtitle?.toLowerCase().contains(q) ?? false),
        )
        .toList(growable: false);
  }

  int get _pages => (_filtered.length / AllTripsSheet._pageSize).ceil();

  List<TripHistoryEntry> get _visible {
    final filtered = _filtered;
    final start = _page * AllTripsSheet._pageSize;
    final end = (start + AllTripsSheet._pageSize).clamp(0, filtered.length);
    if (start >= end) return const [];
    return filtered.sublist(start, end);
  }

  void _onSearch(String value) {
    setState(() {
      _query = value;
      _page = 0;
    });
  }

  void _goToPage(int page) {
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppColors.tint(colors.primary, colors.surface, 0.12);
    final iconInk = dark
        ? colors.onSurface
        : AppColors.legible(colors.primary, fill);
    final hairline = dark ? AppColors.lineDark : colors.outlineVariant;

    final filtered = _filtered;
    final pages = _pages;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.history_rounded, size: 21, color: iconInk),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tus viajes recientes',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.entries.length == 1
                            ? '1 destino guardado'
                            : '${widget.entries.length} destinos guardados',
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            TextField(
              key: const ValueKey('recent-trips-search'),
              controller: _searchController,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              cursorColor: colors.primary,
              style: text.bodyMedium?.copyWith(color: colors.onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar destino',
                hintStyle: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconColor: colors.onSurfaceVariant,
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          key: const ValueKey('recent-trips-clear-search'),
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                ),
                filled: true,
                fillColor: colors.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide(color: hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide(color: hairline),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      'Sin destinos para «$_query»',
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              _AllTripsHistoryList(
                entries: _visible,
                onSelect: widget.onSelect,
              ),
            if (pages > 1) ...[
              const SizedBox(height: AppSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: const ValueKey('recent-trips-prev-page'),
                    tooltip: 'Página anterior',
                    onPressed: _page > 0 ? () => _goToPage(_page - 1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(
                    'Página ${_page + 1} de $pages',
                    key: const ValueKey('recent-trips-page-label'),
                    style: text.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('recent-trips-next-page'),
                    tooltip: 'Página siguiente',
                    onPressed: _page < pages - 1
                        ? () => _goToPage(_page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lista interna de filas del historial para la hoja «Ver todos».
///
/// Reutiliza la misma tarjeta agrupada (_HistoryPanel) y las mismas filas
/// (_TripRow) que la portada, pero con el prefijo de clave
/// `recent-trip-all-` para distinguir las keys de los widgets.
class _AllTripsHistoryList extends StatelessWidget {
  const _AllTripsHistoryList({required this.entries, required this.onSelect});

  final List<TripHistoryEntry> entries;
  final ValueChanged<TripHistoryEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hairline = dark ? AppColors.lineDark : HtmlDesignTokens.slate100;
    final cardBg = dark ? colors.surface : HtmlDesignTokens.whiteBlue;
    final borderColor = dark ? AppColors.lineDark : HtmlDesignTokens.emerald50;
    final radius = BorderRadius.circular(AppRadius.lg);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: radius,
        border: Border.all(color: borderColor),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 64,
                endIndent: AppSpace.lg,
                color: hairline,
              ),
            _TripRow(
              key: ValueKey('recent-trip-all-${entries[i].key}'),
              entry: entries[i],
              onTap: () => onSelect(entries[i]),
            ),
          ],
          const SizedBox(height: AppSpace.xs),
        ],
      ),
    );
  }
}

/// Fila individual del historial: estilo del HTML.
class _TripRow extends StatelessWidget {
  const _TripRow({super.key, required this.entry, required this.onTap});

  final TripHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleInk = colors.onSurface;
    final subInk = colors.onSurfaceVariant;

    // Píldora de duración: estilo del HTML (gris claro con ícono).
    final pillFill = dark
        ? colors.onSurface.withValues(alpha: 0.1)
        : HtmlDesignTokens.slate100;
    final pillInk = dark ? colors.onSurface : HtmlDesignTokens.slate500;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: titleInk.withValues(alpha: 0.06),
        child: Padding(
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
                      const SizedBox(height: 1),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm + 2,
                  vertical: AppSpace.xs + 1,
                ),
                decoration: BoxDecoration(
                  color: pillFill,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 12, color: pillInk),
                    const SizedBox(width: 4),
                    Text(
                      _trailing(entry),
                      style: text.labelSmall?.copyWith(
                        color: pillInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _trailing(TripHistoryEntry entry) {
    final minutes = entry.durationMinutes;
    if (minutes != null && minutes > 0) return Fmt.duration(minutes);
    final days = DateTime.now().difference(entry.lastUsed).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'ayer';
    return 'hace $days d';
  }
}
