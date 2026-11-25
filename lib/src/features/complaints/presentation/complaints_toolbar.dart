// Barra de filtros por categoría y botón de orden del feed de quejas.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../application/complaints_feed_controller.dart';
import 'widgets/complaint_chips.dart';

/// Fila de filtros por motivo: solo los motivos que tienen reportes.
///
/// Se oculta con un solo motivo en juego (no hay nada que elegir) y con el feed
/// sin cargar, para que la fila no aparezca y desaparezca bajo el dedo.
class ComplaintsCategoryFilterBar extends ConsumerWidget {
  const ComplaintsCategoryFilterBar({super.key, required this.on});

  /// Fondo real sobre el que se pintan las pastillas (mide el contraste).
  final Color on;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reported = ref.watch(reportedCategoriesProvider);
    if (reported.length < 2) return const SizedBox.shrink();
    final colors = context.colors;
    final filter = ref.watch(complaintCategoryFilterProvider);
    final notifier = ref.read(complaintCategoryFilterProvider.notifier);
    final counts = ref.watch(complaintCategoryCountsProvider);
    final total = counts.values.fold(0, (sum, n) => sum + n);

    return SizedBox(
      // Barra delgada: cada píxel entre la cabecera y el listado es una línea
      // menos de la primera queja (las pastillas miden ~30).
      height: 42,
      child: Stack(
        children: [
          ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            children: [
              ComplaintPill(
                label: 'Todas',
                icon: Icons.apps_rounded,
                accent: colors.primary,
                on: on,
                emphasized: filter == null,
                count: total,
                onTap: () => notifier.state = null,
              ),
              for (final category in reported) ...[
                const SizedBox(width: AppSpace.sm),
                CategoryChip(
                  category: category,
                  on: on,
                  selected: filter == category,
                  count: counts[category],
                  // Tocarlo de nuevo lo quita: el filtro es un toggle, no un
                  // callejón.
                  onTap: () =>
                      notifier.state = filter == category ? null : category,
                ),
              ],
            ],
          ),
          // El contenido se desvanece en el borde: así se entiende que la fila
          // sigue y que la pastilla cortada se puede arrastrar.
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: AppSpace.xl,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [on, on.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector de orden del feed: una pastilla con el orden activo que abre un
/// menú con las tres opciones (la elegida con ✓).
class ComplaintsSortButton extends ConsumerWidget {
  const ComplaintsSortButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sort = ref.watch(complaintSortProvider);
    final surface = colors.surfaceContainerLowest;
    final fill = AppColors.tint(colors.primary, surface, 0.1);
    final ink = AppColors.legible(colors.primary, fill);
    return PopupMenuButton<ComplaintSort>(
      key: const ValueKey('complaints-sort'),
      tooltip: 'Ordenar',
      initialValue: sort,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (value) {
        HapticFeedback.selectionClick();
        ref.read(complaintSortProvider.notifier).state = value;
      },
      itemBuilder: (context) => [
        for (final option in ComplaintSort.values)
          PopupMenuItem<ComplaintSort>(
            value: option,
            child: Row(
              children: [
                Icon(option.icon, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: AppSpace.md),
                Expanded(child: Text(option.label)),
                if (option == sort)
                  Icon(Icons.check_rounded, size: 18, color: colors.primary),
              ],
            ),
          ),
      ],
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm + 2,
          AppSpace.xs + 1,
          AppSpace.sm,
          AppSpace.xs + 1,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sort.icon, size: 14, color: ink),
            const SizedBox(width: AppSpace.xs),
            Text(
              sort.label,
              style: context.text.labelMedium?.copyWith(
                color: ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: ink),
          ],
        ),
      ),
    );
  }
}
