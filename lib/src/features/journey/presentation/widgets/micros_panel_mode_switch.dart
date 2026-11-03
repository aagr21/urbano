import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Interruptor LÍNEAS ⇄ LUGARES: una pista hundida con una pastilla de marca
/// que se desliza al cambiar de modo. La tinta de los rótulos se interpola,
/// así que el texto no salta de color a mitad del recorrido; los toques siguen
/// siendo uno por rótulo (el `Text` vive dentro de su `InkWell`).
class MicrosPanelModeSwitch extends StatelessWidget {
  const MicrosPanelModeSwitch({
    super.key,
    required this.places,
    required this.onChanged,
  });

  /// `true` = modo LUGARES (la pastilla se va a la derecha).
  final bool places;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final radius = BorderRadius.circular(AppRadius.pill);
    // Pista: el gris de los contenedores con un soplo del primario.
    final track = Color.lerp(
      colors.surfaceContainerHighest,
      colors.primary,
      colors.brightness == Brightness.dark ? 0.06 : 0.04,
    )!;
    return Container(
      height: 42,
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: track,
        borderRadius: radius,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: places ? Alignment.centerRight : Alignment.centerLeft,
            duration: Motion.morph,
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      Color.lerp(colors.primary, colors.secondary, 0.8)!,
                    ],
                  ),
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            // Stretch: cada rótulo ocupa todo el alto de la pista (zona
            // táctil cómoda, no solo el renglón del texto).
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Segment(
                selected: !places,
                label: 'Líneas',
                icon: Icons.format_list_numbered_rounded,
                onTap: () => onChanged(false),
                radius: radius,
                colors: colors,
                text: text,
              ),
              _Segment(
                selected: places,
                label: 'Lugares',
                icon: Icons.place_rounded,
                onTap: () => onChanged(true),
                radius: radius,
                colors: colors,
                text: text,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rótulo con su zona táctil y su tinta interpolada.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.radius,
    required this.colors,
    required this.text,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final BorderRadius radius;
  final ColorScheme colors;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: TweenAnimationBuilder<Color?>(
            duration: Motion.morph,
            curve: Curves.easeOut,
            tween: ColorTween(
              end: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
            builder: (_, color, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
