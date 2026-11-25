import '../../routes/data/route_models.dart';

/// Lógica pura del selector de micro del formulario de quejas: búsqueda por
/// número o por calle y el resumen del recorrido que se muestra en cada fila.
///
/// Vive fuera del widget para poder probarla sin montar la hoja.

/// Minúsculas y sin tildes: «Piraí», «pirai» y «PIRAÍ» son la misma búsqueda.
String foldForSearch(String value) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const to = 'aaaaaeeeeiiiiooooouuuun';
  final lower = value.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    out.write(index < 0 ? char : to[index]);
  }
  return out.toString();
}

/// Paradas clave «con nombre»: fuera las genéricas del feed (`Parada S1966`),
/// que no le dicen nada a nadie.
List<String> namedKeyStops(RouteSummary route) => [
  for (final stop in route.keyStops ?? const <String>[])
    if (stop.trim().isNotEmpty &&
        !RegExp(
          r'^parada\s+s?\d+$',
          caseSensitive: false,
        ).hasMatch(stop.trim()))
      stop.trim(),
];

/// Abrevia una parada para que quepa en una línea:
/// `Avenida Piraí esquina Calle Venus` → `Av. Piraí y C. Venus`.
String shortStopName(String stop) => stop
    .replaceAll(RegExp(r'\bAvenida\b'), 'Av.')
    .replaceAll(RegExp(r'\bCalle\b'), 'C.')
    .replaceAll(RegExp(r'\s+esquina\s+'), ' y ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// «Pasa por …» de una línea (hasta dos paradas), o `null` si el feed no trae
/// ninguna parada con nombre.
String? routeStopsSummary(RouteSummary route) {
  final stops = namedKeyStops(route).take(2).map(shortStopName).toList();
  if (stops.isEmpty) return null;
  return 'Pasa por ${stops.join(' · ')}';
}

/// Filtra y ordena las líneas para [query].
///
/// * Vacío: todas, en el orden recibido.
/// * Solo dígitos: primero la línea exacta (`8`), luego las que empiezan por
///   ese número (`80`, `81`…) y al final las que lo contienen (`18`). Es como
///   busca quien ya sabe en qué micro iba.
/// * Texto: número, nombre o cualquier parada clave (por calle), sin tildes.
List<RouteSummary> searchRoutes(List<RouteSummary> routes, String query) {
  final q = foldForSearch(query.trim());
  if (q.isEmpty) return routes;

  if (RegExp(r'^\d+$').hasMatch(q)) {
    int rank(RouteSummary route) {
      final number = route.shortName.trim().toLowerCase();
      if (number == q) return 0;
      if (number.startsWith(q)) return 1;
      if (number.contains(q)) return 2;
      return 3;
    }

    final ranked = [
      for (final route in routes)
        if (rank(route) < 3) route,
    ];
    // `sort` no es estable en Dart: se desempata por la posición original.
    final order = {for (final (i, route) in routes.indexed) route.id: i};
    ranked.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : order[a.id]!.compareTo(order[b.id]!);
    });
    return ranked;
  }

  return [
    for (final route in routes)
      if (foldForSearch(
        [route.shortName, route.longName, ...?route.keyStops].join(' '),
      ).contains(q))
        route,
  ];
}
