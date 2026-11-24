import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../data/route_models.dart';
import 'micro_bus_art.dart';

/// Tarjeta de una línea del catálogo `/micros`.
///
/// La identidad de la línea es su **numeral con el color GTFS** ([RouteBadge]),
/// no un ícono genérico: es lo que el pasajero busca y lo que viaja con un
/// [Hero] hasta la cabecera del detalle. Al lado, el recorrido y los datos que
/// sí cambian de línea a línea (paradas, sentidos); debajo, los extremos reales
/// del recorrido como un riel origen → destino. Toda la tarjeta es el botón:
/// no hay pie «Ver recorrido» que repita lo mismo.
class MicroCard extends StatelessWidget {
  const MicroCard({
    super.key,
    required this.route,
    required this.onTap,
    this.heroPrefix,
  });

  final RouteSummary route;
  final VoidCallback onTap;

  /// Prefijo del [Hero] del badge; debe coincidir con el que usa el detalle
  /// (`?from=micros` ↔ `route-badge-micros-<id>`).
  final String? heroPrefix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.fromHex(route.color);
    final fill = AppColors.tint(accent, colors.surface, dark ? 0.18 : 0.07);
    final ink = AppColors.legible(accent, fill);
    final keyStops = route.keyStops;
    final hasEnds = keyStops != null && keyStops.length >= 2;
    final radius = BorderRadius.circular(AppRadius.lg);

    final facts = <String>[
      if (route.stopCount > 0) '${route.stopCount} paradas',
      if (route.directionsCount > 1)
        'Ida y vuelta'
      else if (route.directionsCount == 1)
        'Solo ida',
    ];

    return PressScale(
      scale: 0.985,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: dark ? 0.22 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: colors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: dark
                  ? AppColors.lineDark
                  : colors.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                // Filete del color real de la línea: la tarjeta se reconoce
                // de un vistazo sin leer el numeral. El `Material` recorta
                // sus esquinas, así no asoma fuera del borde redondeado.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: accent,
                    child: const SizedBox(width: 5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.md + 5,
                    AppSpace.md,
                    AppSpace.md,
                    AppSpace.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RouteBadge(
                            label: route.shortName,
                            colorHex: route.color,
                            textColorHex: route.textColor,
                            size: RouteBadgeSize.large,
                            heroTag: heroPrefix == null
                                ? null
                                : 'route-badge-$heroPrefix-${route.id}',
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  route.longName.isNotEmpty
                                      ? route.longName
                                      : route.shortName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    color: colors.onSurface,
                                  ),
                                ),
                                if (facts.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    facts.join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          _BusPlate(accent: accent, fill: fill),
                        ],
                      ),
                      // Extremos reales del recorrido (primeras/últimas
                      // paradas del feed). Sin ellas la tarjeta no
                      // inventa un trayecto: lo de arriba ya la
                      // identifica.
                      if (hasEnds) ...[
                        const SizedBox(height: AppSpace.md),
                        _EndpointsRail(
                          origin: _shortStopName(keyStops.first),
                          destination: _shortStopName(keyStops.last),
                          via: keyStops.length > 2
                              ? _shortStopName(keyStops[1])
                              : null,
                          accent: accent,
                          fill: fill,
                          ink: ink,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Micro ilustrado con el color de la línea sobre una placa tonal: sustituye
/// el chevron y el pie «Ver recorrido» como firma de «esto se abre».
class _BusPlate extends StatelessWidget {
  const _BusPlate({required this.accent, required this.fill});

  final Color accent;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: MicroBusArt(color: accent, size: const Size(38, 26)),
    );
  }
}

/// Riel origen → destino con los extremos del recorrido sobre el tinte de la
/// línea. Con una tercera parada clave se lee «vía …» debajo.
class _EndpointsRail extends StatelessWidget {
  const _EndpointsRail({
    required this.origin,
    required this.destination,
    required this.accent,
    required this.fill,
    required this.ink,
    this.via,
  });

  final String origin;
  final String destination;
  final String? via;
  final Color accent;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final label = text.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: colors.onSurface,
    );
    final caption = text.labelSmall?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: ink,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('DESDE', style: caption)),
              const SizedBox(width: 28),
              Expanded(
                child: Text('HASTA', textAlign: TextAlign.end, style: caption),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.trip_origin_rounded, size: 13, color: ink),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  origin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: label,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.double_arrow_rounded, size: 16, color: ink),
              ),
              Expanded(
                child: Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: label,
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.location_on_rounded, size: 14, color: ink),
            ],
          ),
          if (via != null && via != origin && via != destination) ...[
            const SizedBox(height: 3),
            Text(
              'vía $via',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Acorta nombres largos de paradas extrayendo el tramo principal
/// («Avenida Los Pinos esquina Calle Las Palmeras» → «Avenida Los Pinos»).
String _shortStopName(String name) {
  if (name.isEmpty) return name;
  final parts = name.split(' esquina ');
  if (parts.length >= 2) return parts[0];
  if (name.length > 30) {
    final words = name.split(' ');
    if (words.length > 3) return '${words.take(3).join(' ')}…';
  }
  return name;
}
