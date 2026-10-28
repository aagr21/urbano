import 'package:flutter/material.dart';

import '../animation/motion.dart';
import '../theme/app_theme.dart';
import '../utils/extensions.dart';

/// Estado vacío ilustrado con iconografía de Material.
///
/// Entra con el `Reveal` del kit (y no con `flutter_animate`): estos estados se
/// montan dentro de `AsyncValueView` justo cuando un test está haciendo `pump()`
/// simples, y el `Timer` de `Animate` dejaría el test con uno pendiente.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.iconColor,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Color? iconColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final tint = iconColor ?? colors.primary;

    return Reveal(
      slide: 10,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? AppSpace.lg : AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // El disco flota: un estado vacío que se mueve se lee como
              // «esperando datos», no como una pantalla muerta.
              Bob(
                amplitude: compact ? 2.5 : 4.5,
                period: const Duration(milliseconds: 2000),
                child: Container(
                  width: compact ? 72 : 96,
                  height: compact ? 72 : 96,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tint.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, size: compact ? 32 : 44, color: tint),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpace.xl),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.near_me_rounded, size: 18),
                  label: Text(actionLabel!),
                ),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: AppSpace.sm),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
