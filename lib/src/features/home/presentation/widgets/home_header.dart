import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/urbano_logo.dart';
import 'home_official_seal.dart';

/// **Cabecera de Inicio**: una sola franja con las dos firmas de la app.
///
/// A la izquierda, el escudo del Gobierno Autónomo Municipal de Santa Cruz de
/// la Sierra (imagen oficial, se escala pero no se redibuja); a la derecha, el
/// logotipo de Urbano con su lema, y en la esquina el botón de tema
/// claro/oscuro. Es la cabecera del diseño «Pantalla de inicio»: no hay
/// banda aparte ni píldora de ubicación; el CTA «Planifica tu viaje» va justo
/// debajo.
///
/// Escudo y logo se reparten el ancho con `FittedBox(scaleDown)`: en el
/// teléfono más angosto se achican juntos en vez de desbordar.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      key: const ValueKey('home-official-band'),
      padding: EdgeInsets.fromLTRB(
        AppSpace.lg,
        topInset + AppSpace.md,
        AppSpace.lg,
        AppSpace.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        label:
                            'Gobierno Autónomo Municipal de Santa Cruz de la '
                            'Sierra',
                        image: true,
                        child: const HomeOfficialSeal(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  const Expanded(
                    flex: 11,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: UrbanoLogo(key: ValueKey('home-logo')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          const _ThemeToggleButton(key: ValueKey('home-theme-button')),
        ],
      ),
    );
  }
}

/// Botón de **tema claro/oscuro** de la cabecera.
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
    final bg = dark ? colors.surfaceContainerHigh : colors.surface;
    final iconInk = dark ? colors.onSurface : AppColors.ink;
    final label = dark ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro';

    return PressScale(
      scale: 0.95,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(
            color: dark ? AppColors.lineDark : colors.outlineVariant,
          ),
          boxShadow: AppTheme.softShadow(
            color: Colors.black,
            opacity: dark ? 0.25 : 0.07,
            blur: 16,
            dy: 4,
          ),
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
                    size: 24,
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
