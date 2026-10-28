import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';

/// Cerrador "X" que cuelga centrado debajo de la tarjeta de origen/destino.
///
/// Repliega el panel de origen/destino: es la forma explícita de cerrar, ya
/// que la píldora inferior queda lejos del pulgar cuando el panel está
/// desplegado.
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
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
