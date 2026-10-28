import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Acceso destacado: Planificar viaje (mapa + planeador fusionados).
///
/// Una sola tarjeta CTA con el **color sólido** de la marca en vez de fichas
/// genéricas: al ser la acción principal del home se le da peso propio, y el
/// acento coral del botón redondo hace que el ojo llegue a la flecha.
/// "Cerca de mí" se retiró junto con las paradas.
///
/// La entrada en cascada la decide el home (`Reveal`); aquí solo vive el
/// feedback de pulsado, que es lo que falta en toda tarjeta con `InkWell`.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: PressScale(scale: 0.98, child: _PlanActionCard()),
    );
  }
}

class _PlanActionCard extends StatelessWidget {
  const _PlanActionCard();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/journey'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppTheme.softShadow(
              color: AppColors.primary,
              opacity: 0.3,
              blur: 18,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    color: scheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Viajar',
                        style: context.text.titleMedium?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Marca tu destino y listo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    // Botón circular en espejo: claro → círculo blanco con
                    // ícono verde agua; oscuro (la tarjeta vira aqua) →
                    // círculo profundo con ícono luminoso, sin una tercera
                    // capa de color sobre la tarjeta.
                    color: scheme.onPrimary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: scheme.primary,
                    size: 19,
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
