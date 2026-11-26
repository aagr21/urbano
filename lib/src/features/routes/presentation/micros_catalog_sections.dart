// Bloques de la pantalla `/micros` (MicrosScreen): cabecera, banda de
// identidad, buscador, rótulo de resultados, vacío y lista. Todos son
// presentación pura: reciben datos y callbacks, el estado vive en
// `MicrosCatalogController`.

import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/urbano_back_button.dart';
import '../application/micros_catalog_controller.dart';
import '../data/route_facts.dart';
import '../data/route_models.dart';
import 'micros_catalog_widgets.dart';
import 'widgets/micro_bus_art.dart';
import 'widgets/micros_card.dart';

/// Cabecera: volver, identidad del catálogo y la única acción de pantalla
/// (actualizar). Antes había un botón de mapa y una campana que no hacían
/// nada: un control que no responde es peor que no tenerlo.
class MicrosHeader extends StatelessWidget {
  const MicrosHeader({
    super.key,
    required this.total,
    required this.loading,
    required this.onRefresh,
  });

  final int total;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final badgeFill = AppColors.tint(colors.primary, colors.surface, 0.14);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.sm,
        AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          const UrbanoBackButton(key: ValueKey('micros-back')),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Micros',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeFill,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Text(
                        'SCZ',
                        style: text.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.legible(colors.primary, badgeFill),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  loading
                      ? 'Santa Cruz de la Sierra'
                      : 'Santa Cruz de la Sierra · $total líneas',
                  style: text.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: loading ? null : onRefresh,
            tooltip: 'Actualizar catálogo',
            icon: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banda de identidad del catálogo: qué es, qué se puede hacer y los datos
/// de ciudad que no cambian por línea (cuántas hay, pasaje y fuente).
class MicrosHeroBanner extends StatelessWidget {
  const MicrosHeroBanner({
    super.key,
    required this.total,
    required this.loading,
  });

  final int total;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HtmlDesignTokens.emerald900, HtmlDesignTokens.teal950],
        ),
        boxShadow: [
          BoxShadow(
            color: HtmlDesignTokens.emerald700.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Anillos de la ciudad como textura: la banda no es un rectángulo
          // plano, pero tampoco compite con las tarjetas.
          const Positioned(
            right: -46,
            top: -46,
            child: MicrosHeroRing(size: 150, alpha: 0.10),
          ),
          const Positioned(
            right: -14,
            top: -14,
            child: MicrosHeroRing(size: 86, alpha: 0.14),
          ),
          const Positioned(
            right: AppSpace.lg,
            top: AppSpace.md,
            child: MicroBusArt(
              color: HtmlDesignTokens.emerald400,
              size: Size(48, 32),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Red urbana de micros',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: HtmlDesignTokens.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(right: 64),
                  child: Text(
                    'Toca una línea para ver su recorrido, horario y por dónde pasa.',
                    style: text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: HtmlDesignTokens.emerald100.withValues(
                        alpha: 0.88,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: MicrosHeroStat(
                        value: loading ? '—' : '$total',
                        label: 'líneas',
                      ),
                    ),
                    const MicrosHeroDivider(),
                    const Expanded(
                      child: MicrosHeroStat(
                        value: kOfficialFareLabel,
                        label: 'pasaje',
                      ),
                    ),
                    const MicrosHeroDivider(),
                    const Expanded(
                      child: MicrosHeroStat(
                        value: 'GTFS',
                        label: 'datos oficiales',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Buscador del catálogo (número, avenida o zona) con su botón de limpiar.
class MicrosSearchField extends StatelessWidget {
  const MicrosSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: colors.outlineVariant),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      cursorColor: colors.primary,
      style: text.bodyMedium?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Busca por número, avenida o zona…',
        hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: colors.onSurfaceVariant,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Limpiar búsqueda',
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              onPressed: onClear,
            );
          },
        ),
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.8),
        ),
      ),
    );
  }
}

/// Qué se está viendo y en qué orden. El orden es un selector visible (no
/// un menú escondido dentro del buscador): es una decisión real del catálogo.
class MicrosResultsCaption extends StatelessWidget {
  const MicrosResultsCaption({
    super.key,
    required this.caption,
    required this.sort,
    required this.onSort,
  });

  final String caption;
  final CatalogSort sort;
  final ValueChanged<CatalogSort> onSort;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        MicrosSortSwitch(value: sort, onChanged: onSort),
      ],
    );
  }
}

/// Catálogo vacío: sin feed importado, o sin resultados para la búsqueda.
class MicrosEmpty extends StatelessWidget {
  const MicrosEmpty({super.key, required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final searching = query.isNotEmpty;
    return EmptyState(
      icon: Icons.directions_bus_outlined,
      title: searching ? 'Sin líneas para "$query"' : 'Todavía no hay líneas',
      message: searching
          ? 'Prueba con otro número o nombre de línea.'
          : 'El catálogo se llena cuando el backend importa el feed GTFS.',
      actionLabel: searching ? 'Limpiar búsqueda' : null,
      onAction: searching ? onClear : null,
    );
  }
}

/// Lista de líneas (con la fila «Cargando más líneas…» al paginar).
class MicrosRouteListSliver extends StatelessWidget {
  const MicrosRouteListSliver({
    super.key,
    required this.routes,
    required this.loadingMore,
    required this.onOpen,
  });

  final List<RouteSummary> routes;
  final bool loadingMore;
  final ValueChanged<RouteSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index >= routes.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Center(
              child: Text(
                'Cargando más líneas…',
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final route = routes[index];
        return Reveal(
          key: ValueKey('micros-card-${route.id}'),
          index: index,
          slide: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: 6,
            ),
            child: MicroCard(
              route: route,
              heroPrefix: 'micros',
              onTap: () => onOpen(route),
            ),
          ),
        );
      }, childCount: routes.length + (loadingMore ? 1 : 0)),
    );
  }
}
