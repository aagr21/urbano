import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../data/route_models.dart';
import '../route_providers.dart';

/// «Pasa por»: los lugares principales del recorrido, derivados de las
/// paradas del feed. Nada de horarios — calles y vías de referencia.
///
/// La heurística vive en [RoutePlaces.mainPlaces] (pública para testing):
/// el nombre de una parada es «X esquina Y»; contamos cuántas veces aparece
/// cada vía a lo largo de todo el recorrido y nos quedamos con las más
/// frecuentes, ordenadas por dónde aparecen PRIMERO — la lista se lee en el
/// orden geográfico del micro, de origen al destino.
class RoutePlaces extends ConsumerWidget {
  const RoutePlaces({
    super.key,
    required this.routeKey,
    required this.routeColor,
  });

  final RouteKey routeKey;
  final Color routeColor;

  /// Hitos de Santa Cruz que valen el doble aunque el micro solo pase un
  /// par de veces: son los lugares que toda la ciudad reconoce.
  static const _landmarks = [
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
  static List<String> mainPlaces(List<RouteStop> stops, {int max = 10}) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(routeStopsProvider(routeKey));
    final colors = context.colors;
    final text = context.text;

    return AsyncValueView<List<RouteStop>>(
      value: stops,
      onRetry: () => ref.invalidate(routeStopsProvider(routeKey)),
      isEmpty: (items) => items.isEmpty,
      emptyIcon: Icons.route_rounded,
      emptyTitle: 'Recorrido sin paradas',
      emptyMessage: 'El feed no declara paradas en este sentido.',
      onEmpty: () => const SizedBox.shrink(),
      loadingCount: 3,
      // La maqueta imita la forma real del recorrido.
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            LoadingShimmer(width: 120, height: 64, radius: AppRadius.tile),
            SizedBox(width: 26),
            LoadingShimmer(width: 120, height: 64, radius: AppRadius.tile),
            SizedBox(width: 26),
            LoadingShimmer(width: 120, height: 64, radius: AppRadius.tile),
          ],
        ),
      ),
      onError: (error) => const SizedBox.shrink(),
      data: (items) {
        final places = mainPlaces(items);
        final originStreet = _street(items.first.name);
        final endStreet = _street(items.last.name);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            //
            // Cabecera: origen → destino en dos cápsulas con la identidad de
            // la línea (tó del color real, borde al 35%).
            //
            Row(
              children: [
                _EndpointChip(
                  label: originStreet,
                  color: routeColor,
                  icon: Icons.trip_origin_rounded,
                  expanded: true,
                ),
                // Flecha de avance: el ojo lee de izquierda a derecha,
                // exactamente la dirección del micro en este sentido.
                Icon(
                  Icons.double_arrow_rounded,
                  size: 18,
                  color: routeColor.withValues(alpha: 0.55),
                ),
                _EndpointChip(
                  label: endStreet,
                  color: routeColor,
                  icon: Icons.location_searching_rounded,
                  expanded: true,
                ),
              ],
            ),
            //
            // La línea de recorrido: nodos + tramos que SE DIBUJAN una vez
            // (Ambient cycles: 1, one-shot con ciclo explícito). Los tramos
            // arrancan en cascada según su posición: la primera vez parece
            // el micro recorriendo la ruta de izquierda a derecha.
            //
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              clipBehavior: Clip.none,
              child: Ambient(
                cycles: 1,
                period: const Duration(milliseconds: 1100),
                builder: (context, t, phase, child) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < places.length; i++) ...[
                        _PlaceNode(
                          label: places[i],
                          color: routeColor,
                          index: i,
                          first: i == 0,
                          last: i == places.length - 1,
                        ),
                        if (i < places.length - 1)
                          _RouteSegment(
                            color: routeColor,
                            // Progresión por tramo: el tramo i empieza a
                            // dibujarse cuando el anterior anda a medio camino
                            // — el ojo lee la ruta materializándose de
                            // izquierda a derecha.
                            progress: ((t * (places.length - 1) - i).clamp(
                              0.0,
                              1.0,
                            )),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.route_rounded,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    CountUp(
                      value: items.length,
                      format: (v) => '$v paradas en este sentido',
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// El «esquina» saca el cruce: el lugar ES la vía principal.
  static String _street(String name) {
    final base = name.split(' esquina ').first.trim();
    return base.isEmpty ? name : base;
  }
}

/// Cápsula de extremo (origen/destino) del recorrido: relleno tinte 8%,
/// borde tinte 35% y el icono en el color de la línea como acento — el
/// texto se queda en el de la superficie, que es el fondo real medible.
class _EndpointChip extends StatelessWidget {
  const _EndpointChip({
    required this.label,
    required this.color,
    required this.icon,
    this.expanded = false,
  });

  /// El color del micro actúa como acento, no como relleno continuo.
  final String label;
  final Color color;
  final IconData icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    final decoration = BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    );
    return expanded
        ? Expanded(
            child: Container(decoration: decoration, child: content),
          )
        : Container(decoration: decoration, child: content);
  }
}

/// Tramo entre dos nodos del recorrido: se dibuja TRAZÁNDOSE una vez —
/// dashes del color de la línea que crecen, con un «bus» en la frontera del
/// trazo mientras avanza, y el camino base tenue ya puesto, para que la
/// lectura del lugar sea clara ANTES del primer trazo.
class _RouteSegment extends StatelessWidget {
  const _RouteSegment({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Altura ALINEADA al centro del chip de nodo (26 px): el tramo conecta
    // exactamente los chips, no los rótulos.
    return SizedBox(
      width: 30,
      height: _PlaceNode.chipSize,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SegmentPainter(color: color, progress: progress),
      ),
    );
  }
}

class _SegmentPainter extends CustomPainter {
  const _SegmentPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Camino base prometido (tenue).
    paint.color = color.withValues(alpha: 0.22);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    // Trazo activo con dash: crece al progreso del tramo.
    if (progress > 0) {
      paint.color = color;
      final end = size.width * progress;
      final dashed = Path();
      const dash = 5.0;
      const gap = 4.0;
      for (double x = 0; x < end; x += dash + gap) {
        dashed.moveTo(x, y);
        dashed.lineTo(math.min(x + dash, end), y);
      }
      canvas.drawPath(dashed, paint);

      // Bus en la frontera del trazo: circulito claro con anillo del tinte —
      // uno por tramo mientras su trazo avanza; al cerrarse desaparecen y la
      // línea queda terminada, continua y sutil.
      if (progress < 1) {
        canvas.drawCircle(
          Offset(end, y),
          4,
          Paint()..color = color.withValues(alpha: 0.25),
        );
        canvas.drawCircle(Offset(end, y), 2.6, Paint()..color = Colors.white);
        canvas.drawCircle(
          Offset(end, y),
          2.6,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentPainter old) =>
      old.progress != progress || old.color != color;
}

class _PlaceNode extends StatelessWidget {
  const _PlaceNode({
    required this.label,
    required this.color,
    required this.index,
    required this.first,
    required this.last,
  });

  static const chipSize = 26.0;

  final String label;
  final Color color;
  final int index;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    // Relleno sólido (extremos) frente al color puro; relleno translúcido
    // (intermedios) pintado sobre superficie: mido ese fondo real, no el
    // tinte — regla nada-oscuro-sobre-oscuro.
    final filled = first || last;
    final foreground = filled
        ? AppColors.onColor(color)
        : AppColors.legible(
            color,
            Color.lerp(context.colors.surface, color, 0.14)!,
          );
    return SizedBox(
      width: 110,
      child: Column(
        children: [
          // Chip del nodo: extremo = icono, intermedio = numeral. Los números
          // le dan orden legible a la lista (el orden en que pasa el micro) y
          // el relleno tinte ancla el color de la línea.
          Container(
            width: chipSize,
            height: chipSize,
            decoration: BoxDecoration(
              color: filled ? color : color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: filled
                    ? Colors.transparent
                    : color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: filled
                ? Icon(
                    first ? Icons.play_arrow_rounded : Icons.stop_rounded,
                    size: 16,
                    color: foreground,
                  )
                : Center(
                    child: Text(
                      '${index + 1}',
                      style: text.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(
              fontWeight: first || last ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
