import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../core/utils/extensions.dart';
import 'home_location_pill.dart';
import 'home_official_band.dart';
import 'home_route_lattice.dart';
import 'home_wordmark.dart';

/// **Cabecera de Inicio**, sobre el lienzo de la portada.
///
/// La referencia abre con dos franjas: la **banda oficial** —escudo del
/// Gobierno Autónomo Municipal de Santa Cruz de la Sierra a la izquierda y la
/// píldora «Transporte Oficial» a la derecha— y, debajo, la marca centrada
/// (wordmark con su punto, lema, botón de tema claro/oscuro a la derecha y la
/// píldora de ubicación). La banda es lo que firma la app como servicio municipal; el
/// escudo es una imagen (no se redibuja) y conserva su relación de aspecto.
///
/// El buscador de rutas se retiró con la poda de la portada: la pantalla debe
/// caber entera (cabecera, accesos, «¿A dónde vas?» y viajes recientes) y el
/// catálogo ya se abre desde el acceso **Micros**. La cabecera se queda en
/// banda oficial + marca + ubicación.
///
/// Encima del lienzo todo se mide con los tokens del tema ([ColorScheme]), de
/// modo que el mismo bloque funciona en claro y en oscuro sin tintas fijas.
/// La trama de anillos de Santa Cruz sigue de fondo, muy tenue, para que la
/// portada no pierda el movimiento de la marca.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        // Anillos de la ciudad de fondo.
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.55,
              child: HomeRouteLattice(tint: colors.primary),
            ),
          ),
        ),
        Column(
          children: [
            SizedBox(height: topInset),
            const HomeOfficialBand(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg + AppSpace.xs,
                AppSpace.xxl,
                AppSpace.lg + AppSpace.xs,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Escalado solo en pintura: el alto de la cabecera
                          // (y por tanto que la portada quepa sin scroll) no
                          // cambia por agrandar la marca.
                          Transform.scale(
                            scale: 1.5,
                            alignment: Alignment.bottomCenter,
                            child: const HomeWordmark(),
                          ),
                          // El trazo y la parada asoman bajo la línea base
                          // (escalados ×1,5): el lema les deja ese aire.
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            Env.tagline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Positioned(
                        right: 0,
                        top: -6,
                        child: _ThemeToggleButton(
                          key: ValueKey('home-theme-button'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  const HomeLocationPill(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Botón de **tema claro/oscuro** de la cabecera (donde antes iba el menú).
///
/// Muestra a dónde lleva, no dónde está: una luna en claro y un sol en oscuro.
/// El primer toque deja de seguir al sistema y fija el brillo contrario al que
/// se está viendo; [ThemeModeController.setMode] lo persiste para la próxima
/// sesión. El ícono gira al cambiar ([AnimatedSwitcher], sin controlador
/// propio) y, con «reducir animaciones», cambia en seco.
class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.md);
    final bg = dark ? colors.surface.withValues(alpha: 0.9) : Colors.white;
    final iconInk = dark ? colors.onSurface : HtmlDesignTokens.slate800;
    final label = dark ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro';

    return PressScale(
      scale: 0.95,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(
            color: dark ? AppColors.lineDark : HtmlDesignTokens.slate100,
          ),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => ref
                .read(themeModeControllerProvider.notifier)
                .setMode(dark ? ThemeMode.light : ThemeMode.dark),
            borderRadius: radius,
            splashColor: iconInk.withValues(alpha: 0.08),
            child: Tooltip(
              message: label,
              child: Center(
                child: AnimatedSwitcher(
                  duration: Motion.duration(context, Motion.morph),
                  switchInCurve: Motion.standard,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => RotationTransition(
                    turns: Tween<double>(
                      begin: -0.25,
                      end: 0,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Icon(
                    dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey(dark),
                    size: 22,
                    color: iconInk,
                    semanticLabel: label,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
