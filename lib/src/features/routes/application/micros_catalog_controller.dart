import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/route_models.dart';
import '../data/route_repository.dart';

/// Orden del catálogo. Se traduce al `sort` del contrato (`/routes`).
enum CatalogSort {
  number('name', 'número de línea', '1–9'),
  corridor('longName', 'nombre del recorrido', 'A–Z');

  const CatalogSort(this.value, this.label, this.short);

  /// Valor que entiende el backend.
  final String value;

  /// Cómo se lee en la app.
  final String label;

  /// Etiqueta del selector.
  final String short;
}

/// Estado del catálogo `/micros`: lo cargado hasta ahora y en qué fase está.
class MicrosCatalogState {
  const MicrosCatalogState({
    this.routes = const [],
    this.page = 0,
    this.total = 0,
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.error,
    this.query = '',
    this.sort = CatalogSort.number,
  });

  final List<RouteSummary> routes;

  /// Última página cargada (1-based; 0 = ninguna).
  final int page;

  /// Total de líneas que reporta el backend para la búsqueda actual.
  final int total;

  /// Primera página en curso (el esqueleto ocupa la lista).
  final bool loading;

  /// Página siguiente en curso (fila «Cargando más líneas…» al final).
  final bool loadingMore;
  final bool hasMore;
  final Object? error;

  /// Búsqueda ya aplicada (sin espacios a los lados).
  final String query;
  final CatalogSort sort;

  /// Qué se está viendo, en palabras.
  String get caption {
    if (loading) return 'Cargando líneas…';
    if (query.isEmpty) return '$total líneas';
    return '$total ${total == 1 ? 'línea' : 'líneas'} para «$query»';
  }

  MicrosCatalogState copyWith({
    List<RouteSummary>? routes,
    int? page,
    int? total,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
    String? query,
    CatalogSort? sort,
  }) => MicrosCatalogState(
    routes: routes ?? this.routes,
    page: page ?? this.page,
    total: total ?? this.total,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
    query: query ?? this.query,
    sort: sort ?? this.sort,
  );
}

/// Suma una página nueva sin repetir líneas ya cargadas (el backend puede
/// devolver solapes si el feed cambia entre páginas).
List<RouteSummary> appendRoutePage(
  List<RouteSummary> current,
  List<RouteSummary> incoming,
) {
  final known = {for (final route in current) route.id};
  return [...current, ...incoming.where((route) => !known.contains(route.id))];
}

/// ¿Quedan páginas? Solo si la última trajo algo y aún falta para el total.
bool catalogHasMore({
  required int loaded,
  required int total,
  required bool lastPageEmpty,
}) => !lastPageEmpty && loaded < total;

/// Paginación del catálogo de micros contra `/routes`.
///
/// El backend topa `limit` en 100 y el feed ronda las 154 líneas: se pide de
/// 100 en 100 y la pantalla avisa cuando se acerca al final ([loadMore]).
class MicrosCatalogController extends AutoDisposeNotifier<MicrosCatalogState> {
  static const pageSize = 100;

  /// Firma de la consulta en vuelo: una respuesta vieja (otra búsqueda u
  /// otro orden) no pisa la nueva.
  int _generation = 0;

  /// Primera carga, lanzada al crearse el controlador (fuera de `build`:
  /// escribir el estado mientras se construye está prohibido). Se expone para
  /// poder esperarla.
  late Future<void> initialLoad;

  @override
  MicrosCatalogState build() {
    initialLoad = Future.microtask(reload);
    return const MicrosCatalogState();
  }

  RouteRepository get _repo => ref.read(routeRepositoryProvider);

  Future<Paged<RouteSummary>> _fetch(int page) => _repo.list(
    q: state.query.isEmpty ? null : state.query,
    page: page,
    limit: pageSize,
    sort: state.sort.value,
  );

  /// Vuelve a la primera página. Con [skeleton] en `false` la lista actual
  /// queda a la vista mientras llega la nueva.
  Future<void> reload({bool skeleton = true}) async {
    final generation = ++_generation;
    state = state.copyWith(
      loading: skeleton,
      hasMore: false,
      loadingMore: false,
      clearError: true,
    );
    try {
      final result = await _fetch(1);
      if (generation != _generation) return;
      state = state.copyWith(
        routes: result.items,
        page: 1,
        total: result.meta.safeTotal,
        hasMore: catalogHasMore(
          loaded: result.items.length,
          total: result.meta.safeTotal,
          lastPageEmpty: result.items.isEmpty,
        ),
        loading: false,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(error: error, loading: false);
    }
  }

  /// Pide la página siguiente, si corresponde.
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final generation = _generation;
    final next = state.page + 1;
    state = state.copyWith(loadingMore: true);
    try {
      final result = await _fetch(next);
      if (generation != _generation) return;
      final routes = appendRoutePage(state.routes, result.items);
      state = state.copyWith(
        routes: routes,
        page: next,
        total: result.meta.safeTotal,
        hasMore: catalogHasMore(
          loaded: routes.length,
          total: result.meta.safeTotal,
          lastPageEmpty: result.items.isEmpty,
        ),
        loadingMore: false,
      );
    } catch (_) {
      if (generation != _generation) return;
      // Sin red al paginar: se queda lo cargado y no se reintenta en bucle.
      state = state.copyWith(loadingMore: false, hasMore: false);
    }
  }

  /// Aplica una búsqueda (ya con su pausa: la decide la pantalla).
  Future<void> search(String query) {
    state = state.copyWith(query: query.trim());
    return reload();
  }

  /// Cambia el orden y recarga; el mismo orden no hace nada.
  Future<void> sortBy(CatalogSort sort) async {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort);
    await reload();
  }
}

final microsCatalogControllerProvider =
    NotifierProvider.autoDispose<MicrosCatalogController, MicrosCatalogState>(
      MicrosCatalogController.new,
    );
