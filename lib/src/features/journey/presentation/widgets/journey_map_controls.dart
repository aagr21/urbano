import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/location/location_fab.dart';
import '../../../../core/widgets/map_tile_button.dart';
import 'journey_map_button.dart';

/// Columna de controles a la derecha del mapa: zoom, ubicación, brillo del
/// mapa y pantalla completa.
class JourneyMapControls extends StatelessWidget {
  const JourneyMapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.tracking,
    required this.onFollowChanged,
    required this.fullscreen,
    required this.onToggleFullscreen,
    this.bearing = 0,
    this.onResetNorth,
    this.onOpenMenu,
    this.onBack,
  });
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  /// `true` mientras la cámara sigue la ubicación del usuario.
  final bool tracking;
  final ValueChanged<bool> onFollowChanged;

  /// `true` cuando el mapa está a pantalla completa (el botón ofrece salir).
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final double bearing;
  final VoidCallback? onResetNorth;

  /// Abre el menú principal; `null` lo omite (pruebas de la sola columna de
  /// herramientas del mapa).
  final VoidCallback? onOpenMenu;

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
        if (onOpenMenu != null) ...[
          MapCircleButton(
            key: const ValueKey('journey-menu-button'),
            icon: Icons.menu_rounded,
            tooltip: 'Menú',
            onTap: onOpenMenu!,
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

  static void _noop() {}
}
