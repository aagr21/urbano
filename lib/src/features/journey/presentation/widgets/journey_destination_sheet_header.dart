import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius, AppSpace;
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';

/// Cabecera del sheet «Planificar viaje».
///
/// Una sola fila: la placa con el glifo de ruta, el título con la ciudad en
/// vivo debajo y el botón de cerrar. Antes había una píldora de ciudad aparte
/// y un botón de ajustes que no hacía nada; los dos se retiraron para que la
/// cabecera no ocupe alto ni prometa acciones que no existen.
class DestinationSheetHeader extends StatelessWidget {
  const DestinationSheetHeader({super.key, this.onClose});

  /// Cierra la hoja. Por defecto usa la ruta actual del [Navigator].
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final enVivo = AppColors.legible(
      HtmlDesignTokens.emerald600,
      colors.surface,
    );

    void close() => (onClose ?? () => Navigator.maybePop(context))();

    return Row(
      children: [
        // Placa de marca con el glifo de ruta.
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HtmlDesignTokens.emerald600,
                HtmlDesignTokens.emerald800,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: Icon(
            Icons.alt_route_rounded,
            size: 22,
            // Ícono grande (no texto): basta 3:1, que el blanco cumple sobre todo
            // el degradado; `onColor` lo confirma en vez de fijarlo a mano.
            color: AppColors.onColor(
              HtmlDesignTokens.emerald600,
              preferred: AppColors.surfaceLight,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Planificar viaje',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              // `LiveDot` reserva 3× su tamaño para el halo: sin este
              // corrimiento el punto quedaba sangrado respecto del título.
              Transform.translate(
                offset: const Offset(-5, 0),
                child: Row(
                  children: [
                    LiveDot(color: enVivo, size: 5),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        'Santa Cruz de la Sierra · en vivo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          color: enVivo,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Tooltip(
          message: 'Cerrar',
          child: PressScale(
            scale: 0.92,
            child: InkWell(
              onTap: close,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outlineVariant, width: 0.8),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
