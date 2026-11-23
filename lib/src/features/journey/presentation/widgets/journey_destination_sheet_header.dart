import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius;
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';

/// Header del bottom sheet "Planificar viaje" — estilo de sheet.html.
///
/// Muestra una píldora de ubicación, un logo con borde degradado, el título
/// "Planificar viaje" y un botón de ajustes.
class DestinationSheetHeader extends StatelessWidget {
  const DestinationSheetHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Píldora de ubicación
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: HtmlDesignTokens.emerald500.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: HtmlDesignTokens.emerald500.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Punto vivo
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: HtmlDesignTokens.emerald400,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Text(
                'Santa Cruz de la Sierra',
                style: text.labelSmall?.copyWith(
                  color: HtmlDesignTokens.emerald700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 10,
                color: HtmlDesignTokens.emerald600,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Título con logo degradado
        Row(
          children: [
            // Logo con borde degradado
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    HtmlDesignTokens.emerald600,
                    HtmlDesignTokens.teal500,
                    HtmlDesignTokens.cyan400,
                  ],
                ),
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: HtmlDesignTokens.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  size: 20,
                  color: HtmlDesignTokens.emerald600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planificar viaje',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: dark
                          ? HtmlDesignTokens.slate50
                          : HtmlDesignTokens.slate900,
                    ),
                  ),
                  Text(
                    'Rutas en tiempo real & micros',
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: HtmlDesignTokens.slate400,
                    ),
                  ),
                ],
              ),
            ),
            // Botón de ajustes
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HtmlDesignTokens.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: dark ? AppColors.lineDark : HtmlDesignTokens.slate200,
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 16,
                color: dark
                    ? HtmlDesignTokens.slate400
                    : HtmlDesignTokens.slate600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
