import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius;
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';

/// Botón de planificar del sheet «Planificar viaje».
///
/// Encendido: degradado esmeralda con glow, placa del micro y flecha.
/// Apagado: superficie tonal del tema (nada de blanco translúcido sobre un
/// fondo claro, que dejaba el texto casi invisible).
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
    final colors = context.colors;
    final text = context.text;

    // El estado apagado no puede quedar por debajo de 4.5:1: sobre el gris
    // claro del tema, `onSurfaceVariant` se perdía. Tinta principal atenuada
    // sobre el contenedor más bajo mantiene el texto legible sin gritar.
    final disabledInk = colors.onSurface.withValues(alpha: 0.62);
    final foreground = enabled ? Colors.white : disabledInk;

    return PressScale(
      scale: 0.98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled
                  ? const LinearGradient(
                      colors: [
                        HtmlDesignTokens.emerald600,
                        HtmlDesignTokens.emerald500,
                        HtmlDesignTokens.teal500,
                      ],
                    )
                  : null,
              color: enabled ? null : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: enabled
                  ? null
                  : Border.all(color: colors.outlineVariant, width: 0.8),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: HtmlDesignTokens.emerald500.withValues(
                          alpha: 0.32,
                        ),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: enabled
                          ? Colors.white.withValues(alpha: 0.2)
                          : colors.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.directions_bus_rounded,
                      size: 16,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Planificar viaje',
                        maxLines: 1,
                        style: text.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: enabled
                        ? Colors.white
                        : disabledInk.withValues(alpha: 0.7),
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
