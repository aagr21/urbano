import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Botón de «apoyo» tipo red social: corazón que se rellena y da un pequeño
/// salto al activarse, con el contador rodando vía [CountUp]. Es presentacional
/// (props + callback); la lógica optimista vive en el controller del feed.
///
/// La palabra del producto es **apoyo** (la cabecera cuenta «apoyos»); el
/// corazón y el API siguen llamándose like, pero ninguna letra de la app dice
/// «me gusta».
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.liked,
    required this.count,
    required this.onTap,
    this.on,
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;

  /// Superficie sobre la que se pinta la pastilla. Se pasa explícita porque el
  /// contraste se mide contra lo que REALMENTE hay detrás.
  final Color? on;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: Motion.quick,
    lowerBound: 0.8,
    value: 1,
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pop.forward(from: 0.8);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final surface = widget.on ?? colors.surfaceContainerLow;
    final accent = widget.liked ? colors.error : colors.onSurfaceVariant;
    // El fondo existe siempre (al 7 % cuando no hay apoyo): así el pie de la
    // tarjeta se lee como dos acciones y no como un ícono suelto.
    final fill = AppColors.tint(accent, surface, widget.liked ? 0.16 : 0.07);
    final ink = AppColors.legible(accent, fill);
    return PressScale(
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.xs,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pop,
                child: Icon(
                  widget.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: ink,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              AnimatedDefaultTextStyle(
                duration: Motion.quick,
                style: TextStyle(
                  fontSize: 14,
                  color: ink,
                  fontWeight: widget.liked ? FontWeight.w800 : FontWeight.w600,
                ),
                child: CountUp(
                  value: widget.count,
                  duration: Motion.settle,
                  format: (value) => value == 0 ? 'Apoyo' : '$value',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
