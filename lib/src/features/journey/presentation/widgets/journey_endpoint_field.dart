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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final fill = AppColors.tint(accent, colors.surface, dark ? 0.16 : 0.06);
    final border = AppColors.tint(accent, colors.surface, dark ? 0.34 : 0.20);
    final labelInk = AppColors.legible(accent, fill);
    final plate = AppColors.tint(accent, fill, dark ? 0.34 : 0.22);
    final plateInk = AppColors.legible(accent, plate);

    final valueStyle = text.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 14.5,
      color: empty ? colors.onSurfaceVariant : colors.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Ink(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: border, width: 0.8),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.sm + 2,
                  AppSpace.sm,
                  AppSpace.sm + 2,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: plate,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(icon, size: 18, color: plateInk),
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
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              if (tag != null && !empty) ...[
                                const SizedBox(width: 6),
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
                                      fontSize: 8.5,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
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
                              // El tema de la app pinta los inputs como
                              // píldoras rellenas; aquí el campo vive dentro
                              // de la fila tonal, así que no lleva caja
                              // propia ni borde de foco.
                              decoration: InputDecoration(
                                isCollapsed: true,
                                filled: false,
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
                            const SizedBox(height: 1),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onMapTap != null) ...[
                      const SizedBox(width: AppSpace.sm),
                      Tooltip(
                        message: 'Elegir en el mapa',
                        child: InkWell(
                          onTap: onMapTap,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.outlineVariant,
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              Icons.map_outlined,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        ?suggestions,
      ],
    );
  }
}
