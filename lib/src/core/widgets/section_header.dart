import 'package:flutter/material.dart';

import '../animation/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart' show AppRadius, AppSpace;
import '../utils/extensions.dart';

/// Encabezado de sección: título + subtítulo opcional + acción opcional.
///
/// La acción es una **píldora** con punta de flecha, no un `TextButton`: el
/// «Ver todas» de texto plano se perdía contra el lienzo y no parecía un
/// destino.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.lg,
      AppSpace.xl,
      AppSpace.lg,
      AppSpace.sm,
    ),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          // Barra de marca junto al título: firma visual de las secciones
          // con los dos tintes fríos de la marca.
          Container(
            width: 4,
            height: 28,
            margin: const EdgeInsets.only(right: AppSpace.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.aqua],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: AppSpace.sm),
            _ActionPill(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

/// Píldora de acción del encabezado («Ver todas»).
///
/// Usa el par `primaryContainer`/`onPrimaryContainer` del [ColorScheme]: es el
/// tono que el tema ya tiene verificado en claro (menta con tinta profunda) y
/// en oscuro (verde hondo con tinta luminosa), así la píldora se lee en los dos
/// modos sin volver a medir el contraste a mano.
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = colors.onPrimaryContainer;
    final radius = BorderRadius.circular(AppRadius.pill);
    return PressScale(
      scale: 0.94,
      child: Material(
        color: colors.primaryContainer,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.xs + 3,
              AppSpace.sm,
              AppSpace.xs + 3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.text.labelMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Icon(Icons.arrow_forward_rounded, size: 15, color: ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
