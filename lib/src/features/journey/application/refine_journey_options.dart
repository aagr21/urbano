import '../data/journey_models.dart';

/// Nº de candidatos a pedir al planificador para tener margen tras el filtrado.
///
/// Tope 10: el DTO del backend valida `maxResults` con `@Max(10)`; pasarlo
/// devuelve 400 "Validation failed" y el viaje entero falla.
int candidatePool(int maxShown) => (maxShown * 4).clamp(1, 10);

/// Quita opciones "parecidas" (misma secuencia de micros, solo cambia la hora)
/// y pone primero los viajes SIN transbordo.
///
/// - Dos opciones comparten firma si usan la misma secuencia de rutas (p. ej.
///   `8 → 10`). De cada firma se conserva UNA: la de salida más próxima, y ante
///   empate la de menor duración.
/// - Orden final: primero todos los directos, luego los de transbordo; dentro
///   de cada grupo, por duración asc y después por hora de salida asc.
List<JourneyOption> refineJourneyOptions(
  List<JourneyOption> options, {
  required int maxShown,
}) {
  final bestBySignature = <String, JourneyOption>{};
  for (final option in options) {
    final key = _routeSignature(option);
    final current = bestBySignature[key];
    if (current == null || _departsSooner(option, current)) {
      bestBySignature[key] = option;
    }
  }

  final ordered = bestBySignature.values.toList()
    ..sort((a, b) {
      final byType = _typeRank(a) - _typeRank(b);
      if (byType != 0) return byType;
      final byDuration = a.durationMinutes - b.durationMinutes;
      if (byDuration != 0) return byDuration;
      return a.departAt.compareTo(b.departAt);
    });

  return ordered.length <= maxShown ? ordered : ordered.sublist(0, maxShown);
}

/// Clave que identifica "la misma combinación de micros" ignorando la hora.
String _routeSignature(JourneyOption option) {
  final routes = option.busLegs
      .map((leg) => leg.routeShortName ?? leg.routeId ?? '')
      .join('>');
  return routes;
}

int _typeRank(JourneyOption option) =>
    option.type == JourneyType.direct ? 0 : 1;

/// `true` si [a] sale antes que [b]; a igualdad de hora, la de menor duración.
bool _departsSooner(JourneyOption a, JourneyOption b) {
  final byDepart = a.departAt.compareTo(b.departAt);
  if (byDepart != 0) return byDepart < 0;
  return a.durationMinutes < b.durationMinutes;
}
