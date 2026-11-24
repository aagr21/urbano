import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius, AppSpace;
import '../../../../core/utils/extensions.dart';

/// Botón de intercambio entre los dos extremos del viaje.
///
/// Antes era un círculo blanco colgado de dos líneas; ahora es una píldora
/// pequeña alineada a la derecha que dice lo que hace («Invertir»), sin
/// pintar una superficie blanca sobre el tema oscuro.
class JourneySwapDivider extends StatelessWidget {
  const JourneySwapDivider({super.key, this.onSwap});

  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppColors.tint(
      colors.primary,
      colors.surface,
      dark ? 0.2 : 0.1,
    );
    final ink = AppColors.legible(colors.primary, fill);

    return Align(
      alignment: Alignment.centerRight,
      child: PressScale(
        scale: 0.94,
        child: Tooltip(
          message: 'Invertir origen y destino',
          child: InkWell(
            onTap: onSwap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpace.xs + 1),
              padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: AppColors.tint(colors.primary, colors.surface, 0.22),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert_rounded, size: 14, color: ink),
                  const SizedBox(width: 4),
                  Text(
                    'Invertir',
                    style: text.labelSmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.2,
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
