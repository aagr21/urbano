import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../data/route_models.dart';
import '../data/route_repository.dart';
import 'widgets/micros_card.dart';

/// **Catálogo completo de micros** en pantalla propia.
///
/// Antes «Micros» abría el cajón lateral del mapa de Viaje: un fragmento que
/// solo dejaba ver la línea mientras el planificador seguía detrás. Aquí es una
/// pantalla de verdad —buscador, cifras del catálogo y una tarjeta por línea—
/// con la acción **Ver detalles** en cada una.
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
          sort: 'shortName',
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

  void _openDetail(RouteSummary route) {
    context.push(UrbanoRoutes.routeDetail(route.id, from: 'micros'));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark
          ? HtmlDesignTokens.slate900
          : HtmlDesignTokens.slate50,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom header con backdrop blur
            _buildHeader(context),
            // Contenido scrolleable
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
                          // Hero banner
                          _buildHeroBanner(context),
                          const SizedBox(height: AppSpace.md),
                          // Search + filter chips
                          _buildSearchAndFilters(context),
                        ],
                      ),
                    ),
                  ),
                  // Route list
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

  /// Header personalizado: back button, título "Micros" + badge "SCZ",
  /// botones de mapa y notificaciones.
  Widget _buildHeader(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark
        ? HtmlDesignTokens.slate800.withValues(alpha: 0.9)
        : HtmlDesignTokens.white.withValues(alpha: 0.9);
    final border = dark
        ? HtmlDesignTokens.slate700.withValues(alpha: 0.3)
        : HtmlDesignTokens.slate200.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.lg,
        AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          PressScale(
            scale: 0.95,
            child: InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: dark
                      ? HtmlDesignTokens.slate700
                      : HtmlDesignTokens.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: dark
                        ? HtmlDesignTokens.slate600
                        : HtmlDesignTokens.slate200.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: dark
                      ? HtmlDesignTokens.slate300
                      : HtmlDesignTokens.slate700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Micros',
                      style: context.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: dark
                            ? HtmlDesignTokens.white
                            : HtmlDesignTokens.slate900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // SCZ badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: HtmlDesignTokens.emerald100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: HtmlDesignTokens.emerald200.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                      child: Text(
                        'SCZ',
                        style: context.text.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: HtmlDesignTokens.emerald800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Santa Cruz de la Sierra',
                  style: context.text.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: dark
                        ? HtmlDesignTokens.slate400
                        : HtmlDesignTokens.slate500,
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Map button
              PressScale(
                scale: 0.95,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: HtmlDesignTokens.emerald50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: HtmlDesignTokens.emerald200.withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    size: 20,
                    color: HtmlDesignTokens.emerald700,
                  ),
                ),
              ),
              // Notification button
              PressScale(
                scale: 0.95,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: dark
                        ? HtmlDesignTokens.slate700
                        : HtmlDesignTokens.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: dark
                          ? HtmlDesignTokens.slate600
                          : HtmlDesignTokens.slate200.withValues(alpha: 0.7),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: dark
                            ? HtmlDesignTokens.slate300
                            : HtmlDesignTokens.slate600,
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: HtmlDesignTokens.emerald500,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: dark
                                  ? HtmlDesignTokens.slate700
                                  : HtmlDesignTokens.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Hero banner: gradiente esmeralda, ícono de micro, título,
  /// contador de líneas activas, tarifa y horario.
  Widget _buildHeroBanner(BuildContext context) {
    final text = context.text;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        // HTML: from-emerald-800 via-[#064e3b] to-teal-950
        // Tailwind emerald-800 = #064E3B = HtmlDesignTokens.emerald900
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HtmlDesignTokens.emerald900,
            HtmlDesignTokens.emerald900,
            HtmlDesignTokens.teal950,
          ],
        ),
        border: Border.all(
          color: HtmlDesignTokens.emerald600.withValues(alpha: 0.3),
        ),
        // HTML: shadow-floating = 0 12px 30px -4px rgba(6, 78, 59, 0.28)
        boxShadow: [
          BoxShadow(
            color: HtmlDesignTokens.emerald700.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient glow effects
          Positioned(
            right: -32,
            bottom: -40,
            child: Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                color: HtmlDesignTokens.emerald400.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: HtmlDesignTokens.emerald400.withValues(alpha: 0.05),
                    blurRadius: 48,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 56,
            top: -24,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: HtmlDesignTokens.teal300.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: HtmlDesignTokens.teal300.withValues(alpha: 0.08),
                    blurRadius: 32,
                  ),
                ],
              ),
            ),
          ),
          // Content
          Column(
            children: [
              Row(
                children: [
                  // Bus icon
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HtmlDesignTokens.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      border: Border.all(
                        color: HtmlDesignTokens.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      size: 24,
                      color: HtmlDesignTokens.emerald200,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title + count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Red Urbana de Micros',
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: HtmlDesignTokens.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: HtmlDesignTokens.emerald400.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: HtmlDesignTokens.emerald300.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                '$_total líneas activas',
                                style: text.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: HtmlDesignTokens.emerald100,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Toca cualquier línea para ver su recorrido y paradas',
                          style: text.labelSmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: HtmlDesignTokens.emerald100.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // HTML: mt-3 pt-2.5 border-t border-white/10
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Divider(
                  height: 0,
                  color: HtmlDesignTokens.white.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(height: 8),
              // Footer: fare + hours (HTML: flex-wrap gap-2)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  // Fare pill — HTML: bg-emerald-500/20 + pulse dot + white bold text
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: HtmlDesignTokens.emerald500.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: HtmlDesignTokens.emerald400.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: HtmlDesignTokens.emerald300,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tarifa oficial: Bs. 3.50',
                          style: text.labelSmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: HtmlDesignTokens.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Hours pill — HTML: bg-white/10
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: HtmlDesignTokens.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: HtmlDesignTokens.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: HtmlDesignTokens.emerald300,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '05:00 - 23:30',
                          style: text.labelSmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: HtmlDesignTokens.emerald100.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Búsqueda con chips de filtro horizontales.
  Widget _buildSearchAndFilters(BuildContext context) {
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? HtmlDesignTokens.slate300 : HtmlDesignTokens.slate800;
    final softInk = dark
        ? HtmlDesignTokens.slate400
        : HtmlDesignTokens.slate400;
    final hairline = dark
        ? HtmlDesignTokens.slate600
        : HtmlDesignTokens.slate200.withValues(alpha: 0.9);
    final fieldBg = dark ? HtmlDesignTokens.slate800 : HtmlDesignTokens.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        TextField(
          controller: _search,
          onChanged: _onQueryChanged,
          onSubmitted: (_) {
            _debounce.cancel();
            _loadFirstPage();
          },
          textInputAction: TextInputAction.search,
          cursorColor: HtmlDesignTokens.emerald600,
          style: text.bodyMedium?.copyWith(
            color: ink,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Busca por número, avenida o zona...',
            hintStyle: text.bodyMedium?.copyWith(color: softInk),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: softInk),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _search,
              builder: (context, value, _) {
                if (value.text.isEmpty) {
                  return IconButton(
                    icon: Icon(Icons.tune_rounded, size: 16, color: softInk),
                    onPressed: () {},
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  );
                }
                return IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: softInk),
                  onPressed: () {
                    _search.clear();
                    _loadFirstPage();
                  },
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                );
              },
            ),
            filled: true,
            fillColor: fieldBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(
                color: HtmlDesignTokens.emerald600,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Filter chips
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            children: [
              _filterChip(context, text, 'Todos', '$_total', true),
              const SizedBox(width: 8),
              _filterChip(context, text, '⭐ Favoritos'),
              const SizedBox(width: 8),
              _filterChip(context, text, 'Casco Viejo / Centro'),
              const SizedBox(width: 8),
              _filterChip(context, text, 'Anillos (1° al 4°)'),
              const SizedBox(width: 8),
              _filterChip(context, text, 'Plan 3000'),
              const SizedBox(width: 8),
              _filterChip(context, text, 'Villa 1° de Mayo'),
              const SizedBox(width: 8),
              _filterChip(context, text, 'Pampa de la Isla'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(
    BuildContext context,
    TextTheme text,
    String label, [
    String? count,
    bool isSelected = false,
  ]) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PressScale(
      scale: 0.97,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? HtmlDesignTokens.emerald700
                : (dark ? HtmlDesignTokens.slate700 : HtmlDesignTokens.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? HtmlDesignTokens.emerald800
                  : (dark
                        ? HtmlDesignTokens.slate600
                        : HtmlDesignTokens.slate200.withValues(alpha: 0.9)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: text.labelSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? HtmlDesignTokens.white
                      : (dark
                            ? HtmlDesignTokens.slate300
                            : HtmlDesignTokens.slate600),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? HtmlDesignTokens.emerald800.withValues(alpha: 0.9)
                        : HtmlDesignTokens.slate100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count,
                    style: text.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? HtmlDesignTokens.emerald100
                          : HtmlDesignTokens.slate600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
            child: MicroCard(route: route, onTap: () => _openDetail(route)),
          ),
        );
      }, childCount: _routes.length + (_loadingMore ? 1 : 0)),
    );
  }
}
