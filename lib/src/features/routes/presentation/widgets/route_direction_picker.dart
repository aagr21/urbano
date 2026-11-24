import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/route_models.dart';
import 'route_detail_hero.dart';

/// Extremos de un sentido: el `headsign` del sentido es su destino y el del
/// sentido contrario, su origen. `null` si el feed no los nombra (solo
/// «Ida»/«Vuelta») o si la línea tiene un único sentido.
(String, String)? directionEndpoints(RouteDetail detail, int directionId) {
  if (detail.directions.length < 2) return null;
  final active = detail.directionById(directionId);
  if (active == null) return null;
  final other = detail.directions.firstWhere(
    (d) => d.directionId != active.directionId,
    orElse: () => active,
  );
  if (!isNamedHeadsign(active.headsign) || !isNamedHeadsign(other.headsign)) {
    return null;
  }
  if (active.headsign.trim() == other.headsign.trim()) return null;
  return (other.headsign.trim(), active.headsign.trim());
}

/// `true` si el `headsign` nombra un lugar (no es el genérico «Ida»/«Vuelta»).
bool isNamedHeadsign(String value) {
  final v = value.trim().toLowerCase();
  return v.isNotEmpty && v != 'ida' && v != 'vuelta';
}

/// Selector de sentido: el ÚNICO control de ida/vuelta del detalle.
///
/// Una cápsula compacta con dos mitades escritas como las piensa el pasajero
/// («Hacia Centro» / «Hacia El Mechero»); la elegida se rellena con el color
/// de la línea. Cambiarla cambia el estado, el horario, el mapa y el
/// recorrido. Si el feed no nombra los extremos se lee «Ida» / «Vuelta».
class RouteDirectionPicker extends StatelessWidget {
  const RouteDirectionPicker({
    super.key,
    required this.detail,
    required this.value,
    required this.routeColor,
    required this.onChanged,
  });

  final RouteDetail detail;
  final int value;
  final Color routeColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: dark
            ? colors.surfaceContainerHigh
            : colors.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final direction in detail.directions)
            Expanded(
              child: _Segment(
                direction: direction,
                ends: directionEndpoints(detail, direction.directionId),
                selected: direction.directionId == value,
                routeColor: routeColor,
                onTap: () => onChanged(direction.directionId),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.direction,
    required this.ends,
    required this.selected,
    required this.routeColor,
    required this.onTap,
  });

  final RouteDirection direction;
  final (String, String)? ends;
  final bool selected;
  final Color routeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.pill);
    final fill = selected ? routeHeroFill(context, routeColor) : null;
    final ink = fill != null
        ? AppColors.onColor(fill)
        : colors.onSurfaceVariant;
    final label = ends != null
        ? 'Hacia ${ends!.$2}'
        : direction.directionId == 0
        ? 'Ida'
        : 'Vuelta';

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: Motion.quick,
        decoration: BoxDecoration(color: fill, borderRadius: radius),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('route-direction-tab-${direction.directionId}'),
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    direction.directionId == 0
                        ? Icons.arrow_forward_rounded
                        : Icons.arrow_back_rounded,
                    size: 16,
                    color: ink,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: ink,
                      ),
                    ),
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
