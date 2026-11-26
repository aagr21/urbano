import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../routes/data/route_models.dart';
import '../../application/leg_stroke_colors.dart';
import '../../data/journey_models.dart';
import 'journey_micro_gallery.dart';

/// Tarjeta de opción de viaje con timeline expandible de tramos.
class JourneyOptionCard extends StatelessWidget {
  const JourneyOptionCard({
    super.key,
    required this.option,
    required this.expanded,
    required this.onToggle,
    this.index = 0,
    this.selected = false,
    this.routes = const {},
  });

  final JourneyOption option;
  final bool expanded;
  final VoidCallback onToggle;
  final int index;

  /// `true` si esta opción es la visible en el mapa de resultados.
  final bool selected;

  /// Ficha de cada línea por `routeId` (foto del micro, trayecto). Llega
  /// después que la respuesta de `/journey`: mientras tanto (o si falla) la
  /// galería pinta placas del color de cada línea.
  final Map<String, RouteSummary> routes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final isDirect = option.type == JourneyType.direct;
    final typeColor = isDirect ? colors.secondary : colors.tertiary;

    // Colores de ruta que se repiten entre micros: asignar color alternativo
    // para que no se confundan dos líneas distintas con el mismo color GTFS.
    final legAltColors = LegStrokeColors.forLegs(option.legs);

    // La opción dibujada en el mapa se distingue por un velo muy tenue del
    // primario además del borde: se lee de un vistazo sin gritar.
    final fill = selected
        ? Color.lerp(colors.surface, colors.primary, 0.05)!
        : colors.surface;

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
            color: fill,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: selected
                  ? colors.primary
                  : expanded
                  ? colors.primary.withValues(alpha: 0.5)
                  : colors.outlineVariant,
              width: selected ? 1.6 : 1.0,
            ),
            boxShadow: AppTheme.softShadow(
              opacity: selected ? 0.08 : 0.04,
              blur: 12,
              dy: 3,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onToggle,
              borderRadius: AppRadius.card,
              child: Padding(
                padding: AppSpace.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Duración (lo que más se compara) + tipo + chevron.
                    Row(
                      children: [
                        Text(
                          Fmt.duration(option.durationMinutes),
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        // Expanded + chip con elipsis: con fuente grande o
                        // pantalla angosta el chip cede antes que desbordar.
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _TypeChip(
                              label: option.type.label,
                              icon: isDirect
                                  ? Icons.check_circle_rounded
                                  : Icons.swap_horiz_rounded,
                              color: typeColor,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: Motion.duration(context, Motion.base),
                          curve: Motion.standard,
                          child: Icon(
                            Icons.expand_more_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xs),
                    _ScheduleRow(option: option),
                    const SizedBox(height: AppSpace.md),
                    // Los micros del viaje, en foto: se reconoce la opción por
                    // el micro que se va a ver llegar, no solo por un número.
                    JourneyMicroGallery(
                      option: option,
                      alternativeColors: legAltColors,
                      routes: routes,
                      heroScope: '$index',
                    ),
                    const SizedBox(height: AppSpace.md),
                    _MetaRow(
                      walkMeters: _walkMeters(),
                      fareLabel: isDirect
                          ? 'Bs 3.50 · 1 pasaje'
                          : 'Bs 7.00 · 2 pasajes',
                    ),
                    // El paso a paso solo vive en la tarjeta abierta: cerradas,
                    // las opciones se comparan sin un muro de instrucciones.
                    AnimatedSize(
                      duration: Motion.duration(context, Motion.base),
                      curve: Motion.standard,
                      alignment: Alignment.topCenter,
                      child: expanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: AppSpace.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Divider(
                                    height: 1,
                                    color: colors.outlineVariant.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.md),
                                  for (var i = 0; i < option.legs.length; i++)
                                    _LegTile(
                                      leg: option.legs[i],
                                      option: option,
                                      index: i,
                                      alternativeColor: legAltColors[i],
                                    ),
                                ],
                              ),
                            )
                          : const SizedBox(width: double.infinity),
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

  int _walkMeters() {
    final to = option.walkToStop?.distanceMeters ?? 0;
    final from = option.walkFromStop?.distanceMeters ?? 0;
    return to + from;
  }
}

/// Píldora del tipo de viaje («Directo» / «1 transbordo») sobre un tinte.
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = Color.lerp(colors.surface, color, 0.14)!;
    final ink = AppColors.legible(color, fill);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ink),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horario de salida → llegada, con los íconos de subir y bajar.
class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.option});

  final JourneyOption option;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        Icon(Icons.login_rounded, size: 15, color: colors.primary),
        const SizedBox(width: AppSpace.xs),
        Text(GtfsTime.toHm(option.departAt), style: style),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 14,
            color: colors.outline,
          ),
        ),
        Icon(Icons.logout_rounded, size: 15, color: colors.tertiary),
        const SizedBox(width: AppSpace.xs),
        Text(GtfsTime.toHm(option.arriveAt), style: style),
      ],
    );
  }
}

/// Pie de la tarjeta: caminata total y pasaje, en una sola línea discreta.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.walkMeters, required this.fareLabel});

  final int walkMeters;
  final String fareLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    Widget item(IconData icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.onSurfaceVariant),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: AppSpace.lg,
      runSpacing: AppSpace.xs,
      children: [
        if (walkMeters > 0)
          item(
            Icons.directions_walk_rounded,
            '${Fmt.distance(walkMeters.toDouble())} a pie',
          ),
        item(Icons.payments_outlined, fareLabel),
      ],
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

    // Riel de la línea de tiempo: une este paso con el siguiente en el color
    // del tramo (más tenue a pie), así el viaje se lee como un recorrido y no
    // como una lista suelta.
    final railColor = leg.kind == JourneyLegKind.walk
        ? colors.outlineVariant
        : tint.withValues(alpha: 0.55);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
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
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: railColor,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: isLast ? 0 : 14),
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
