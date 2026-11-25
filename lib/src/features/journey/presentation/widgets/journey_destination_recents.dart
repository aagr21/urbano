// Piezas de la sección «Tus destinos recientes» de la hoja de destino
// (showJourneyDestinationSheet): cabecera con contador, aviso vacío y
// paginación. Solo props/callbacks; la página actual vive en la hoja.

import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius, AppSpace;
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';

/// Encabezado de la sección de destinos recientes.
class DestinationRecentsHeader extends StatelessWidget {
  const DestinationRecentsHeader({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppColors.tint(
      HtmlDesignTokens.emerald600,
      colors.surface,
      dark ? 0.18 : 0.1,
    );
    final ink = AppColors.legible(HtmlDesignTokens.emerald600, fill);

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(Icons.history_rounded, size: 16, color: ink),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            'Tus destinos recientes',
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$count',
            style: text.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// Aviso discreto cuando todavía no hay historial ni viajes guardados.
class DestinationRecentsEmpty extends StatelessWidget {
  const DestinationRecentsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg + AppSpace.xs),
      child: Row(
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 16,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              'Tus destinos recientes aparecerán aquí.',
              style: context.text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Controles de paginación con flechas e indicador de página (`page` va
/// desde 0). Una flecha sin página a la que ir queda deshabilitada.
class DestinationRecentsPagination extends StatelessWidget {
  const DestinationRecentsPagination({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canGoPrev = page > 0;
    final canGoNext = page < totalPages - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PressScale(
          scale: 0.95,
          child: IconButton(
            onPressed: canGoPrev ? onPrevious : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: canGoPrev ? colors.primary : colors.outlineVariant,
              size: 26,
            ),
            tooltip: 'Página anterior',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Text(
            '${page + 1} / $totalPages',
            style: context.text.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        PressScale(
          scale: 0.95,
          child: IconButton(
            onPressed: canGoNext ? onNext : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoNext ? colors.primary : colors.outlineVariant,
              size: 26,
            ),
            tooltip: 'Página siguiente',
          ),
        ),
      ],
    );
  }
}
