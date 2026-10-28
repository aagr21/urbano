import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Tarjeta translúcida con blur (overlays de mapa, header, etc.).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.blur = 14,
    this.color,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? color;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(radius);
    final surface =
        color ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.82));

    Widget card = ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: effectiveRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      // Sin `PressScale` a propósito: escalar un `BackdropFilter` obliga a
      // re-rasterizar el blur en cada frame del pulso, y en gama baja Android
      // eso se ve como tirón. El splash del `InkWell` ya es feedback suficiente
      // sobre vidrio.
      card = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: card,
        ),
      );
    }
    return card;
  }
}
