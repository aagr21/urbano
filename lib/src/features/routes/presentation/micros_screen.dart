import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/urbano_back_button.dart';
import '../data/route_facts.dart';
import '../data/route_models.dart';
import '../data/route_repository.dart';
import 'micros_catalog_widgets.dart';
import 'widgets/micro_bus_art.dart';
import 'widgets/micros_card.dart';

/// **Catálogo completo de micros** en pantalla propia.
///
/// La lista muestra la identidad real de cada línea —numeral con su color GTFS,
/// recorrido, paradas y sentidos— y lleva al detalle (`/routes/:id`) con el
/// badge en vuelo. El buscador consulta el backend con debounce y el orden es
/// una decisión explícita ([CatalogSort]), no un adorno.
///
/// El backend topa `limit` en 100 y el feed ronda las 154 líneas, así que la
/// lista pagina de 100 en 100 al acercarse al final (el repositorio ya cachea
/// cada página).
class MicrosScreen extends ConsumerStatefulWidget {
  const MicrosScreen({super.key});

  @override
  ConsumerState<MicrosScreen> createState() => _MicrosScreenState();
}

class _MicrosScreenState extends ConsumerState<MicrosScreen> {
  static const _pageSize = 100;

  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _debounce = Debouncer(delay: const Duration(milliseconds: 280));
  final List<RouteSummary> _routes = [];

  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;
  CatalogSort _sort = CatalogSort.number;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce.dispose();
    _scroll
      ..removeListener(_maybeLoadMore)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  Future<Paged<RouteSummary>> _fetch(int page) {
    final query = _search.text.trim();
    return ref
        .read(routeRepositoryProvider)
        .list(
          q: query.isEmpty ? null : query,
          page: page,
          limit: _pageSize,
          sort: _sort.value,
        );
  }

  Future<void> _loadFirstPage({bool skeleton = true}) async {
    setState(() {
      _loading = skeleton;
      _error = null;
      _hasMore = false;
    });
    try {
      final result = await _fetch(1);
      if (!mounted) return;
      setState(() {
        _routes
          ..clear()
          ..addAll(result.items);
        _page = 1;
        _total = result.meta.safeTotal;
        _hasMore = result.items.isNotEmpty && _routes.length < _total;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _maybeLoadMore() {
    if (_loading || _loadingMore || !_hasMore) return;
    if (_scroll.position.extentAfter > 420) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final next = _page + 1;
    try {
      final result = await _fetch(next);
      if (!mounted) return;
      final known = {for (final route in _routes) route.id};
      setState(() {
        _routes.addAll(
          result.items.where((route) => !known.contains(route.id)),
        );
        _page = next;
        _total = result.meta.safeTotal;
        _hasMore = result.items.isNotEmpty && _routes.length < _total;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
    }
  }

  void _onQueryChanged(String _) {
    _debounce.run(() {
      if (!mounted) return;
      _loadFirstPage();
    });
  }

  void _changeSort(CatalogSort sort) {
    if (sort == _sort) return;
    _debounce.cancel();
    setState(() => _sort = sort);
    _loadFirstPage();
    _scroll.jumpTo(0);
  }

  void _openDetail(RouteSummary route) {
    context.push(UrbanoRoutes.routeDetail(route.id, from: 'micros'));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg,
                        AppSpace.md,
                        AppSpace.lg,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroBanner(context),
                          const SizedBox(height: AppSpace.md),
                          _buildSearch(context),
                          const SizedBox(height: AppSpace.sm),
                          _buildResultsCaption(context),
                        ],
                      ),
                    ),
                  ),
                  if (_loading)
                    const SliverToBoxAdapter(child: SkeletonList())
                  else if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: ErrorView(
                          error: _error,
                          onRetry: _loadFirstPage,
                        ),
                      ),
                    )
                  else if (_routes.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState(context))
                  else
                    _buildRouteListSliver(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cabecera: volver, identidad del catálogo y la única acción de pantalla
  /// (actualizar). Antes había un botón de mapa y una campana que no hacían
  /// nada: un control que no responde es peor que no tenerlo.
  Widget _buildHeader(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

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
                        color: AppColors.tint(
                          colors.primary,
                          colors.surface,
                          0.14,
                        ),
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
                          color: AppColors.legible(
                            colors.primary,
                            AppColors.tint(
                              colors.primary,
                              colors.surface,
                              0.14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _loading
                      ? 'Santa Cruz de la Sierra'
                      : 'Santa Cruz de la Sierra · $_total líneas',
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
            onPressed: _loading ? null : _loadFirstPage,
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

  /// Banda de identidad del catálogo: qué es, qué se puede hacer y los datos
  /// de ciudad que no cambian por línea (cuántas hay, pasaje y fuente).
  Widget _buildHeroBanner(BuildContext context) {
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
                        value: _loading ? '—' : '$_total',
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

  Widget _buildSearch(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: colors.outlineVariant),
    );

    return TextField(
      controller: _search,
      onChanged: _onQueryChanged,
      onSubmitted: (_) {
        _debounce.cancel();
        _loadFirstPage();
      },
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
          valueListenable: _search,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Limpiar búsqueda',
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              onPressed: () {
                _search.clear();
                _loadFirstPage();
              },
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

  /// Qué se está viendo y en qué orden. El orden es un selector visible (no
  /// un menú escondido dentro del buscador): es una decisión real del catálogo.
  Widget _buildResultsCaption(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final query = _search.text.trim();
    final label = _loading
        ? 'Cargando líneas…'
        : query.isEmpty
        ? '$_total líneas'
        : '$_total ${_total == 1 ? 'línea' : 'líneas'} para «$query»';

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        MicrosSortSwitch(value: _sort, onChanged: _changeSort),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final query = _search.text.trim();
    return EmptyState(
      icon: Icons.directions_bus_outlined,
      title: query.isEmpty
          ? 'Todavía no hay líneas'
          : 'Sin líneas para "$query"',
      message: query.isEmpty
          ? 'El catálogo se llena cuando el backend importa el feed GTFS.'
          : 'Prueba con otro número o nombre de línea.',
      actionLabel: query.isEmpty ? null : 'Limpiar búsqueda',
      onAction: query.isEmpty
          ? null
          : () {
              _search.clear();
              _loadFirstPage();
            },
    );
  }

  Widget _buildRouteListSliver(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index >= _routes.length) {
          if (_loadingMore) {
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
          return null;
        }
        final route = _routes[index];
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
              onTap: () => _openDetail(route),
            ),
          ),
        );
      }, childCount: _routes.length + (_loadingMore ? 1 : 0)),
    );
  }
}
