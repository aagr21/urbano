import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Píldora compacta de dato (sentido) con ícono y tinta ya resueltos.
class MetaPill extends StatelessWidget {
  const MetaPill({
    super.key,
    required this.icon,
    required this.label,
    required this.fill,
    required this.ink,
  });

  final IconData icon;
  final String label;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ink),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (text.labelSmall ?? text.bodySmall)?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora con el número de recorridos activos de una línea.
class ActivePill extends StatelessWidget {
  const ActivePill({
    super.key,
    required this.count,
    required this.tint,
    required this.cardBackground,
  });

  final int count;
  final Color tint;

  /// Color de la tarjeta detrás de la píldora, para calcular el contraste.
  final Color cardBackground;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    // El relleno de la píldora es el tinte al 16% sobre la tarjeta: el número
    // y el ícono contrastan contra **esa mezcla**, no contra la superficie ni
    // contra el tinte puro (un `2C3E50` sobre una hoja oscura sería ilegible).
    final background = Color.lerp(cardBackground, tint, 0.16)!;
    final ink = AppColors.legible(tint, background);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: ink.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 11, color: ink),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: (text.labelSmall ?? text.bodySmall)?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
