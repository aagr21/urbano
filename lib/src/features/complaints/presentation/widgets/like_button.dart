import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
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
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;

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
    final tint = widget.liked ? colors.error : colors.onSurfaceVariant;
    return PressScale(
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.xs,
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
                  color: tint,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              AnimatedDefaultTextStyle(
                duration: Motion.quick,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.liked ? tint : colors.onSurfaceVariant,
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
