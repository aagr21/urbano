import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import 'micros_panel_edge_handle.dart';

/// Armazón del cajón de micros: alineación a la izquierda, arrastre horizontal
/// (con el muelle que devuelve el panel a su sitio), la superficie `Material`,
/// el `SafeArea` y el tirador del borde. El contenido lo pone el panel.
///
/// El tirador sobresale del panel hacia el mapa: la caja del `Stack` es más
/// ancha que el `Material` a propósito, o el tirador quedaría fuera del `size`
/// de su `RenderBox` y no recibiría taps.
class MicrosPanelShell extends StatelessWidget {
  const MicrosPanelShell({
    super.key,
    required this.width,
    required this.handleZone,
    required this.offsetDx,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onClose,
    required this.child,
  });

  /// Ancho del cajón (sin la zona del tirador).
  final double width;

  /// Franja extra a la derecha donde vive el tirador.
  final double handleZone;

  /// Desplazamiento horizontal del arrastre (0 = pegado al borde).
  final double offsetDx;

  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        // Tirar del panel hacia la izquierda lo cierra (con muelle si el
        // arrastre se queda corto). Los gestos verticales los deja pasar la
        // lista.
        onHorizontalDragUpdate: onDragUpdate,
        onHorizontalDragEnd: onDragEnd,
        child: Transform.translate(
          offset: Offset(offsetDx, 0),
          child: Opacity(
            opacity: (1 - offsetDx.abs() / 460).clamp(0.0, 1.0),
            child: SizedBox(
              width: width + handleZone,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: colors.surface,
                    elevation: 10,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(AppRadius.lg),
                    ),
                    child: SizedBox(
                      width: width,
                      height: double.infinity,
                      child: SafeArea(child: child),
                    ),
                  ),
                  // Tirador pegado al borde derecho: vive sobre el mapa y
                  // cierra el panel (invita al arrastre horizontal).
                  Positioned(
                    right: 0,
                    top: 120,
                    child: SizedBox(
                      width: handleZone,
                      child: MicrosPanelEdgeHandle(onTap: onClose),
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
