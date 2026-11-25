import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppSpace;
import '../../../../core/utils/extensions.dart';
import 'journey_endpoint_field.dart';

/// Separador entre origen y destino dentro del bloque de ruta.
///
/// Tres piezas en una fila: a la izquierda el riel punteado que une la placa
/// del origen con la del destino (centrado bajo ellas), al medio la línea que
/// separa los dos campos y a la derecha el botón redondo de invertir, en la
/// MISMA columna que los botones de mapa de cada campo. Antes era una píldora
/// «Invertir» suelta entre dos cajas, que es lo que se leía descuadrado.
class JourneySwapDivider extends StatelessWidget {
  const JourneySwapDivider({super.key, this.onSwap});

  final VoidCallback? onSwap;

  static const double _height = 28;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppColors.tint(
      colors.primary,
      colors.surface,
      dark ? 0.22 : 0.12,
    );
    final ink = AppColors.legible(colors.primary, fill);
    const size = JourneyEndpointField.actionSize;

    return SizedBox(
      height: _height,
      child: Row(
        children: [
          // Riel: centrado bajo la placa de 32 px de cada campo.
          const SizedBox(width: JourneyEndpointField.inset),
          SizedBox(
            width: JourneyEndpointField.plateSize,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    width: 3,
                    height: 3,
                    margin: const EdgeInsets.symmetric(vertical: 1.5),
                    decoration: BoxDecoration(
                      color: colors.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Divider(height: 1, color: colors.outlineVariant)),
          const SizedBox(width: AppSpace.sm),
          PressScale(
            scale: 0.92,
            child: Tooltip(
              message: 'Invertir origen y destino',
              child: Material(
                color: fill,
                shape: CircleBorder(
                  side: BorderSide(color: colors.surface, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onSwap,
                  child: SizedBox.square(
                    dimension: size,
                    child: Icon(Icons.swap_vert_rounded, size: 20, color: ink),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
    );
  }
}
