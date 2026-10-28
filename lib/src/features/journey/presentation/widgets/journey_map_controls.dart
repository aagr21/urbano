import 'package:flutter/material.dart';

import '../../../../core/location/location_fab.dart';
import '../../../../core/utils/extensions.dart';
import 'journey_map_button.dart';

/// Columna de controles a la derecha del mapa: zoom, ubicación (con
/// estados), micros y pantalla completa.
class JourneyMapControls extends StatelessWidget {
  const JourneyMapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onOpenMicros,
    required this.microsActive,
    required this.tracking,
    required this.onFollowChanged,
    required this.fullscreen,
    required this.onToggleFullscreen,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onOpenMicros;

  /// `true` cuando hay micros con recorrido dibujado en el mapa.
  final bool microsActive;

  /// `true` mientras la cámara sigue la ubicación del usuario.
  final bool tracking;
  final ValueChanged<bool> onFollowChanged;

  /// `true` cuando el mapa está a pantalla completa (el botón ofrece salir).
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MapCircleButton(
          icon: Icons.add_rounded,
          tooltip: 'Acercar',
          onTap: onZoomIn,
        ),
        const SizedBox(height: 10),
        MapCircleButton(
          icon: Icons.remove_rounded,
          tooltip: 'Alejar',
          onTap: onZoomOut,
        ),
        const SizedBox(height: 10),
        LocationFab(
          following: tracking,
          onFollowChanged: onFollowChanged,
          heroTag: 'journey-location',
        ),
        const SizedBox(height: 10),
        _MicrosButton(active: microsActive, onTap: onOpenMicros),
        const SizedBox(height: 10),
        MapCircleButton(
          icon: fullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          tooltip: fullscreen
              ? 'Salir de pantalla completa'
              : 'Pantalla completa',
          onTap: onToggleFullscreen,
        ),
      ],
    );
  }
}

/// Botón de micros: abre el menú de líneas y muestra un punto indicador
/// mientras haya recorridos dibujados sobre el mapa. El punto entra con un
/// pequeño rebote (0.2 → 1, `easeOutBack`) para marcar el cambio de estado.
class _MicrosButton extends StatelessWidget {
  const _MicrosButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MapCircleButton(
          icon: Icons.directions_bus_rounded,
          tooltip: 'Micros',
          onTap: onTap,
        ),
        if (active)
          Positioned(
            top: 3,
            right: 3,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.2, end: 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
