import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Sección numerada del formulario de queja.
///
/// Convierte una pila de cajas en un formulario que se entiende de un
/// vistazo: número de paso, título, ícono y contenido.
class ComplaintFormSection extends StatelessWidget {
  const ComplaintFormSection({
    super.key,
    required this.step,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  /// Número del paso: convierte una pila de cajas en un formulario que se
  /// entiende de un vistazo.
  final int step;
  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final badgeFill = AppColors.tint(colors.primary, colors.surface, 0.14);
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeFill,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '$step',
                  style: TextStyle(
                    color: AppColors.legible(colors.primary, badgeFill),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Icon(icon, size: 18, color: colors.onSurfaceVariant),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          child,
        ],
      ),
    );
  }
}
