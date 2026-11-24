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
///   `8 → 10`). De cada firma se conserva UNA: la que llega antes; ante
///   empate, la que MENOS hace caminar y luego la de menor duración. No se
///   elige por "sale antes": salir antes para caminar hasta una parada más
///   lejana de la MISMA línea (un tramo que el micro ya cubría) ganaba
///   siempre esa comparación.
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
    if (current == null || _isBetterVariant(option, current)) {
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

/// `true` si [a] es mejor variante que [b] de la misma combinación de
/// micros: llega antes; a igualdad, camina menos; después, dura menos.
bool _isBetterVariant(JourneyOption a, JourneyOption b) {
  final byArrive = a.arriveAt.compareTo(b.arriveAt);
  if (byArrive != 0) return byArrive < 0;
  final byWalk = totalWalkMeters(a) - totalWalkMeters(b);
  if (byWalk != 0) return byWalk < 0;
  return a.durationMinutes < b.durationMinutes;
}

/// Metros a pie de una opción: suma de sus tramos de caminata o, si el
/// backend no los manda, de `walkToStop` + `walkFromStop`.
int totalWalkMeters(JourneyOption option) {
  final walks = option.walkLegs;
  if (walks.isNotEmpty) {
    return walks.fold(0, (acc, leg) => acc + (leg.distanceMeters ?? 0));
  }
  return (option.walkToStop?.distanceMeters ?? 0) +
      (option.walkFromStop?.distanceMeters ?? 0);
}
