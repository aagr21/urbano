import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart' show AppRadius;
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../domain/journey_place.dart';

/// Campo de extremo (origen o destino) — estilo de sheet.html.
///
/// Muestra un ícono con fondo de color, la etiqueta, un campo de texto
/// editable y un botón "Mapa" para elegir en el mapa.
class JourneyEndpointField extends StatelessWidget {
  const JourneyEndpointField({
    super.key,
    required this.label,
    required this.place,
    required this.icon,
    required this.iconBg,
    required this.iconInk,
    required this.labelInk,
    required this.subtitleInk,
    required this.onTap,
    required this.onMapTap,
    required this.mapButtonBg,
    required this.mapButtonInk,
    required this.mapButtonBorder,
    this.controller,
    this.focusNode,
    this.hintText,
  });

  final String label;
  final JourneyPlace? place;
  final IconData icon;
  final Color iconBg;
  final Color iconInk;
  final Color labelInk;
  final Color subtitleInk;
  final VoidCallback onTap;
  final VoidCallback onMapTap;
  final Color mapButtonBg;
  final Color mapButtonInk;
  final Color mapButtonBorder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;

  String _label(JourneyPlace? place) {
    if (place == null) return '';
    return switch (place) {
      JourneyPlacePoi(:final name) => name,
      JourneyPlacePoint(:final address) => address ?? 'Punto en el mapa',
      JourneyPlaceLocation(:final address) => address ?? 'Mi ubicación',
    };
  }

  String _subtitle(JourneyPlace? place) {
    if (place == null) return '';
    if (place is JourneyPlacePoi) return place.subtitle ?? '';
    if (place is JourneyPlaceLocation) return 'Ubicación actual detectada';
    return '';
  }

  /// Campo de texto editable con el botón "Mapa" como zona separada.
  Widget _buildEditableField(BuildContext context, TextTheme text) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: HtmlDesignTokens.slate400,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 2),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
      style: text.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Icono con fondo de color
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(icon, size: 14, color: iconInk),
            ),
            const SizedBox(width: 10),
            // Texto editable o estático
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.labelSmall?.copyWith(
                      color: labelInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (controller != null)
                    // Campo editable: TextField con el botón "Mapa" integrado
                    _buildEditableField(context, text)
                  else if (place != null) ...[
                    Text(
                      _label(place),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (_subtitle(place).isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        _subtitle(place),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          color: subtitleInk,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            // Botón "Mapa"
            Tooltip(
              message: 'Elegir en el mapa',
              child: InkWell(
                onTap: onMapTap,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: mapButtonBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: mapButtonBorder, width: 0.8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_rounded, size: 12, color: mapButtonInk),
                      const SizedBox(width: 4),
                      Text(
                        'Mapa',
                        style: text.labelSmall?.copyWith(
                          color: mapButtonInk,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
