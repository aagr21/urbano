// Piezas del catálogo de micros (MicrosScreen): orden del catálogo,
// estadísticas del banner y anillos decorativos.

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../core/utils/extensions.dart';

/// Orden del catálogo. Se traduce al `sort` del contrato (`/routes`).
enum CatalogSort {
  number('name', 'número de línea', '1–9'),
  corridor('longName', 'nombre del recorrido', 'A–Z');

  const CatalogSort(this.value, this.label, this.short);

  /// Valor que entiende el backend.
  final String value;

  /// Cómo se lee en la app.
  final String label;

  /// Etiqueta del selector.
  final String short;
}

/// Dato de la banda de identidad (fondo oscuro fijo: la tinta es clara).
class MicrosHeroStat extends StatelessWidget {
  const MicrosHeroStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: HtmlDesignTokens.white,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.labelSmall?.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: HtmlDesignTokens.emerald200,
          ),
        ),
      ],
    );
  }
}

class MicrosHeroDivider extends StatelessWidget {
  const MicrosHeroDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: HtmlDesignTokens.white.withValues(alpha: 0.14),
    );
  }
}

/// Anillo translúcido de la banda (eco de los anillos de Santa Cruz).
class MicrosHeroRing extends StatelessWidget {
  const MicrosHeroRing({super.key, required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: HtmlDesignTokens.emerald300.withValues(alpha: alpha),
          width: 10,
        ),
      ),
    );
  }
}

/// Selector de orden del catálogo: dos segmentos compactos (`1–9` · `A–Z`).
class MicrosSortSwitch extends StatelessWidget {
  const MicrosSortSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CatalogSort value;
  final ValueChanged<CatalogSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.pill);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final sort in CatalogSort.values)
            MicrosSortOption(
              key: ValueKey('micros-sort-${sort.name}'),
              label: sort.short,
              tooltip: 'Ordenar por ${sort.label}',
              selected: sort == value,
              onTap: () => onChanged(sort),
            ),
        ],
      ),
    );
  }
}

class MicrosSortOption extends StatelessWidget {
  const MicrosSortOption({
    super.key,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.pill);
    final ink = selected
        ? AppColors.legible(colors.primary, colors.surface)
        : colors.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        // Sombra suave en vez de `elevation`: la del Material dibujaba un
        // contorno oscuro duro alrededor de la píldora activa.
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: radius,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                child: Text(
                  label,
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
