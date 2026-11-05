import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';

/// Cerrador "X" que cuelga centrado debajo de la tarjeta de origen/destino.
///
/// Repliega el panel de origen/destino: es la forma explícita de cerrar, ya
/// que la píldora inferior queda lejos del pulgar cuando el panel está
/// desplegado.
///
/// Es la pastilla circular de siempre (relleno `surface` + borde), pero SIN
/// sombra: el `BoxShadow` con desplazamiento y desenfoque se leía como un
/// «borde cuadrado» detrás del círculo, que es justo lo que había que quitar.
class JourneyPlannerCloseButton extends StatelessWidget {
  const JourneyPlannerCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: const SizedBox(
            width: 34,
            height: 34,
            child: Icon(Icons.close_rounded, size: 20),
          ),
        ),
      ),
    );
  }
}
