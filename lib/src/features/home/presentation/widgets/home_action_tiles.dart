import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/urbano_glyph.dart';
import 'home_navigation.dart';

/// Los cuatro accesos de la portada en una retícula de 2 × 2.
///
/// Cada acceso es una tarjeta blanca con el ícono de la marca sobre una placa
/// tonal, el nombre, su bajada y un chevrón verde (diseño «Pantalla de
/// inicio»). Son secundarios a propósito: el CTA primario es «Planifica tu
/// viaje», justo encima.
///
/// Los cuatro son destinos reales de la app:
///
/// - **Micros** abre el catálogo completo (`/micros`).
/// - **Viajes** abre la hoja de origen/destino con destinos recientes.
/// - **Lugares** abre la hoja «¿Qué micro pasa cerca?» y, con «Buscar cerca»,
///   la vista `/nearby`.
/// - **Denuncias** cambia a la rama del feed.
///
/// La entrada en cascada la pone el home (`Reveal`); aquí solo vive el pulsado.
class HomeActionTiles extends ConsumerWidget {
  const HomeActionTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.lg,
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
                    glyph: UrbanoGlyphKind.micros,
                    title: 'Micros',
                    subtitle: 'Rutas, paradas y horarios',
                    onTap: () => UrbanoRoutes.openMicrosCatalog(context),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('home-tile-journey'),
                    glyph: UrbanoGlyphKind.journey,
                    title: 'Viajes',
                    subtitle: 'Planifica tu trayecto',
                    onTap: () => openJourneyDestinationSheet(context, ref),
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
                    glyph: UrbanoGlyphKind.places,
                    title: 'Lugares',
                    subtitle: 'Qué micro pasa cerca',
                    onTap: () => openPlacesSearch(context),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _ActionTile(
                    key: const ValueKey('home-tile-complaints'),
                    glyph: UrbanoGlyphKind.complaints,
                    title: 'Denuncias',
                    subtitle: 'Reporta y ayúdanos a mejorar',
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
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final UrbanoGlyphKind glyph;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = colors.onSurface;
    final radius = BorderRadius.circular(AppRadius.lg);

    // Superficie común a los cuatro: blanca con un velo verde apenas
    // perceptible abajo a la derecha, y un filete verde suave (en el diseño la
    // tarjeta se despega del lienzo por el filete y una sombra corta).
    final surface = [
      colors.surface,
      AppColors.tint(colors.primary, colors.surface, dark ? 0.10 : 0.035),
    ];
    final border = colors.primary.withValues(alpha: dark ? 0.24 : 0.16);
    // Placa del ícono: gris verdoso claro; en oscuro, un escalón del grafito.
    final plate = dark
        ? colors.surfaceContainerHighest
        : AppColors.tint(colors.primary, const Color(0xFFF1F3F1), 0.05);
    final chevron = dark ? colors.primary : AppColors.greenDeep;

    return PressScale(
      scale: 0.97,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: surface,
          ),
          borderRadius: radius,
          border: Border.all(color: border, width: 1.2),
          boxShadow: AppTheme.softShadow(
            color: dark ? Colors.black : AppColors.primaryDark,
            opacity: dark ? 0.16 : 0.07,
            blur: 14,
            dy: 5,
          ),
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
                AppSpace.sm,
                AppSpace.sm + 2,
                2,
                AppSpace.sm + 2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(AppSpace.xs + 2),
                    decoration: BoxDecoration(
                      color: plate,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: UrbanoGlyph(glyph, size: 34),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            maxLines: 1,
                            style: text.titleMedium?.copyWith(
                              color: ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
