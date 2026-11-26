/// Una página de una lista paginada.
typedef ListPage<T> = ({List<T> items, int page, int totalPages});

/// Recorta [items] a la página [page] de [pageSize]. Una página fuera de rango
/// (p. ej. tras borrar la última fila de la última página) se acota a la
/// última que existe, así la lista nunca queda vacía teniendo filas.
ListPage<T> pageOf<T>(
  List<T> items, {
  required int page,
  required int pageSize,
}) {
  final totalPages = items.isEmpty ? 0 : (items.length / pageSize).ceil();
  final safe = totalPages == 0 ? 0 : page.clamp(0, totalPages - 1);
  return (
    items: items.skip(safe * pageSize).take(pageSize).toList(growable: false),
    page: safe,
    totalPages: totalPages,
  );
}
