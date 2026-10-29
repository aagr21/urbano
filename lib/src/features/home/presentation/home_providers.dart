import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../routes/data/route_models.dart';
import '../../routes/data/route_repository.dart';
import '../../routes/presentation/route_providers.dart';
import '../data/meta.dart';
import '../data/stats.dart';
import '../data/stats_repository.dart';

/// Datos del dashboard (stats del feed GTFS).
final statsProvider = FutureProvider<Stats>(
  (ref) => ref.watch(statsRepositoryProvider).stats(),
);

/// Contrato del dataset (`GET /meta`) para la pantalla Info.
final metaProvider = FutureProvider<MetaInfo>(
  (ref) => ref.watch(statsRepositoryProvider).meta(),
);

/// Salud/versionado del backend (para la pantalla Info).
final healthProvider = FutureProvider<HealthInfo>(
  (ref) => ref.watch(statsRepositoryProvider).health(),
);

/// Resultado del buscador global (solo rutas: las paradas se retiraron).
class GlobalSearchResult {
  const GlobalSearchResult({required this.routes});

  final Paged<RouteSummary> routes;

  bool get isEmpty => routes.items.isEmpty;
}

/// Forma (polilínea + color) de la ruta destacada del mini mapa del home.
class FeaturedRouteShape {
  const FeaturedRouteShape({required this.points, required this.colorHex});

  final List<LatLng> points;
  final String colorHex;
}

/// Geometría de la primera ruta del listado para el mini mapa destacado.
///
/// Devuelve `null` si no hay rutas, si la ruta no tiene `shape` o si algo
/// falla: el mapa del home es decorativo y nunca debe romper la pantalla.
final featuredRouteShapeProvider =
    FutureProvider.autoDispose<FeaturedRouteShape?>((ref) async {
      try {
        final page = await ref.watch(
          routesListProvider(const RoutesQuery(limit: 6)).future,
        );
        if (page.items.isEmpty) return null;
        final detail = await ref.watch(
          routeDetailProvider(RouteKey(page.items.first.id)).future,
        );
        final shape = detail.shape;
        if (shape == null || shape.points.length < 2) return null;
        return FeaturedRouteShape(points: shape.points, colorHex: detail.color);
      } catch (_) {
        return null;
      }
    });

/// Buscador global de rutas (query ya debounced).
final globalSearchProvider = FutureProvider.autoDispose
    .family<GlobalSearchResult, String>((ref, rawQuery) async {
      final query = rawQuery.trim();
      if (query.isEmpty) {
        return const GlobalSearchResult(
          routes: Paged(items: [], meta: Meta()),
        );
      }

      final routes = await ref
          .watch(routeRepositoryProvider)
          .list(q: query, limit: 5);
      return GlobalSearchResult(routes: routes);
    });
