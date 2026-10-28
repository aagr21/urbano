import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/utils/extensions.dart';

/// Botón circular flotante sobre el mapa (zoom, micros, swap de la
/// timeline, encuadrar viaje). Superficie elevada + borde del tema.
///
/// Se hunde al pulsar: son los controles más rápidos de la pantalla y sin ese
/// hundido dan sensación de placa muerta. No lleva `BackdropFilter`, así que
/// escalarlos cuesta cero (a diferencia de `GlassCard`).
class MapCircleButton extends StatelessWidget {
  const MapCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PressScale(
      scale: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onTap,
          icon: Icon(icon, size: 20, color: colors.primary),
        ),
      ),
    );
  }
}
