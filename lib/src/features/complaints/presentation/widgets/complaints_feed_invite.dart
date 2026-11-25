// Cierre del feed de quejas: invita a reportar y enseña el doble toque.

import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Tarjeta que cierra el feed de quejas.
///
/// Con pocos reportes la pantalla quedaba media vacía bajo la última tarjeta:
/// ese hueco ahora invita a reportar (el CTA es el mismo «Crear» de la
/// cabecera, que a esa altura ya se fue con el scroll) y enseña el gesto del
/// feed —doble toque sobre una foto para apoyar—, que de otro modo no se
/// descubre. Va al final de la lista, así que no toca la regla de la cortina:
/// la primera queja sigue entrando entera.
class ComplaintsFeedInvite extends StatelessWidget {
  const ComplaintsFeedInvite({
    super.key,
    required this.onCreate,
    this.index = 0,
  });

  final VoidCallback onCreate;

  /// Posición en la lista, para escalonar su entrada con las tarjetas.
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final surface = colors.surfaceContainerLow;
    final disc = AppColors.tint(colors.primary, surface, 0.14);
    final discInk = AppColors.legible(colors.primary, disc);
    final heart = AppColors.legible(colors.error, surface);

    return Reveal(
      key: const ValueKey('complaints-feed-invite'),
      index: index,
      slide: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: disc,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      size: 24,
                      color: discInk,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text(
                      '¿Viste algo en tu micro?',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Cuéntalo en un minuto, con la línea y una foto: cada '
                'reporte ayuda a que el servicio mejore.',
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('complaints-invite-create'),
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_comment_rounded, size: 20),
                  label: const Text('Reportar algo'),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              // El gesto del feed, dicho una vez y en voz baja.
              Row(
                children: [
                  Icon(Icons.favorite_rounded, size: 16, color: heart),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Toca dos veces la foto de un reporte para apoyarlo.',
                      style: text.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
