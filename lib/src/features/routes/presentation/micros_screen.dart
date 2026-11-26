import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../application/micros_catalog_controller.dart';
import 'micros_catalog_sections.dart';

/// **Catálogo completo de micros** en pantalla propia.
///
/// La lista muestra la identidad real de cada línea —numeral con su color GTFS,
/// recorrido, paradas y sentidos— y lleva al detalle (`/routes/:id`) con el
/// badge en vuelo. El buscador consulta el backend con debounce y el orden es
/// una decisión explícita ([CatalogSort]), no un adorno.
///
/// Esta clase solo cablea: la paginación y sus reglas viven en
/// [MicrosCatalogController]; los bloques visuales, en
/// `micros_catalog_sections.dart`.
class MicrosScreen extends ConsumerStatefulWidget {
  const MicrosScreen({super.key});

  @override
  ConsumerState<MicrosScreen> createState() => _MicrosScreenState();
}

class _MicrosScreenState extends ConsumerState<MicrosScreen> {
  /// A cuántos píxeles del final se pide la página siguiente.
  static const _loadMoreThreshold = 420.0;

  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _debounce = Debouncer(delay: const Duration(milliseconds: 280));

  MicrosCatalogController get _catalog =>
      ref.read(microsCatalogControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
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

  void _maybeLoadMore() {
    if (_scroll.position.extentAfter > _loadMoreThreshold) return;
    _catalog.loadMore();
  }

  void _searchNow() {
    _debounce.cancel();
    _catalog.search(_search.text);
  }

  void _clearSearch() {
    _search.clear();
    _searchNow();
  }

  void _changeSort(CatalogSort sort) {
    _debounce.cancel();
    _catalog.sortBy(sort);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(microsCatalogControllerProvider);
    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLowest,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            MicrosHeader(
              total: state.total,
              loading: state.loading,
              onRefresh: _catalog.reload,
            ),
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
                          MicrosHeroBanner(
                            total: state.total,
                            loading: state.loading,
                          ),
                          const SizedBox(height: AppSpace.md),
                          MicrosSearchField(
                            controller: _search,
                            onChanged: (_) => _debounce.run(() {
                              if (mounted) _catalog.search(_search.text);
                            }),
                            onSubmitted: (_) => _searchNow(),
                            onClear: _clearSearch,
                          ),
                          const SizedBox(height: AppSpace.sm),
                          MicrosResultsCaption(
                            caption: state.caption,
                            sort: state.sort,
                            onSort: _changeSort,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.loading)
                    const SliverToBoxAdapter(child: SkeletonList())
                  else if (state.error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: ErrorView(
                          error: state.error,
                          onRetry: _catalog.reload,
                        ),
                      ),
                    )
                  else if (state.routes.isEmpty)
                    SliverToBoxAdapter(
                      child: MicrosEmpty(
                        query: state.query,
                        onClear: _clearSearch,
                      ),
                    )
                  else
                    MicrosRouteListSliver(
                      routes: state.routes,
                      loadingMore: state.loadingMore,
                      onOpen: (route) => context.push(
                        UrbanoRoutes.routeDetail(route.id, from: 'micros'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
