import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animation/motion.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/route_badge.dart';
import '../../../core/widgets/urbano_back_button.dart';
import '../data/route_models.dart';
import '../data/route_repository.dart';
import 'widgets/micro_bus_art.dart';

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
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        leading: const UrbanoBackButton(),
        title: const Text('Micros'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CatalogIntro(total: _total, loading: _loading),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.sm,
                AppSpace.lg,
                AppSpace.sm,
              ),
              child: _SearchField(
                controller: _search,
                onChanged: _onQueryChanged,
                onClear: () {
                  _search.clear();
                  _loadFirstPage();
                },
                onSubmitted: (_) {
                  _debounce.cancel();
                  _loadFirstPage();
                },
              ),
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const SkeletonList();
    }
    if (_error != null) {
      return ErrorView(error: _error, onRetry: _loadFirstPage);
    }
    if (_routes.isEmpty) {
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

    return RefreshIndicator(
      onRefresh: () => _loadFirstPage(skeleton: false),
      child: ListView.separated(
        key: const ValueKey('micros-list'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.xs,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        itemCount: _routes.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, index) => index < _routes.length - 1
            ? const SizedBox(height: AppSpace.md)
            : const SizedBox(height: AppSpace.sm),
        itemBuilder: (context, index) {
          if (index >= _routes.length) {
            // Pie de paginación: texto estable (nada de spinners infinitos que
            // dejen `pumpAndSettle` sin converger en los tests).
            return Padding(
              padding: const EdgeInsets.only(top: AppSpace.lg),
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
          final route = _routes[index];
          return Reveal(
            key: ValueKey('micros-card-${route.id}'),
            index: index,
            slide: 8,
            child: _MicroCard(route: route, onTap: () => _openDetail(route)),
          );
        },
      ),
    );
  }
}

/// Portada del catálogo: una hoja con el color de marca y las cifras vivas.
class _CatalogIntro extends StatelessWidget {
  const _CatalogIntro({required this.total, required this.loading});

  final int total;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.onColor(AppColors.primaryDark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.lg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.md,
          AppSpace.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: ink.withValues(alpha: 0.22)),
              ),
              child: Icon(Icons.directions_bus_rounded, size: 22, color: ink),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Todas las líneas de Santa Cruz',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loading
                        ? 'Cargando el catálogo…'
                        : '$total líneas · toca una para ver su recorrido',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: ink.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (!loading)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$total',
                  style: context.text.labelMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Buscador de grafito con filete e íconos blancos: el relieve lo da el
    // borde claro, no un relleno blanco.
    final ink = colors.onSurface;
    final softInk = colors.onSurfaceVariant;
    final hairline = dark ? AppColors.lineDark : colors.outlineVariant;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      cursorColor: colors.primary,
      style: text.bodyLarge?.copyWith(color: ink),
      decoration: InputDecoration(
        hintText: 'Busca por número o nombre',
        hintStyle: text.bodyMedium?.copyWith(color: softInk),
        prefixIcon: const Icon(Icons.search_rounded),
        prefixIconColor: ink,
        suffixIconColor: softInk,
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Limpiar búsqueda',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
        ),
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: hairline),
        ),
      ),
    );
  }
}

/// Tarjeta de una línea: su micro ilustrado, identidad GTFS, cifras y
/// «Ver detalles».
///
/// La franja izquierda y el bus comparten el color del feed, así la lista se
/// escanea por línea sin leer el número. No hay paradas: el catálogo solo
/// conoce lo que el backend expone de cada ruta (viajes y sentidos).
class _MicroCard extends StatelessWidget {
  const _MicroCard({required this.route, required this.onTap});

  final RouteSummary route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = colors.onSurface;
    final softInk = colors.onSurfaceVariant;
    final accent = AppColors.fromHex(route.color);
    // El color de la línea entra teñido en la placa del bus y sólido en la
    // franja: nunca como relleno de la tarjeta.
    final tinted = AppColors.tint(accent, colors.surface, dark ? 0.18 : 0.10);
    final stripe = AppColors.legible(accent, colors.surface);
    final radius = BorderRadius.circular(AppRadius.lg);
    final hairline = dark
        ? AppColors.lineDark
        : colors.outlineVariant.withValues(alpha: 0.7);

    return PressScale(
      scale: 0.985,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: dark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : AppTheme.softShadow(opacity: 0.05, blur: 16),
        ),
        child: Material(
          color: colors.surface,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: ink.withValues(alpha: 0.05),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: hairline),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      AppSpace.md,
                      AppSpace.md,
                      AppSpace.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 66,
                              height: 54,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tinted,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.tile,
                                ),
                              ),
                              child: MicroBusArt(color: accent),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      RouteBadge(
                                        label: route.shortName,
                                        colorHex: route.color,
                                        textColorHex: route.textColor,
                                        size: RouteBadgeSize.small,
                                        heroTag:
                                            'route-badge-micros-${route.id}',
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: softInk,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    route.longName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                      color: ink,
                                    ),
                                  ),
                                  if (route.description.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      route.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.bodySmall?.copyWith(
                                        color: softInk,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: AppSpace.sm,
                                runSpacing: AppSpace.xs,
                                children: [
                                  MetaChip(
                                    icon: Icons.schedule_rounded,
                                    label: '${route.tripCount} rutas',
                                  ),
                                  if (route.directionsCount > 1)
                                    const MetaChip(
                                      icon: Icons.swap_horiz_rounded,
                                      label: 'Ida y vuelta',
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpace.xs),
                            TextButton(
                              onPressed: onTap,
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.sm,
                                  vertical: AppSpace.xs,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Ver detalles'),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 15,
                                    color: colors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: stripe,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(AppRadius.lg),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
