import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../../core/widgets/urbano_back_button.dart';
import '../../data/route_models.dart';
import 'micro_bus_art.dart';

/// Flecha de vuelta flotante del mapa a sangre.
///
/// El mapa completo no tiene `AppBar` (el trazado manda), así que la salida es
/// un botón circular oscuro sobre el propio mapa: el mismo gesto de todas las
/// pantallas, sin header que le robe alto al recorrido.
class MapFloatingBack extends StatelessWidget {
  const MapFloatingBack({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: const UrbanoBackButton(color: Colors.white),
    );
  }
}

/// Placa de identidad de la línea sobre el mapa a sangre.
///
/// Muestra el micro ilustrado, el color real del feed, el numeral y el nombre
/// largo junto al sentido activo. Va flotando arriba, al lado de
/// [MapFloatingBack], para que el recorrido se lea sin perder de vista qué
/// línea se está mirando.
class RouteMapPlate extends StatelessWidget {
  const RouteMapPlate({
    super.key,
    required this.detail,
    required this.routeColor,
    this.directionLabel,
  });

  final RouteDetail detail;
  final Color routeColor;

  /// «Ida»/«Vuelta» cuando el recorrido tiene más de un sentido.
  final String? directionLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tinted = AppColors.tint(
      routeColor,
      colors.surface,
      dark ? 0.18 : 0.10,
    );
    final accent = AppColors.legible(routeColor, colors.surface);

    return Material(
      color: colors.surface.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tinted,
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: MicroBusArt(color: routeColor, size: const Size(46, 32)),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Wrap y no Row: con un numeral largo y un sentido escrito,
                  // la placa se parte en dos líneas en vez de desbordar en
                  // móviles angostos.
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RouteBadge(
                        label: detail.shortName,
                        colorHex: detail.color,
                        textColorHex: detail.textColor,
                        size: RouteBadgeSize.small,
                      ),
                      if (directionLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tint(
                              routeColor,
                              colors.surface,
                              0.14,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            directionLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail.longName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
