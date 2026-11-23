import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/location/location_fab.dart';
import '../../../../core/widgets/map_tile_button.dart';
import 'journey_map_button.dart';

/// Columna de controles a la derecha del mapa: zoom, ubicación y brillo del
/// mapa.
class JourneyMapControls extends StatelessWidget {
  const JourneyMapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.tracking,
    required this.onFollowChanged,
    this.bearing = 0,
    this.onResetNorth,
    this.onBack,
  });
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  /// `true` mientras la cámara sigue la ubicación del usuario.
  final bool tracking;
  final ValueChanged<bool> onFollowChanged;

  final double bearing;
  final VoidCallback? onResetNorth;

  /// Vuelve a Inicio desde la rama Viaje; `null` lo omite (pruebas de la sola
  /// columna de herramientas).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (onBack != null) ...[
          MapCircleButton(
            key: const ValueKey('journey-back-button'),
            icon: Icons.arrow_back_rounded,
            tooltip: 'Volver al inicio',
            onTap: onBack!,
          ),
          const SizedBox(height: 10),
        ],
        if (bearing.abs() > 0.5) ...[
          MapCircleButton(
            icon: Icons.explore_rounded,
            tooltip: 'Orientar al norte',
            onTap: onResetNorth ?? _noop,
            rotation: -bearing * math.pi / 180,
          ),
          const SizedBox(height: 10),
        ],
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
        LocationFab(following: tracking, onFollowChanged: onFollowChanged),
        const SizedBox(height: 10),
        // Selector de capa del mapa (independiente del tema de la app): cambia
        // solo el fondo del mapa. El ícono es chrome de la app, se pinta con el
        // tema de la app.
        const MapTileButton(),
      ],
    );
  }

  static void _noop() {}
}
