import 'package:flutter/material.dart';

import '../animation/motion.dart';
import '../theme/app_theme.dart';
import '../utils/extensions.dart';
import '../utils/time_formatters.dart';

/// Píldora de dato: icono + valor grande + etiqueta.
/// (stats del home, chips de info de ruta, etc.)
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.accent,
    this.expanded = true,
    this.countTo,
    this.countFormat,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? accent;
  final bool expanded;

  /// Si el dato es un entero, [value] entra contando desde 0 en vez de
  /// aparecer de golpe: un número que sube se lee como dato recién calculado.
  final int? countTo;

  /// Cómo se pinta cada paso del conteo; por defecto número es-BO
  /// (`Fmt.number`). Pasa a ser obligatorio si el sufijo va en el número,
  /// p. ej. `(v) => '$v min'`.
  final String Function(int)? countFormat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final tint = accent ?? colors.primary;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          if (icon != null)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
          if (icon != null) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // El número lleva el color del acento: el dato es vivo, no
                // solo su ícono.
                if (countTo == null)
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  )
                else
                  CountUp(
                    value: countTo!,
                    format: countFormat ?? Fmt.number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!expanded) return content;
    return Expanded(child: content);
  }
}
