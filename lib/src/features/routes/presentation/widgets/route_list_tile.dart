import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../../core/widgets/route_photo.dart';
import '../../data/route_models.dart';

/// Fila de ruta: badge de color + nombre + conteos.
///
/// Entra con [Reveal] (escalonado por [index]) y se hunde al pulsar
/// ([PressScale]).
class RouteListTile extends StatelessWidget {
  const RouteListTile({
    super.key,
    required this.route,
    this.onTap,
    this.heroPrefix,
    this.trailing,
    this.showDescription = false,
    this.index = 0,
  });

  final RouteSummary route;
  final VoidCallback? onTap;

  /// Prefijo único por pantalla para el Hero del badge
  /// (evita tags duplicados entre ramas del shell).
  final String? heroPrefix;
  final Widget? trailing;
  final bool showDescription;

  /// Posición en la lista: fija cuánto tarda en entrar la fila.
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Reveal(
      index: index,
      stagger: const Duration(milliseconds: 55),
      slide: 10,
      child: PressScale(
        child: Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.card,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.card,
              child: Row(
                children: [
                  // Foto real del micro si existe (micros.csv): miniatura
                  // alineada al badge, con el mismo silueteado del listado.
                  if (route.imageUrl != null) ...[
                    RoutePhoto(
                      url: route.imageUrl!,
                      width: 64,
                      height: 48,
                      radius: BorderRadius.circular(AppRadius.tile),
                    ),
                    const SizedBox(width: AppSpace.md),
                  ],
                  // Flexible con flex 0 (loose): intrínseco pero acotado al
                  // espacio restante — con la foto y nombres largos la fila
                  // no desborda; el texto del badge se elipsea.
                  Flexible(
                    flex: 0,
                    child: RouteBadge(
                      label: route.shortName,
                      colorHex: route.color,
                      textColorHex: route.textColor,
                      size: RouteBadgeSize.large,
                      heroTag: heroPrefix == null
                          ? null
                          : 'route-badge-$heroPrefix-${route.id}',
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.longName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(height: 1.25),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (route.directionsCount > 0)
                              MetaChip(
                                icon: Icons.swap_horiz_rounded,
                                label: route.directionsCount > 1
                                    ? 'Ida y vuelta'
                                    : 'Solo ida',
                              ),
                            if (showDescription && route.description.isNotEmpty)
                              MetaChip(label: route.description),
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(Icons.chevron_right_rounded, color: colors.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
