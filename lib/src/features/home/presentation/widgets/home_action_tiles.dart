import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../../journey/application/journey_planner_controller.dart';
import '../../../journey/presentation/widgets/journey_destination_sheet.dart';
import '../../../nearby/presentation/nearby_search_sheet.dart';
import 'home_action_illustrations.dart';

/// Los cuatro accesos de la portada en una retícula de 2 × 2.
///
/// Cada cuadro es una tarjeta de superficie común (velo de laguna), una placa con
/// la ilustración propia (que flota y cuyo halo respira), una píldora con la
/// categoría y el nombre con su bajada. Los cuadros son deliberadamente
/// compactos: la portada tiene que mostrar también «¿A dónde vas?» y los viajes
/// recientes sin scroll, así que la ilustración, los espacios y la tipografía
/// van por debajo del tamaño de una tarjeta de contenido.
///
/// Los cuatro son destinos reales de la app:
///
/// - **Micros** abre el catálogo completo en su propia pantalla (`/micros`).
/// - **Viajes** abre el sheet de origen/destino con destinos recientes.
/// - **Lugares** abre la hoja «¿Qué micro pasa cerca?» (escribir, GPS o
///   mapa + radio) y, con «Buscar cerca», la vista `/nearby` con las líneas
///   que pasan por ahí, su sentido y su recorrido con flechas.
/// - **Denuncias** cambia a la rama del feed.
///
/// La entrada en cascada la pone el home (`Reveal`); aquí solo vive el pulsado.
class HomeActionTiles extends ConsumerWidget {
  const HomeActionTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> openPlaces() async {
      final query = await showNearbySearchSheet(context);
      if (query == null || !context.mounted) return;
      await context.push(UrbanoRoutes.nearby(query));
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
                    badge: 'Recorridos',
                    badgeBg: HtmlDesignTokens.rose50,
                    badgeInk: HtmlDesignTokens.redMaterial,
                    art: HomeActionArt.micros,
                    title: 'Micros',
                    subtitle: 'Información de rutas',
                    arrowHoverBg: HtmlDesignTokens.rose50,
                    arrowHoverInk: HtmlDesignTokens.redMaterial,
                    onTap: () => UrbanoRoutes.openMicrosCatalog(context),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('home-tile-journey'),
                    badge: 'Planificador',
                    badgeBg: HtmlDesignTokens.cyan50,
                    badgeInk: HtmlDesignTokens.microDarker,
                    art: HomeActionArt.journey,
                    title: 'Viajes',
                    subtitle: 'Planifica tu trayecto',
                    phaseOffset: 0.25,
                    arrowHoverBg: HtmlDesignTokens.cyan50,
                    arrowHoverInk: HtmlDesignTokens.microDark,
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
                    badgeBg: HtmlDesignTokens.green50,
                    badgeInk: HtmlDesignTokens.greenDark,
                    art: HomeActionArt.places,
                    title: 'Lugares',
                    subtitle: 'Qué micro pasa cerca',
                    phaseOffset: 0.5,
                    arrowHoverBg: HtmlDesignTokens.green50,
                    arrowHoverInk: HtmlDesignTokens.greenDark,
                    onTap: openPlaces,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('home-tile-complaints'),
                    badge: 'Atención',
                    badgeBg: HtmlDesignTokens.rose50Light,
                    badgeInk: HtmlDesignTokens.redDark,
                    art: HomeActionArt.complaints,
                    title: 'Denuncias',
                    subtitle: 'Reclamos y alertas',
                    phaseOffset: 0.75,
                    arrowHoverBg: HtmlDesignTokens.rose50,
                    arrowHoverInk: HtmlDesignTokens.redDark,
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
    required this.badgeBg,
    required this.badgeInk,
    required this.art,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.arrowHoverBg,
    required this.arrowHoverInk,
    this.phaseOffset = 0,
  });

  final String badge;
  final Color badgeBg;
  final Color badgeInk;
  final HomeActionArt art;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Colores del botón de acción al pasar el dedo.
  final Color arrowHoverBg;
  final Color arrowHoverInk;

  /// Desfase de la flotación ambiente (`0..1`).
  final double phaseOffset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = colors.onSurface;
    final inkSoft = colors.onSurfaceVariant;
    final radius = BorderRadius.circular(AppRadius.lg);

    // Los cuatro cuadros comparten superficie en los dos temas: un velo de
    // laguna apenas perceptible en la esquina y un filete neutro. Antes, en
    // claro, cada uno llevaba su degradado pastel y su borde de color, y la
    // retícula competía con «¿A dónde vas?» (el CTA primario). La identidad
    // de cada acceso la lleva su píldora, no el fondo.
    final bgColors = [
      AppColors.tint(colors.primary, colors.surface, dark ? 0.16 : 0.07),
      colors.surface,
      colors.surface,
    ];
    final border = dark
        ? colors.primary.withValues(alpha: 0.2)
        : colors.outlineVariant;

    // Placa tonal de la ilustración: relleno sin filete (la tarjeta ya tiene
    // uno; dos bordes anidados se leían como «caja dentro de caja»).
    final plateFill = dark
        ? Colors.white.withValues(alpha: 0.055)
        : AppColors.tint(colors.primary, colors.surface, 0.06);

    return PressScale(
      scale: 0.97,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgColors,
          ),
          borderRadius: radius,
          border: Border.all(color: border, width: 0.9),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: 0.12)
                  : AppColors.ink.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: ink.withValues(alpha: 0.06),
            highlightColor: ink.withValues(alpha: 0.04),
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.sm + 2,
                AppSpace.md,
                AppSpace.sm + 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: _Badge(
                          label: badge,
                          fill: badgeBg,
                          ink: badgeInk,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: dark
                              ? colors.surface.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: dark
                                  ? Colors.black.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 14,
                          color: dark
                              ? colors.onSurface
                              : HtmlDesignTokens.slate400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs + 2),
                  Center(
                    child: _ArtStage(
                      art: art,
                      dark: dark,
                      plateFill: plateFill,
                      phaseOffset: phaseOffset,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.15,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
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

/// Píldora de categoría de un acceso.
///
/// Ninguna lleva punto vivo: la app no tiene posiciones de micros en tiempo
/// real, así que nada en la portada debe sugerir «en vivo».
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.fill, required this.ink});

  final String label;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: ink.withValues(alpha: 0.32), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placa tonal con la ilustración del acceso.
