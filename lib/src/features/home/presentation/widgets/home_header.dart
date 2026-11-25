import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/urbano_menu.dart'
    show showUrbanoMenu, UrbanoSection;
import 'home_location_pill.dart';
import 'home_official_band.dart';
import 'home_route_lattice.dart';
import 'home_wordmark.dart';

/// **Cabecera de Inicio**, sobre el lienzo de la portada.
///
/// La referencia abre con dos franjas: la **banda oficial** —escudo del
/// Gobierno Autónomo Municipal de Santa Cruz de la Sierra a la izquierda y la
/// píldora «Transporte Oficial» a la derecha— y, debajo, la marca centrada
/// (wordmark con su punto, lema, botón de menú a la derecha y la píldora de
/// ubicación). La banda es lo que firma la app como servicio municipal; el
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
                      Positioned(
                        right: 0,
                        top: -6,
                        child: _MenuButton(
                          key: const ValueKey('home-menu-button'),
                          onTap: () => showUrbanoMenu(
                            context,
                            current: UrbanoSection.home,
                          ),
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

/// Botón del menú: estilo del HTML (blanco con sombra suave, bordes redondeados).
class _MenuButton extends StatelessWidget {
  const _MenuButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.md);
    final bg = dark ? colors.surface.withValues(alpha: 0.9) : Colors.white;
    final iconInk = dark ? colors.onSurface : HtmlDesignTokens.slate600;

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
            onTap: onTap,
            borderRadius: radius,
            splashColor: iconInk.withValues(alpha: 0.08),
            child: Center(
              child: Tooltip(
                message: 'Menú',
                child: _HamburgerIcon(color: iconInk),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ícono de hamburguesa del HTML: tres líneas redondeadas.
class _HamburgerIcon extends StatelessWidget {
  const _HamburgerIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 3,
        children: [_Line(), _Line(), _Line()],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 2.5,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? context.colors.onSurface
            : HtmlDesignTokens.slate800,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
