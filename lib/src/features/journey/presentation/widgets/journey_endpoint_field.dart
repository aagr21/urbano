import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius, AppSpace;
import '../../../../core/utils/extensions.dart';

/// Fila de extremo (origen o destino) del sheet «Planificar viaje».
///
/// Se lee como un campo: contenedor tonal del acento del extremo, placa con
/// el ícono, etiqueta, un campo de texto editable para escribir el lugar, el
/// botón para elegir en el mapa y, debajo, la lista de sugerencias que arma
/// quien la usa. El texto se escribe aquí; el punto del viaje lo resuelve el
/// padre (GPS, lugar popular, mapa o reciente).
class JourneyEndpointField extends StatelessWidget {
  const JourneyEndpointField({
    super.key,
    required this.label,
    required this.value,
    required this.emptyHint,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.subtitle,
    this.tag,
    this.onMapTap,
    this.empty = false,
    this.controller,
    this.focusNode,
    this.inputKey,
    this.onChanged,
    this.onSubmitted,
    this.suggestions,
  });

  final String label;

  /// Valor mostrado cuando no hay [controller].
  final String? value;
  final String emptyHint;
  final IconData icon;

  /// Acento del extremo (esmeralda en origen, rosa en destino).
  final Color accent;
  final String? subtitle;

  /// Píldora corta junto a la etiqueta (por ejemplo `GPS`).
  final String? tag;

  final VoidCallback onTap;
  final VoidCallback? onMapTap;

  /// `true` cuando no hay valor todavía: el texto se pinta como pista.
  final bool empty;

  /// Campo editable. Cuando existe, el usuario puede escribir el lugar.
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final Key? inputKey;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Sugerencias que se pintan justo debajo del campo (las arma el padre).
  final Widget? suggestions;

  /// Lado de la placa del ícono. El riel de [JourneySwapDivider] se centra
  /// bajo ella, así que ambos leen esta misma medida.
  static const double plateSize = 32;

  /// Sangría horizontal de la fila (placa a la izquierda, mapa a la derecha).
  static const double inset = AppSpace.md;

  /// Lado del botón de mapa; el de invertir usa el mismo para alinearse.
  static const double actionSize = 40;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final plate = AppColors.tint(accent, colors.surface, dark ? 0.26 : 0.14);
    final plateInk = AppColors.legible(accent, plate);
    final labelInk = AppColors.legible(accent, colors.surface);

    final valueStyle = text.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: empty ? colors.onSurfaceVariant : colors.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // La fila no dibuja caja propia: vive dentro del bloque de ruta de la
        // hoja, que ya es la superficie. Una caja por campo + la del bloque +
        // la de la hoja era el «cajas dentro de cajas» que se veía descuadrado.
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              inset,
              AppSpace.md,
              AppSpace.sm,
              AppSpace.md,
            ),
            child: Row(
              children: [
                Container(
                  width: plateSize,
                  height: plateSize,
                  decoration: BoxDecoration(
                    color: plate,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 17, color: plateInk),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: text.labelSmall?.copyWith(
                              color: labelInk,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              height: 1.2,
                            ),
                          ),
                          if (tag != null && !empty) ...[
                            const SizedBox(width: AppSpace.xs + 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: plate,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                tag!,
                                style: text.labelSmall?.copyWith(
                                  color: plateInk,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  letterSpacing: 0.6,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (controller != null)
                        TextField(
                          key: inputKey,
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: onChanged,
                          onSubmitted: onSubmitted,
                          textInputAction: TextInputAction.search,
                          textCapitalization: TextCapitalization.words,
                          cursorColor: colors.primary,
                          style: valueStyle,
                          // El tema pinta los inputs como píldoras rellenas
                          // CON relleno interno: aquí se anula todo (también
                          // `contentPadding`, que era lo que corría el texto
                          // a la derecha de la etiqueta y del subtítulo).
                          decoration: InputDecoration(
                            isCollapsed: true,
                            isDense: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            hintText: emptyHint,
                            hintStyle: valueStyle?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                        )
                      else
                        Text(
                          value ?? emptyHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: valueStyle,
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onMapTap != null) ...[
                  const SizedBox(width: AppSpace.sm),
                  IconButton(
                    onPressed: onMapTap,
                    tooltip: 'Elegir en el mapa',
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(actionSize),
                      minimumSize: const Size.square(actionSize),
                      padding: EdgeInsets.zero,
                      // Sin el margen táctil de 48 px: el botón mide lo mismo
                      // que el de invertir y ambos caen en la misma columna.
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: colors.onSurfaceVariant,
                    ),
                    icon: const Icon(Icons.map_outlined, size: 20),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (suggestions != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.sm,
              0,
              AppSpace.sm,
              AppSpace.sm,
            ),
            child: suggestions,
          ),
      ],
    );
  }
}