///
/// La pieza flota un par de píxeles y el halo respira con la misma onda:
/// es el único movimiento de la tarjeta y va desfasado entre las cuatro
/// para que la retícula no lata al unísono. Con «reducir animaciones» se
/// queda quieta en su estado de reposo.
class _ArtStage extends StatelessWidget {
  const _ArtStage({
    required this.art,
    required this.dark,
    required this.plateFill,
    required this.phaseOffset,
  });

  final HomeActionArt art;
  final bool dark;
  final Color plateFill;
  final double phaseOffset;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final colors = context.colors;
    return Ambient(
      period: const Duration(milliseconds: 3200),
      builder: (context, t, phase, _) {
        final p = (phase + phaseOffset) % 1;
        final wave = math.sin(p * 2 * math.pi);
        final bob = reduced ? 0.0 : wave * 2.2;
        final breath = reduced ? 0.5 : 0.5 + 0.5 * wave;

        return Container(
          height: 60,
          width: 106,
          decoration: BoxDecoration(
            color: plateFill,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo que respira sobre la placa.
              Opacity(
                opacity: (0.30 + 0.55 * breath).clamp(0.0, 1.0),
                child: Container(
                  width: 82,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.primary.withValues(alpha: dark ? 0.32 : 0.22),
                        colors.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, -bob),
                child: HomeActionIllustration(art, size: const Size(92, 54)),
              ),
            ],
          ),
        );
      },
    );
  }
}
