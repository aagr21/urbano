import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import 'micros_panel_motion.dart';

/// Buscador del panel con halo de foco animado (el theme ya pinta el borde
/// primario; aquí se añade el resplandor y el tinte del prefijo).
///
/// En LÍNEAS filtra en vivo; en LUGARES el ENTER (o la flecha del sufijo)
/// confirma la búsqueda: no hay una petición por letra.
class MicrosPanelSearchField extends StatelessWidget {
  const MicrosPanelSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.animation,
    required this.placesMode,
    required this.placesDraft,
    required this.query,
    required this.locked,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClearQuery,
    required this.onClearPlacesSearch,
    required this.onPickPlace,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Tramo de la entrada del panel que le toca a esta sección.
  final Animation<double> animation;

  final bool placesMode;

  /// Borrador de lugares aún sin confirmar (decide si aparece la flecha).
  final String placesDraft;

  /// Texto con el que se está filtrando el catálogo (para la «x»).
  final String query;

  final bool locked;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClearQuery;
  final VoidCallback onClearPlacesSearch;
  final VoidCallback onPickPlace;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final focused = focusNode.hasFocus;
    return microsRise(
      animation,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: AnimatedContainer(
          duration: Motion.fade,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.input),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: focused ? 0.18 : 0),
                blurRadius: focused ? 16 : 0,
                spreadRadius: focused ? 0.5 : 0,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            // En lugares el ENTER confirma la búsqueda (no por letra); en
            // líneas filtra en vivo (local, gratis).
            onSubmitted: placesMode ? (_) => onSubmitted() : null,
            decoration: InputDecoration(
              isDense: true,
              // Relleno teñido (marca al 5%, al 10% con el foco): el campo
              // deja de ser un gris plano y se lee parte del panel.
              filled: true,
              fillColor: Color.lerp(
                colors.surface,
                colors.primary,
                focused ? 0.1 : 0.05,
              ),
              // Modo lugares: el foco invita a preguntar «¿qué línea pasa por
              // X?» sin que el usuario conozca numerales.
              hintText: placesMode
                  ? '¿Qué línea pasa por aquí? (calle, lugar…)'
                  : 'Buscar línea…',
              prefixIcon: TweenAnimationBuilder<Color?>(
                duration: Motion.fade,
                curve: Curves.easeOut,
                tween: ColorTween(
                  end: focused ? colors.primary : colors.onSurfaceVariant,
                ),
                builder: (_, color, _) => Icon(
                  placesMode ? Icons.place_rounded : Icons.search_rounded,
                  size: 20,
                  color: color,
                ),
              ),
              suffixIcon: _searchSuffix(
                context,
                placesMode: placesMode,
                placesDraft: placesDraft,
                query: query,
                locked: locked,
                onClearQuery: onClearQuery,
                onSubmitted: onSubmitted,
                onClearPlacesSearch: onClearPlacesSearch,
                onPickPlace: onPickPlace,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: colors.primary, width: 1.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sufijo del buscador según modo: en LÍNEAS la «x» limpia el filtro; en
/// LUGARES es el botón que confirma (el borrador cumplió ≥ 3 letras) más la
/// «x» que borra todo (borrador + confirmada) y el atajo de marcar el punto en
/// el mapa.
///
/// Devuelve `null` (y no un widget vacío) cuando no hay sufijo: un
/// `suffixIcon` no nulo reserva 48 px de alto en el `InputDecorator`.
Widget? _searchSuffix(
  BuildContext context, {
  required bool placesMode,
  required String placesDraft,
  required String query,
  required bool locked,
  required VoidCallback onClearQuery,
  required VoidCallback onSubmitted,
  required VoidCallback onClearPlacesSearch,
  required VoidCallback onPickPlace,
}) {
  if (!placesMode) {
    if (query.isEmpty) return null;
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onClearQuery,
      icon: const Icon(Icons.close_rounded, size: 18),
    );
  }
  final draft = placesDraft.trim();
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Marcar el lugar directamente en el mapa (además de escribirlo o
      // usar «cerca de mí»): siempre disponible en modo lugares.
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Marcar en el mapa',
        onPressed: locked ? null : onPickPlace,
        icon: const Icon(Icons.add_location_alt_rounded, size: 18),
      ),
      if (draft.isNotEmpty)
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Buscar',
          onPressed: onSubmitted,
          icon: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: context.colors.primary,
          ),
        ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onClearPlacesSearch,
        icon: const Icon(Icons.close_rounded, size: 18),
      ),
    ],
  );
}
