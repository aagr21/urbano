part of 'journey_micros_sheet.dart';

/// Descarga **todas** las rutas paginando `/routes` (100 por página) hasta
/// cubrir `meta.total` (el backend limita `limit` a 100). Ordenadas por
/// numeral (`sort: 'name'` → `route_short_name`). Ante un error devuelve lo
/// acumulado hasta ese momento (o vacío si falló la primera página).
Future<List<RouteSummary>> _fetchAllMicros(WidgetRef ref) async {
  const pageSize = 100;
  final repository = ref.read(routeRepositoryProvider);
  try {
    final first = await repository.list(limit: pageSize, sort: 'name');
    final micros = [...first.items];
    var page = 1;
    while (micros.length < first.meta.safeTotal) {
      page++;
      final next = await repository.list(
        page: page,
        limit: pageSize,
        sort: 'name',
      );
      if (next.items.isEmpty) break; // defensa contra bucles infinitos.
      micros.addAll(next.items);
    }
    return micros;
  } catch (_) {
    return const <RouteSummary>[];
  }
}

/// Fundido + deslizamiento desde la izquierda para la entrada escalonada de
/// las secciones del panel (impulsado por [_entrance], va de 0 a 1 una vez).
Widget _rise(Animation<double> a, Widget child) => FadeTransition(
  opacity: a,
  child: SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(-0.05, 0),
      end: Offset.zero,
    ).animate(a),
    child: child,
  ),
);

/// Entrada escalonada del listado, calculada sobre el valor de [entrance]
/// (la `_entrance` del panel):
/// matemática pura en `build`, sin timers ni listeners por tarjeta. Así el
/// escalonado no se re-dispara al hacer scroll (en cuanto termina la entrada
/// la tarjeta ya sale en su sitio) y el árbol se asienta sin relojes
/// pendientes en los tests de widget.
Widget _stagger(AnimationController entrance, int index, Widget tile) {
  if (entrance.isCompleted) return tile;
  final start = math.min(0.4 + index * 0.05, 0.9);
  final t = Curves.easeOutCubic.transform(
    ((entrance.value - start) / 0.18).clamp(0.0, 1.0),
  );
  return Opacity(
    opacity: t,
    child: Transform.translate(offset: Offset(-16 * (1 - t), 0), child: tile),
  );
}
