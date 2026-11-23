import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius;
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';

/// Botón de planificar — degradado esmeralda como sheet.html.
///
/// Botón ancho con gradiente esmeralda, sombra glow, ícono de micro y flecha.
/// Cuando está deshabilitado, muestra un fondo gris semitransparente.
class JourneyPlanButton extends StatelessWidget {
  const JourneyPlanButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return PressScale(
      scale: 0.98,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          decoration: enabled
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      HtmlDesignTokens.emerald600,
                      HtmlDesignTokens.emerald500,
                      HtmlDesignTokens.teal500,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: HtmlDesignTokens.emerald500.withValues(
                        alpha: 0.35,
                      ),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                )
              : BoxDecoration(
                  color:
                      (dark
                              ? HtmlDesignTokens.slate500
                              : HtmlDesignTokens.slate400)
                          .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Planificar viaje',
                style: text.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: Color(0xCCFFFFFF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
