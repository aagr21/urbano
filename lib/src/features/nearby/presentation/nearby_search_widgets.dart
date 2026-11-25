// Piezas de presentación de la hoja de búsqueda de «Lugares»
// (showNearbySearchSheet): título, accesos rápidos, filas y barra de envío.

import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../domain/nearby_micros.dart';

/// Punto elegido en la hoja (aún sin radio).
class NearbyPickedPlace {
  const NearbyPickedPlace({
    required this.label,
    required this.lat,
    required this.lon,
    required this.icon,
    this.detail,
  });

  final String label;
  final double lat;
  final double lon;
  final IconData icon;

  /// Segunda línea: categoría, zona o coordenadas.
  final String? detail;

  NearbyPickedPlace withLabel(String label) => NearbyPickedPlace(
    label: label,
    lat: lat,
    lon: lon,
    icon: icon,
    detail: detail,
  );
}

/// Placa + «¿Qué micro pasa cerca?» + bajada.
class NearbySearchTitle extends StatelessWidget {
  const NearbySearchTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final plate = AppColors.tint(AppColors.success, colors.surface);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: plate,
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: Icon(
            Icons.share_location_rounded,
            color: AppColors.legible(AppColors.success, plate),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Qué micro pasa cerca?',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Elige un punto y te mostramos las líneas y su sentido.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Atajo grande: «Mi ubicación» / «Marcar en el mapa».
class NearbyQuickAction extends StatelessWidget {
  const NearbyQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = AppColors.tint(colors.primary, colors.surface, 0.1);
    final ink = AppColors.legible(colors.primary, fill);
    return PressScale(
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: busy ? null : onTap,
          child: Padding(
            // Relleno lateral corto: con la mitad del ancho de un teléfono,
            // «Marcar en el mapa» no entraba y se cortaba en «Marcar en el …».
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm + 2,
              vertical: AppSpace.md,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: busy
                      ? Icon(Icons.more_horiz_rounded, size: 20, color: ink)
                      : Icon(icon, size: 20, color: ink),
                ),
                const SizedBox(width: AppSpace.xs + 2),
                // Se achica antes que cortarse (pantallas angostas o letra
                // grande del sistema): un acceso a medio leer no se entiende.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: context.text.labelLarge?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class NearbySectionLabel extends StatelessWidget {
  const NearbySectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xs,
        AppSpace.sm,
        AppSpace.xs,
        AppSpace.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class NearbyHintRow extends StatelessWidget {
  const NearbyHintRow({super.key, required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: AppSpace.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de un lugar o parada; elegida, se marca con el color primario.
class NearbyPlaceRow extends StatelessWidget {
  const NearbyPlaceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final fill = selected
        ? AppColors.tint(colors.primary, colors.surface, 0.12)
        : Colors.transparent;
    final plate = AppColors.tint(colors.primary, colors.surface, 0.1);
    // El resaltado lo pinta el propio ListTile (`selectedTileColor`) sobre el
    // Material de la hoja: una caja de color por encima taparía su ripple.
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: onTap,
        dense: true,
        selected: selected,
        selectedTileColor: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: plate,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.legible(colors.primary, plate),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        trailing: selected
            ? Icon(
                Icons.check_circle_rounded,
                color: AppColors.legible(colors.primary, fill),
              )
            : null,
      ),
    );
  }
}

/// Pie fijo: el punto elegido, el radio y «Buscar cerca».
class NearbySubmitBar extends StatelessWidget {
  const NearbySubmitBar({
    super.key,
    required this.picked,
    required this.radius,
    required this.onRadius,
    required this.onSubmit,
    required this.bottomInset,
    required this.colors,
    required this.text,
  });

  final NearbyPickedPlace? picked;
  final int radius;
  final ValueChanged<int> onRadius;
  final VoidCallback onSubmit;
  final double bottomInset;
  final ColorScheme colors;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final current = picked;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.lg + 4,
          AppSpace.md,
          AppSpace.lg + 4,
          bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: Motion.fade,
              child: current == null
                  ? Text(
                      'Elige un lugar de la lista, tu ubicación o un punto '
                      'del mapa.',
                      key: const ValueKey('nearby-picked-empty'),
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : Row(
                      key: ValueKey('nearby-picked-${current.label}'),
                      children: [
                        Icon(
                          current.icon,
                          size: 20,
                          color: AppColors.legible(
                            AppColors.accent,
                            colors.surface,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            current.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.xs + 2,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.xs),
                  child: Text(
                    'Radio',
                    style: text.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final r in kNearbyRadii)
                  ChoiceChip(
                    key: ValueKey('nearby-sheet-radius-$r'),
                    label: Text(formatNearbyDistance(r.toDouble())),
                    selected: r == radius,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onRadius(r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            FilledButton.icon(
              key: const ValueKey('nearby-submit'),
              onPressed: current == null ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
              ),
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('Buscar cerca'),
            ),
          ],
        ),
      ),
    );
  }
}
