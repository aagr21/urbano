import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/extensions.dart';

enum RouteBadgeSize { small, medium, large }

/// Chip con el color GTFS de la ruta (texto con buen contraste).
class RouteBadge extends StatelessWidget {
  const RouteBadge({
    super.key,
    required this.label,
    required this.colorHex,
    this.textColorHex,
    this.size = RouteBadgeSize.medium,
    this.heroTag,
    this.onTap,
  });

  factory RouteBadge.route(
    String shortName, {
    String color = '64748B',
    String? textColor,
    Key? key,
    RouteBadgeSize size = RouteBadgeSize.medium,
    String? heroTag,
    VoidCallback? onTap,
  }) => RouteBadge(
    key: key,
    label: shortName,
    colorHex: color,
    textColorHex: textColor,
    size: size,
    heroTag: heroTag,
    onTap: onTap,
  );

  final String label;
  final String colorHex;
  final String? textColorHex;
  final RouteBadgeSize size;
  final String? heroTag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.fromHex(colorHex);
    final preferred = textColorHex == null
        ? null
        : AppColors.fromHex(textColorHex);
    final foreground = AppColors.onColor(background, preferred: preferred);

    Widget badge = Container(
      padding: size.padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size.radius),
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: size.textStyle.copyWith(color: foreground),
      ),
    );

    if (onTap != null) {
      badge = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size.radius),
          child: badge,
        ),
      );
    }
    if (heroTag != null) {
      badge = Hero(tag: heroTag!, child: badge);
    }
    return badge;
  }
}

extension on RouteBadgeSize {
  EdgeInsets get padding => switch (this) {
    RouteBadgeSize.small => const EdgeInsets.symmetric(
      horizontal: 7,
      vertical: 3,
    ),
    RouteBadgeSize.medium => const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 5,
    ),
    RouteBadgeSize.large => const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 8,
    ),
  };

  double get radius => switch (this) {
    RouteBadgeSize.small => 8,
    RouteBadgeSize.medium => 10,
    RouteBadgeSize.large => 13,
  };

  TextStyle get textStyle => switch (this) {
    RouteBadgeSize.small => const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      height: 1.2,
    ),
    RouteBadgeSize.medium => const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      height: 1.2,
    ),
    RouteBadgeSize.large => const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
      height: 1.2,
    ),
  };
}

/// Chip neutro compacto (distancia, "N paradas", etc.).
class MetaChip extends StatelessWidget {
  const MetaChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.background,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            background ?? scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.text.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
