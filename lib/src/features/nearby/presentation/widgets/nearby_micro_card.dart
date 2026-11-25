import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../../core/widgets/route_photo.dart';
import '../../domain/nearby_micros.dart';

/// Tarjeta de una línea que pasa cerca del punto consultado.
///
/// Lectura de arriba abajo: QUÉ micro (foto, numeral en su color y trayecto),
/// DÓNDE subo (la parada más cercana y cuánto se camina) y EN QUÉ SENTIDO
/// (los botones Ida/Vuelta, cada uno con la distancia a SU parada, porque la
/// ida y la vuelta suelen pasar por calles distintas). Elegida, la tarjeta se
/// tiñe del color de la línea y muestra hacia dónde va ese sentido.
///
/// Es de props/callbacks: la selección vive en `nearbySelectionProvider`.
class NearbyMicroCard extends StatelessWidget {
  const NearbyMicroCard({
    super.key,
    required this.micro,
    required this.selectedDirection,
    required this.onTap,
    required this.onSelectDirection,
    required this.onOpenRoute,
    this.headsign,
  });

  final NearbyMicro micro;

  /// Sentido dibujado en el mapa si ESTA línea es la elegida; `null` si no.
  final int? selectedDirection;

  /// Hacia dónde va el sentido elegido (headsign del feed), si ya se conoce.
  final String? headsign;

  final VoidCallback onTap;
  final ValueChanged<int> onSelectDirection;
  final VoidCallback onOpenRoute;

  bool get _selected => selectedDirection != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final route = micro.route;
    final accent = AppColors.fromHex(route.color);
    final fill = _selected
        ? AppColors.tint(accent, colors.surface, 0.1)
        : colors.surface;
    final accentInk = AppColors.legible(accent, fill);
    final boarding = _selected
        ? micro.boardingFor(selectedDirection!) ?? micro.nearest
        : micro.nearest;
    final longName = route.longName?.trim();

    return PressScale(
      child: AnimatedContainer(
        key: ValueKey('nearby-micro-${route.id}'),
        duration: Motion.morph,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _selected ? accentInk : colors.outlineVariant,
            width: _selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: _selected ? 0.14 : 0.06),
              blurRadius: _selected ? 18 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MicroFace(color: accent, imageUrl: route.imageUrl),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                RouteBadge(
                                  label: route.shortName,
                                  colorHex: route.color,
                                  size: RouteBadgeSize.small,
                                  // Mismo prefijo que lee el detalle con
                                  // `?from=nearby`: el badge vuela hasta él.
                                  heroTag: 'route-badge-nearby-${route.id}',
                                ),
                                const Spacer(),
                                _DistanceTag(
                                  meters: micro.distanceMeters,
                                  ink: accentInk,
                                ),
                              ],
                            ),
                            if (longName != null && longName.isNotEmpty) ...[
                              const SizedBox(height: AppSpace.xs),
                              Text(
                                longName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpace.xs),
                            _BoardingLine(boarding: boarding),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      for (final directionId in const [0, 1]) ...[
                        if (directionId == 1)
                          const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: _DirectionPill(
                            key: ValueKey(
                              'nearby-dir-${route.id}-$directionId',
                            ),
                            directionId: directionId,
                            boarding: micro.boardingFor(directionId),
                            selected: selectedDirection == directionId,
                            accent: accent,
                            background: fill,
                            onTap: () => onSelectDirection(directionId),
                          ),
                        ),
                      ],
                    ],
                  ),
                  AnimatedSize(
                    duration: Motion.morph,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _selected
                        ? _SelectedFooter(
                            headsign: headsign,
                            ink: accentInk,
                            onOpenRoute: onOpenRoute,
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Foto real del micro o, si la línea no tiene, una placa con su color.
class _MicroFace extends StatelessWidget {
  const _MicroFace({required this.color, required this.imageUrl});

  final Color color;
  final String? imageUrl;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.tile);
    final url = imageUrl;
    return SizedBox.square(
      dimension: _size,
      child: ClipRRect(
        borderRadius: radius,
        child: url == null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      Color.lerp(color, context.colors.shadow, 0.4)!,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.directions_bus_rounded,
                  size: 26,
                  color: AppColors.onColor(color),
                ),
              )
            : RoutePhoto(url: url, width: _size, height: _size, radius: radius),
      ),
    );
  }
}

