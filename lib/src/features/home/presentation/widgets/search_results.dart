import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../routes/presentation/widgets/route_list_tile.dart';
import '../home_providers.dart';

/// Resultados en vivo del buscador global (rutas).
class SearchResults extends ConsumerWidget {
  const SearchResults({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(globalSearchProvider(query));

    return AsyncValueView<GlobalSearchResult>(
      value: result,
      onRetry: () => ref.invalidate(globalSearchProvider(query)),
      isEmpty: (data) => data.isEmpty,
      emptyIcon: Icons.search_off_rounded,
      emptyTitle: 'Sin resultados para "$query"',
      emptyMessage: 'Prueba con otro nombre de ruta.',
      loadingCount: 4,
      data: (data) {
        final routes = data.routes.items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (routes.isNotEmpty) ...[
              SectionHeader(
                'Rutas',
                subtitle: '${data.routes.meta.total} coincidencias',
                actionLabel: 'Ver todas',
                onAction: () => UrbanoRoutes.openAllMicros(context, ref),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (var i = 0; i < routes.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      RouteListTile(
                        key: ValueKey(routes[i].id),
                        route: routes[i],
                        heroPrefix: 'search',
                        index: i,
                        onTap: () => context.push(
                          UrbanoRoutes.routeDetail(
                            routes[i].id,
                            from: 'search',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
