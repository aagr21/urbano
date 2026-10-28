import 'package:flutter/material.dart';

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
            // iOS: seleccionada lleva acento; en reposo nada de bordes ni sombra.
            border: selected
                ? Border.all(color: colors.primary, width: 1.6)
                : expanded
                ? Border.all(color: colors.primary.withValues(alpha: 0.5))
                : null,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (selected)
                          MetaChip(
                            icon: Icons.map_rounded,
                            label: 'En el mapa',
                            color: colors.primary,
                            background: colors.primary.withValues(alpha: 0.1),
                          ),
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
                        for (final leg in option.legs)
                          if (leg.isBus)
                            RouteBadge(
                              label:
                                  leg.routeShortName ?? leg.routeId ?? 'Micro',
                              colorHex: leg.routeColor ?? '64748B',
                              size: RouteBadgeSize.small,
                            )
                          else if (leg.isWalk)
                            MetaChip(
                              icon: Icons.directions_walk_rounded,
                              label: Fmt.distance(
                                leg.distanceMeters?.toDouble(),
                              ),
                            ),
                      ],
                    ),
                    AnimatedSize(
                      duration: Motion.morph,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: expanded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                Text(
                                  'Tu viaje paso a paso',
                                  style: text.labelMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _Timeline(option: option),
                              ],
                            )
                          : const SizedBox(width: double.infinity, height: 0),
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
}

/// Timeline vertical de los tramos (walk / bus / transbordo).
class _Timeline extends StatelessWidget {
  const _Timeline({required this.option});

  final JourneyOption option;

  @override
  Widget build(BuildContext context) {
    final legs = option.legs;

    return Column(
      children: [
        for (var i = 0; i < legs.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 34,
                  child: Column(
                    children: [
                      // Cada segmento toma el color del tramo que representa:
                      // la línea cambia sola cuando hay transbordo, igual que
                      // en un diagrama de red.
                      if (i > 0)
                        Expanded(child: _LegRail(color: _legTint(legs[i - 1]))),
                      _LegDot(leg: legs[i]),
                      if (i < legs.length - 1)
                        Expanded(child: _LegRail(color: _legTint(legs[i]))),
                    ],
                  ),
                ),
                Expanded(
                  child: _LegTile(leg: legs[i], option: option),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tinte del tramo: gris para caminar, coral para transbordar y el color GTFS
/// de la línea para el bus.
Color _legTint(JourneyLeg leg) => switch (leg.kind) {
  JourneyLegKind.walk => const Color(0xFF64748B),
  JourneyLegKind.transfer => AppColors.accent,
  JourneyLegKind.bus => AppColors.fromHex(leg.routeColor),
};

/// Segmento de riel: la caja la fija el `Expanded` del padre (altura apretada),
/// así que el pintado en fracción **no mueve el layout** — el riel se dibuja de
/// arriba abajo al expandir la tarjeta, como un diagrama de red que se traza.
class _LegRail extends StatelessWidget {
  const _LegRail({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final stroke = AppColors.legible(color, context.colors.surface);
    // Con «reducir animaciones» el Ambient arranca en reposo (t = 1): el riel
    // sale entero sin necesidad de un ramo aparte.
    return Ambient(
      period: Motion.slow,
      cycles: 1,
      builder: (context, t, phase, _) => SizedBox(
        width: 3,
        child: CustomPaint(
          painter: _RailPainter(
            color: stroke,
            fraction: Curves.easeOutCubic.transform(t),
          ),
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({required this.color, required this.fraction});

  final Color color;

  /// 0..1 del tramo ya trazado.
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const radius = Radius.circular(1.5);
    // Guía fantasma de todo el tramo y, encima, la parte recorrida.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = color.withValues(alpha: 0.22),
    );
    final drawn = size.height * fraction;
    if (drawn < 1) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, drawn), radius),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) =>
      old.color != color || old.fraction != fraction;
}

class _LegDot extends StatelessWidget {
  const _LegDot({required this.leg});

  final JourneyLeg leg;

  @override
  Widget build(BuildContext context) {
    final color = _legTint(leg);
    final icon = switch (leg.kind) {
      JourneyLegKind.walk => Icons.directions_walk_rounded,
      JourneyLegKind.transfer => Icons.swap_horiz_rounded,
      JourneyLegKind.bus => Icons.directions_bus_rounded,
    };

    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
        ],
      ),
      // El relleno puede ser el color de una línea del GTFS (`F1C40F` es casi
      // blanco): el ícono lo elige `onColor`, no queda fijo en blanco.
      child: Icon(icon, size: 15, color: AppColors.onColor(color)),
    );
  }
}

class _LegTile extends StatelessWidget {
  const _LegTile({required this.leg, required this.option});

  final JourneyLeg leg;
  final JourneyOption option;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    final title = switch (leg.kind) {
      JourneyLegKind.walk => 'Caminar ${Fmt.duration(leg.durationMinutes)}',
      JourneyLegKind.transfer => 'Transbordo',
      JourneyLegKind.bus => 'Micro ${leg.routeShortName ?? leg.routeId ?? ''}',
    };

    final String subtitle;
    switch (leg.kind) {
      case JourneyLegKind.walk:
        subtitle = Fmt.distance(leg.distanceMeters?.toDouble());
      case JourneyLegKind.transfer:
        subtitle =
            option.legs
                .takeWhile((l) => l != leg)
                .where((l) => l.isBus)
                .isNotEmpty
            ? 'Cambia de micro aquí'
            : 'Cambia de micro';
      case JourneyLegKind.bus:
        subtitle =
            '${GtfsTime.toHm(leg.departAt)} → ${GtfsTime.toHm(leg.arriveAt)}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall?.copyWith(height: 1.3)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