/// «A 120 m» en el color legible de la línea.
class _DistanceTag extends StatelessWidget {
  const _DistanceTag({required this.meters, required this.ink});

  final double meters;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.near_me_rounded, size: 14, color: ink),
        const SizedBox(width: 2),
        Text(
          formatNearbyDistance(meters),
          style: context.text.labelMedium?.copyWith(
            color: ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// «🚶 2 min · Av. Busch y 3er anillo»: dónde se sube y cuánto se camina.
class _BoardingLine extends StatelessWidget {
  const _BoardingLine({required this.boarding});

  final NearbyBoarding boarding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Row(
      children: [
        Icon(
          Icons.directions_walk_rounded,
          size: 15,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: 2),
        Text(
          '${boarding.walkMinutes} min',
          style: style?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(' · ', style: style),
        Expanded(
          child: Text(
            boarding.stopName.isEmpty ? 'Parada sin nombre' : boarding.stopName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Botón de UN sentido: «Ida → · a 120 m». Elegido se rellena del color de la
/// línea; si ese sentido no pasa cerca, queda apagado y no se toca.
class _DirectionPill extends StatelessWidget {
  const _DirectionPill({
    super.key,
    required this.directionId,
    required this.boarding,
    required this.selected,
    required this.accent,
    required this.background,
    required this.onTap,
  });

  final int directionId;
  final NearbyBoarding? boarding;
  final bool selected;
  final Color accent;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final available = boarding != null;
    final label = directionId == 0 ? 'Ida' : 'Vuelta';
    final fill = selected ? accent : AppColors.tint(accent, background, 0.1);
    final ink = selected
        ? AppColors.onColor(accent)
        : AppColors.legible(accent, fill);
    final detail = !available
        ? 'No pasa cerca'
        : boarding!.confirmed
        ? 'a ${formatNearbyDistance(boarding!.distanceMeters)}'
        : 'a ${formatNearbyDistance(boarding!.distanceMeters)} · sin confirmar';

    final pill = AnimatedContainer(
      duration: Motion.quick,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: available ? fill : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: available
              ? (selected ? accent : AppColors.legible(accent, background))
                    .withValues(alpha: selected ? 1 : 0.35)
              : colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            directionId == 0 ? Icons.east_rounded : Icons.west_rounded,
            size: 18,
            color: available ? ink : colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpace.xs + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: available ? ink : colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: available
                        ? ink.withValues(alpha: 0.85)
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_circle_rounded, size: 18, color: ink),
        ],
      ),
    );

    if (!available) {
      return Semantics(
        label: '$label: no pasa cerca',
        child: Opacity(opacity: 0.7, child: pill),
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $detail',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: pill,
      ),
    );
  }
}

/// Pie de la tarjeta elegida: hacia dónde va el sentido y acceso al detalle.
class _SelectedFooter extends StatelessWidget {
  const _SelectedFooter({
    required this.headsign,
    required this.ink,
    required this.onOpenRoute,
  });

  final String? headsign;
  final Color ink;
  final VoidCallback onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final towards = headsign;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, size: 16, color: ink),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(
              towards == null ? 'Sigue las flechas del mapa' : 'Hacia $towards',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            key: const ValueKey('nearby-open-route'),
            onPressed: onOpenRoute,
            style: TextButton.styleFrom(
              foregroundColor: ink,
              visualDensity: VisualDensity.compact,
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Ver línea'),
          ),
        ],
      ),
    );
  }
}
