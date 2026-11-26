import '../data/route_models.dart';

/// Hitos de Santa Cruz que valen el doble aunque el micro solo pase un
/// par de veces: son los lugares que toda la ciudad reconoce.
const _landmarks = [
  'terminal',
  'mercado',
  'anillo',
  'radial',
  'doble vía',
  'rn7',
  'cristo redentor',
  'estadio',
  'hospital',
  'universidad',
  'estación',
];

/// Vías de referencia del recorrido: frecuencia a lo largo de todas las
/// paradas — con BONUS a hitos conocidos (terminal, mercado, anillos,
/// radiales, doble vía…) para que un punto importante aunque poco
/// recorrido también suba — y ordenado por la primera aparición geográfica.
List<String> routeMainPlaces(List<RouteStop> stops, {int max = 10}) {
  if (stops.isEmpty) return const [];
  final frequency = <String, int>{};
  final label = <String, String>{};
  final firstSeen = <String, int>{};
  for (final stop in stops) {
    for (final raw in stop.name.split(' esquina ')) {
      // El feed canta la misma vía de dos maneras («RN7: X - Y» con y sin
      // espacios alrededor del guion): normalizar ANTES de contar.
      final street = raw.replaceAll(RegExp(r'\s+[-–]\s+'), '-').trim();
      if (street.isEmpty) continue;
      frequency[street] = (frequency[street] ?? 0) + 1;
      label[street] ??= street;
      firstSeen[street] ??= stop.sequence;
    }
  }
  // La puntuación es la frecuencia, pero un hito conocido vale doble:
  // «Terminal Bimodal» puede pasar 2 veces y sigue siendo EL lugar.
  double score(String street) {
    final base = frequency[street]!.toDouble();
    final hit = _landmarks.any(
      (t) =>
          street.toLowerCase().contains(t) ||
          street.toLowerCase().startsWith(t),
    );
    return hit ? base * 2 : base;
  }

  final picked = frequency.keys.toList()
    ..sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      return firstSeen[a]!.compareTo(firstSeen[b]!);
    });
  return picked.take(max).map((s) => label[s]!).toList()
    ..sort((a, b) => firstSeen[a]!.compareTo(firstSeen[b]!));
}

/// El «esquina» saca el cruce: el lugar ES la vía principal.
String stopStreet(String name) {
  final base = name.split(' esquina ').first.trim();
  return base.isEmpty ? name : base;
}
