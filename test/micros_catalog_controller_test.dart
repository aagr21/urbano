import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/routes/application/micros_catalog_controller.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';

import 'helpers/fake_route_repository.dart';

RouteSummary _route(String id) => RouteSummary(
  id: id,
  shortName: id,
  longName: 'Micro $id',
  color: '7F8C8D',
  textColor: 'FFFFFF',
  description: '',
  type: 3,
  directionsCount: 2,
  stopCount: 10,
  tripCount: 2,
);

/// Paginación del catálogo `/micros` sin widgets.
void main() {
  Future<(ProviderContainer, FakeRouteRepository)> start(
    List<RouteSummary> routes, {
    Object? error,
  }) async {
    final repo = FakeRouteRepository(routes, listError: error);
    final container = ProviderContainer(
      overrides: [routeRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    // Mantiene vivo el provider autoDispose durante el test.
    container.listen(microsCatalogControllerProvider, (_, _) {});
    await container.read(microsCatalogControllerProvider.notifier).initialLoad;
    return (container, repo);
  }

  MicrosCatalogState read(ProviderContainer c) =>
      c.read(microsCatalogControllerProvider);

  test('la primera página carga y avisa que hay más', () async {
    final (c, _) = await start(List.generate(150, (i) => _route('$i')));
    final state = read(c);
    expect(state.loading, isFalse);
    expect(state.routes, hasLength(MicrosCatalogController.pageSize));
    expect(state.total, 150);
    expect(state.hasMore, isTrue);
    expect(state.caption, '150 líneas');
  });

  test('loadMore suma la segunda página y se detiene al final', () async {
    final (c, repo) = await start(List.generate(150, (i) => _route('$i')));
    final notifier = c.read(microsCatalogControllerProvider.notifier);
    await notifier.loadMore();
    expect(read(c).routes, hasLength(150));
    expect(read(c).hasMore, isFalse);

    await notifier.loadMore(); // ya no hay más: no pide nada
    expect(repo.listCalls, hasLength(2));
  });

  test(
    'buscar recarga desde la primera página con el texto recortado',
    () async {
      final (c, _) = await start([_route('17'), _route('45'), _route('170')]);
      await c.read(microsCatalogControllerProvider.notifier).search('  17 ');
      final state = read(c);
      expect(state.query, '17');
      expect(state.routes.map((r) => r.id), ['17', '170']);
      expect(state.caption, '2 líneas para «17»');
    },
  );

  test('una sola coincidencia se dice en singular', () async {
    final (c, _) = await start([_route('17'), _route('45')]);
    await c.read(microsCatalogControllerProvider.notifier).search('45');
    expect(read(c).caption, '1 línea para «45»');
  });

  test(
    'cambiar el orden lo manda al backend; el mismo orden no recarga',
    () async {
      final (c, repo) = await start([_route('1')]);
      final notifier = c.read(microsCatalogControllerProvider.notifier);
      await notifier.sortBy(CatalogSort.number);
      expect(repo.listCalls, hasLength(1));
      await notifier.sortBy(CatalogSort.corridor);
      expect(repo.listCalls.last, contains('sort=longName'));
    },
  );

  test('un error de red queda en el estado y no deja cargando', () async {
    final (c, _) = await start(const [], error: Exception('sin red'));
    expect(read(c).error, isNotNull);
    expect(read(c).loading, isFalse);
  });

  group('reglas puras', () {
    test('appendRoutePage no repite líneas ya cargadas', () {
      final merged = appendRoutePage(
        [_route('1'), _route('2')],
        [_route('2'), _route('3')],
      );
      expect(merged.map((r) => r.id), ['1', '2', '3']);
    });

    test('catalogHasMore: página vacía o total alcanzado = no hay más', () {
      expect(
        catalogHasMore(loaded: 100, total: 150, lastPageEmpty: false),
        isTrue,
      );
      expect(
        catalogHasMore(loaded: 150, total: 150, lastPageEmpty: false),
        isFalse,
      );
      expect(
        catalogHasMore(loaded: 100, total: 150, lastPageEmpty: true),
        isFalse,
      );
    });
  });
}
