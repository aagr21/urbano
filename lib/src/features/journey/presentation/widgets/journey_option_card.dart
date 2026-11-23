import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../data/journey_models.dart';

/// Tarjeta de opción de viaje con timeline expandible de tramos.
class JourneyOptionCard extends StatelessWidget {
  const JourneyOptionCard({
    super.key,
    required this.option,
    required this.expanded,
    required this.onToggle,
    this.index = 0,
    this.selected = false,
  });

  final JourneyOption option;
  final bool expanded;
  final VoidCallback onToggle;
  final int index;

  /// `true` si esta opción es la visible en el mapa de resultados.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final isDirect = option.type == JourneyType.direct;

    // Colores de ruta que se repiten entre micros: asignar color alternativo
    // para que no se confundan dos líneas distintas con el mismo color GTFS.
    final legAltColors = alternativeRouteColorsForLegs(option.legs);

    return Reveal(
      index: index,
      stagger: const Duration(milliseconds: 70),
      slide: 10,
      child: PressScale(
        child: AnimatedContainer(
          // Seleccionar/expandir morfea en vez de parpadear: el borde y el
          // fondo entran por interpolación.
          duration: Motion.duration(context, Motion.base),
          curve: Motion.standard,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: selected
                  ? colors.primary
                  : expanded
                  ? colors.primary.withValues(alpha: 0.5)
                  : colors.outlineVariant,
              width: selected ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onToggle,
              borderRadius: AppRadius.card,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isDirect ? colors.secondary : colors.tertiary)
                                    .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDirect
                                    ? Icons.check_circle_rounded
                                    : Icons.swap_horiz_rounded,
                                size: 14,
                                color: isDirect
                                    ? colors.secondary
                                    : colors.tertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                option.type.label,
                                style: text.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isDirect
                                      ? colors.secondary
                                      : colors.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          Fmt.duration(option.durationMinutes),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.login_rounded,
                          size: 15,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          GtfsTime.toHm(option.departAt),
                          style: text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: colors.outline,
                          ),
                        ),
                        Icon(
                          Icons.logout_rounded,
                          size: 15,
                          color: colors.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          GtfsTime.toHm(option.arriveAt),
                          style: text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        // Expanded + ellipsis: ocupa el espacio restante alineado
                        // a la derecha y no desborda en pantallas angostas ni con
                        // tipografía grande (escalado de accesibilidad).
                        Expanded(
                          child: Text(
                            _walkSummary(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: text.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Línea(s) que vas a tomar.
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Línea${option.legs.where((l) => l.isBus).length > 1 ? 's que vas a tomar' : ' que vas a tomar'}:',
                            style: text.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          for (var i = 0; i < option.legs.length; i++)
                            if (option.legs[i].isBus)
                              _LineBadge(
                                leg: option.legs[i],
                                alternativeColor: legAltColors[i],
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Instrucciones paso a paso: caminata, micro, transbordo...
                    Text(
                      'Pasos del viaje:',
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < option.legs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LegTile(
                          leg: option.legs[i],
                          option: option,
                          index: i,
                          alternativeColor: legAltColors[i],
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Solo el coste del pasaje.
                    MetaChip(
                      icon: Icons.payments_outlined,
                      label: isDirect
                          ? 'Bs 3.50 · 1 pasaje'
                          : 'Bs 7.00 · 2 pasajes',
                      color: isDirect ? AppColors.success : colors.tertiary,
                      background:
                          (isDirect ? AppColors.success : colors.tertiary)
                              .withValues(alpha: 0.1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _walkSummary() {
    final to = option.walkToStop?.distanceMeters ?? 0;
    final from = option.walkFromStop?.distanceMeters ?? 0;
    final total = to + from;
    return total > 0 ? 'caminando ${Fmt.distance(total.toDouble())}' : '';
  }

  /// Calcula colores alternativos para piernas de bus que comparten el mismo
  /// color GTFS, para que no se confundan dos líneas distintas con igual color.
  /// Devuelve un mapa: índice en [legs] → color alternativo (hex sin #).
  static Map<int, String> alternativeRouteColorsForLegs(List<JourneyLeg> legs) {
    final busLegs = legs.where((l) => l.isBus).toList();
    final colorCounts = <String, int>{};
    for (final leg in busLegs) {
      final c = leg.routeColor ?? '64748B';
      colorCounts[c] = (colorCounts[c] ?? 0) + 1;
    }
    final repeatedColors = colorCounts.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toSet();
    final alternativeColors = _alternativeRouteColors();
    int altIndex = 0;
    final legAltColors = <int, String>{};
    for (var i = 0; i < busLegs.length; i++) {
      final leg = busLegs[i];
      final c = leg.routeColor ?? '64748B';
      if (repeatedColors.contains(c)) {
        legAltColors[legs.indexOf(leg)] =
            alternativeColors[altIndex % alternativeColors.length];
        altIndex++;
      }
    }
    return legAltColors;
  }

  /// Paleta de colores alternativos para distinguir líneas con el mismo
  /// color GTFS cuando hay transbordo entre ellas.
  static List<String> _alternativeRouteColors() => const [
    'E53935', // rojo
    '1E88E5', // azul
    '43A047', // verde
    'FB8C00', // naranja
    '8E24AA', // púrpura
    'D81B60', // rosa
    '00ACC1', // cian
    '7CB342', // verde claro
    'FDD835', // amarillo
    '6D4C41', // marrón
  ];
}

/// Píldora de una línea del viaje: «Línea 101» sobre el color GTFS de la
/// ruta, con el ícono del micro. El número/nombre solo no dice nada a quien
/// no conoce el sistema; la palabra «Línea» lo hace obvio.
class _LineBadge extends StatelessWidget {
  const _LineBadge({required this.leg, this.alternativeColor});

  final JourneyLeg leg;
  final String? alternativeColor;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.fromHex(
      alternativeColor ?? leg.routeColor ?? '64748B',
    );
    // El color de la línea es arbitrario (hay casi blancos y casi negros):
    // la tinta sale de `onColor`, nunca fija en blanco.
    final foreground = AppColors.onColor(background);
    final name = (leg.routeShortName ?? leg.routeId ?? '').trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_bus_rounded, size: 10, color: foreground),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tinte del tramo: gris para caminar, coral para transbordar y el color GTFS
/// de la línea para el bus. Si se pasa `alternativeColor`, se usa en lugar del
/// color GTFS (sirve para distinguir dos líneas con el mismo color).
Color _legTint(JourneyLeg leg, {String? alternativeColor}) =>
    switch (leg.kind) {
      JourneyLegKind.walk => const Color(0xFF64748B),
      JourneyLegKind.transfer => AppColors.accent,
      JourneyLegKind.bus => AppColors.fromHex(
        alternativeColor ?? leg.routeColor ?? '64748B',
      ),
    };

/// Un paso del itinerario, redactado como instrucción, con su número.
class _LegTile extends StatelessWidget {
  const _LegTile({
    required this.leg,
    required this.option,
    required this.index,
    this.alternativeColor,
  });

  final JourneyLeg leg;
  final JourneyOption option;
  final int index;
  final String? alternativeColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final tint = AppColors.legible(
      _legTint(leg, alternativeColor: alternativeColor),
      colors.surface,
      minContrast: 3,
    );
    final isLast = index == option.legs.length - 1;

    final IconData icon;
    Widget titleWidget;
    String? subtitle;

    switch (leg.kind) {
      case JourneyLegKind.walk:
        icon = Icons.directions_walk_rounded;
        final meters = leg.distanceMeters;
        final amount = meters != null && meters > 0
            ? Fmt.distance(meters.toDouble())
            : Fmt.duration(leg.durationMinutes);
        titleWidget = Text('Camina $amount', style: _titleStyle(text));
        if (isLast) {
          subtitle = 'y llegas a tu destino';
        } else if (index == 0) {
          final stop = option.walkToStop?.name.trim() ?? '';
          subtitle = stop.isEmpty ? 'hasta la parada' : 'hasta «$stop»';
        } else {
          subtitle = 'hasta la siguiente parada';
        }
      case JourneyLegKind.transfer:
        icon = Icons.swap_horiz_rounded;
        final stop = _previousBusStopName();
        titleWidget = Text(
          stop.isEmpty ? 'Bájate aquí' : 'Bájate en «$stop»',
          style: _titleStyle(text),
        );
        subtitle = null;
      case JourneyLegKind.bus:
        icon = Icons.directions_bus_rounded;
        final routeColorHex = alternativeColor ?? leg.routeColor ?? '64748B';
        final routeColor = AppColors.fromHex(routeColorHex);
        final name = (leg.routeShortName ?? leg.routeId ?? '').trim();
        titleWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sube a la ', style: _titleStyle(text)),
            Expanded(
              child: Text(
                name,
                style: (_titleStyle(text) ?? const TextStyle()).copyWith(
                  color: routeColor,
                  fontWeight: FontWeight.w900,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        );
        final to = leg.toStop?.name.trim() ?? '';
        subtitle = to.isEmpty ? null : 'bájate en «$to»';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(6, 2, 0, isLast ? 2 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 3),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: text.labelSmall?.copyWith(
                      color: AppColors.onColor(tint),
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: tint),
                        const SizedBox(width: 6),
                        Flexible(child: titleWidget),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle? _titleStyle(TextTheme text) =>
      text.titleSmall?.copyWith(height: 1.3, fontWeight: FontWeight.w700);

  /// Nombre de la parada donde se cambia: la bajada del último micro anterior.
  String _previousBusStopName() {
    for (var i = index - 1; i >= 0; i--) {
      final prev = option.legs[i];
      if (prev.isBus) return prev.toStop?.name.trim() ?? '';
    }
    return '';
  }
}
