import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/glass_card.dart';
import '../journey_providers.dart';
import 'journey_map_button.dart';

/// Tarjeta superior del planeador (GlassCard): timeline origen→destino
/// (con el botón de swap centrado sobre el conector) + campos, hora y
/// planificar. Pura presentación: todo el estado llega por props.
class JourneyPlannerCard extends StatelessWidget {
  const JourneyPlannerCard({
    super.key,
    required this.origin,
    required this.destination,
    required this.time,
    required this.ready,
    required this.hasResults,
    required this.onSwap,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onPickOriginOnMap,
    required this.onPickDestinationOnMap,
    required this.onPickTime,
    required this.onSubmit,
    required this.onClear,
  });

  final JourneyPlace? origin;
  final JourneyPlace? destination;

  /// Hora de salida `HH:mm` (nula = "Ahora").
  final String? time;

  /// `true` con origen y destino fijados: habilita "Viajar".
  final bool ready;

  /// `true` con resultados visibles: muestra el botón "Limpiar".
  final bool hasResults;

  final VoidCallback onSwap;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onPickOriginOnMap;
  final VoidCallback onPickDestinationOnMap;
  final VoidCallback onPickTime;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline: punto verde → conector → punto rojo, con el
              // botón de intercambio centrado SOBRE el conector: queda
              // separado de los iconos de mapa/editar por todo el ancho
              // de los campos, nunca pegado a su borde derecho.
              Padding(
                padding: const EdgeInsets.only(top: 25, left: 4),
                child: SizedBox(
                  width: 48,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TimelineDot(
                            color: AppColors.success,
                            icon: Icons.trip_origin_rounded,
                          ),
                          SizedBox(
                            width: 2,
                            height: 62,
                            // Neutro que convive con ambos temas (antes
                            // slate-300, demasiado claro para el modo oscuro).
                            child: ColoredBox(color: Color(0xFF94A3B8)),
                          ),
                          _TimelineDot(
                            color: AppColors.danger,
                            icon: Icons.flag_rounded,
                          ),
                        ],
                      ),
                      _SwapButton(onTap: onSwap),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _PlaceField(
                      label: 'Origen',
                      place: origin,
                      hint: 'Marca un punto en el mapa o usa tu ubicación',
                      onTap: onPickOrigin,
                      onMapTap: onPickOriginOnMap,
                    ),
                    const SizedBox(height: 8),
                    _PlaceField(
                      label: 'Destino',
                      place: destination,
                      hint: 'Marca dónde quieres llegar',
                      onTap: onPickDestination,
                      onMapTap: onPickDestinationOnMap,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onPickTime,
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(time == null ? 'Ahora' : 'Salida $time'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: ready ? onSubmit : null,
                  icon: const Icon(Icons.route_rounded, size: 18),
                  label: const Text('Viajar'),
                ),
              ),
              if (hasResults) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Limpiar',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Botón swap de la timeline ("Invertir origen y destino"): separado del
/// borde derecho de los campos es un requisito de regresión de layout.
class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MapCircleButton(
    icon: Icons.swap_vert_rounded,
    tooltip: 'Invertir origen y destino',
    onTap: onTap,
  );
}

/// Campo de origen/destino (sin icono: la timeline lleva los puntos).
class _PlaceField extends StatelessWidget {
  const _PlaceField({
    required this.label,
    required this.place,
    required this.hint,
    required this.onTap,
    this.onMapTap,
  });

  final String label;
  final JourneyPlace? place;
  final String hint;
  final VoidCallback onTap;

  /// Abre el selector de punto en el mapa (si no, no se muestra el botón).
  final VoidCallback? onMapTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: place == null
              ? colors.outlineVariant
              : colors.primary.withValues(alpha: 0.45),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place?.label ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: place == null
                          ? text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            )
                          : text.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (onMapTap != null)
                IconButton(
                  tooltip: 'Elegir en el mapa',
                  onPressed: onMapTap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 38,
                  ),
                  icon: Icon(
                    Icons.map_outlined,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
              Icon(Icons.edit_rounded, size: 16, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Punto de la timeline (origen verde / destino rojo).
class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(icon, size: 8, color: Colors.white),
  );
}
