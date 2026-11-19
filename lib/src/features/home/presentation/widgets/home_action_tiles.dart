import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../journey/application/journey_planner_controller.dart';
import '../../../journey/application/journey_providers.dart';
import '../../../journey/presentation/widgets/journey_destination_sheet.dart';
import 'home_action_illustrations.dart';

/// Los cuatro accesos de la portada en una retícula de 2 × 2.
///
/// Es el bloque que abre la referencia: cada cuadro lleva una píldora con su
/// categoría, un punto de color, una ilustración propia y el nombre con su
/// bajada. Los cuadros son deliberadamente compactos: la portada tiene que
/// mostrar también «¿A dónde vas?» y los viajes recientes sin scroll, así que
/// la ilustración, los espacios y la tipografía van por debajo del tamaño de
/// una tarjeta de contenido. Los cuatro son destinos reales de la app:
///
/// - **Micros** abre el catálogo completo en su propia pantalla (`/micros`).
/// - **Viajes** abre el sheet de origen/destino con destinos recientes.
/// - **Lugares** entra al planificador con el panel de origen/destino abierto
///   (elegir un punto es elegir un lugar).
/// - **Denuncias** cambia a la rama del feed.
///
/// La entrada en cascada la pone el home (`Reveal`); aquí solo vive el pulsado.
class HomeActionTiles extends ConsumerWidget {
  const HomeActionTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openPlaces() {
      ref.read(pendingPlannerPanelProvider.notifier).state = true;
      context.go('/journey');
    }

    Future<void> openJourneySheet() async {
      final planner = ref.read(journeyPlannerControllerProvider);
      await showJourneyDestinationSheet(
        context: context,
        ref: ref,
        initialOrigin: planner.origin,
        initialDestination: planner.destination,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg + AppSpace.xs,
        AppSpace.md,
        AppSpace.lg + AppSpace.xs,
        0,
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('home-tile-micros'),
                    badge: 'Líneas en vivo',
                    art: HomeActionArt.micros,
                    title: 'Micros',
                    subtitle: 'Rutas y frecuencias',
                    accent: AppColors.accentDeep,
                    onTap: () => UrbanoRoutes.openMicrosCatalog(context),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('home-tile-journey'),
                    badge: 'Planificador',
                    art: HomeActionArt.journey,
                    title: 'Viajes',
                    subtitle: 'Planifica tu trayecto',
                    accent: AppColors.primaryDark,
                    onTap: openJourneySheet,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('home-tile-places'),
                    badge: 'Puntos clave',
                    art: HomeActionArt.places,
                    title: 'Lugares',
                    subtitle: 'Paradas y puntos',
                    accent: AppColors.aquaDeep,
                    onTap: openPlaces,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('home-tile-complaints'),
                    badge: 'Atención ciudadana',
                    art: HomeActionArt.complaints,
                    title: 'Denuncias',
                    subtitle: 'Reclamos y alertas',
                    accent: AppColors.accent,
                    onTap: () => context.go('/complaints'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.badge,
    required this.art,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = AppColors.primary,
  });

  final String badge;
  final HomeActionArt art;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Acento del punto y de la píldora. La tinta de la píldora se mide contra
  /// el relleno realmente pintado, no contra el tema.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // En oscuro la tarjeta sigue siendo grafito: el blanco entra por las
    // letras, los íconos y el filete del borde, no por una superficie clara
    // que convertiría la portada en otra app.
    final ink = colors.onSurface;
    final inkSoft = colors.onSurfaceVariant;
    final fill = AppColors.tint(accent, colors.surface, 0.12);
    final badgeInk = AppColors.legible(accent, fill);
    final radius = BorderRadius.circular(AppRadius.lg);
    // Todos los accesos comparten el mismo relleno plano que «Tus viajes
    // recientes»: el color de la tarjeta es uno solo (surface) y el acento
    // vive únicamente en la píldora, el punto y la ilustración. Nada de
    // degradados ni tintes distintos por tarjeta.
    final hairline = dark
        ? AppColors.lineDark
        : colors.outlineVariant.withValues(alpha: 0.7);

    return PressScale(
      scale: 0.97,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: dark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : AppTheme.softShadow(opacity: 0.05, blur: 18),
        ),
        child: Material(
          color: colors.surface,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: ink.withValues(alpha: 0.06),
            highlightColor: ink.withValues(alpha: 0.04),
            borderRadius: radius,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.sm + 2,
                AppSpace.md,
                AppSpace.sm + 2,
              ),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: hairline, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          // La etiqueta más larga («Atención ciudadana») no
                          // cabe a ancho de móvil con la fuente de los tests:
                          // se encoge en vez de desbordar la píldora.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              badge,
                              maxLines: 1,
                              style: text.labelSmall?.copyWith(
                                color: badgeInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Center(
                    child: HomeActionIllustration(
                      art,
                      size: const Size(84, 48),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
