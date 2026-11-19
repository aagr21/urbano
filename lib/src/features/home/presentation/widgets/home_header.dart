import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../../../core/widgets/urbano_menu.dart'
    show showUrbanoMenu, UrbanoSection;
import 'home_route_lattice.dart';

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    // En oscuro el aqua de marca se apaga al secundario del tema: el mismo
    // tono brillante del modo claro se leía como neón sobre el grafito.
    final aqua = dark ? colors.secondary : AppColors.aqua;

    return Stack(
      children: [
        // Anillos de la ciudad de fondo: la marca se mueve sola en cuanto
        // abre la app, pero a esta opacidad se lee como textura, no como
        // dibujo.
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
            // El área del sistema queda sobre el lienzo (mint + anillos) y la
            // banda oficial arranca debajo, como una franja blanca a sangre:
            // el reloj y los íconos no caen sobre el blanco de la franja.
            SizedBox(height: topInset),
            const _OfficialBand(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg + AppSpace.xs,
                AppSpace.lg,
                AppSpace.lg + AppSpace.xs,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // La marca va centrada en el ancho de la cabecera y el menú
                  // flota a la derecha, como en la referencia: no comparten
                  // fila, así el wordmark no se descentra al abrir el menú.
                  Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [
                                      colors.primary,
                                      aqua,
                                      colors.primary,
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    Env.appName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.wordmark(
                                      text.headlineMedium?.copyWith(
                                        color: colors.primary,
                                        fontSize: 34,
                                        height: 1,
                                        letterSpacing: -1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 2,
                                  bottom: 7,
                                ),
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [aqua, colors.primary],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: aqua.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Env.tagline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: text.labelMedium?.copyWith(
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
                  const _LocationPill(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Banda oficial de la portada.
///
/// Firma la app como servicio del municipio: escudo a la izquierda y la
/// píldora «Transporte Oficial» a la derecha, sobre una franja clara que
/// separa la cabecera del lienzo de la portada. Va a sangre horizontal; el
/// área del sistema la resuelve [HomeHeader] con su respiro de lienzo.
class _OfficialBand extends StatelessWidget {
  const _OfficialBand();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Franja casi blanca: en claro es el blanco de las tarjetas teñido apenas
    // de aqua (la referencia no la pinta blanca pura); en oscuro sigue la
    // superficie del tema, nunca una losa clara.
    final fill = dark
        ? colors.surface
        : AppColors.tint(AppColors.aqua, colors.surface, 0.04);
    final hairline = dark
        ? AppColors.lineDark
        : colors.outlineVariant.withValues(alpha: 0.7);

    return DecoratedBox(
      key: const ValueKey('home-official-band'),
      decoration: BoxDecoration(
        color: fill,
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg + AppSpace.xs,
          AppSpace.sm,
          AppSpace.lg + AppSpace.xs,
          AppSpace.sm,
        ),
        child: Row(
          children: [
            // El escudo es una imagen: se escala, nunca se redibuja.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Semantics(
                  label:
                      'Gobierno Autónomo Municipal de Santa Cruz de la Sierra',
                  image: true,
                  child: const _OfficialSeal(),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            const _OfficialPill(),
          ],
        ),
      ),
    );
  }
}

/// Escudo oficial en PNG (fondo transparente).
///
/// En claro cae directamente sobre la franja; en oscuro el trazo negro del
/// escudo se perdería contra el grafito, así que se monta en una placa blanca
/// —el único blanco duro del archivo, y está justificado: la imagen es fija y
/// no puede recolorearse por tema—.
class _OfficialSeal extends StatelessWidget {
  const _OfficialSeal();

  static const String _asset = 'assets/images/gobierno-santa-cruz.png';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final image = Image.asset(
      _asset,
      height: 34,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      // El escudo ya viene recortado; se declara su tamaño real para que el
      // layout no dependa del decodificado asíncrono.
      width: 34 * 900 / 370,
    );
    if (!dark) return image;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: image,
    );
  }
}

/// Píldora «Transporte Oficial»: punto aqua, filete de marca y tinta legible
/// sobre el relleno realmente pintado.
class _OfficialPill extends StatelessWidget {
  const _OfficialPill();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppColors.tint(
      colors.primary,
      colors.surface,
      dark ? 0.18 : 0.07,
    );
    final ink = dark
        ? colors.onSurface
        : AppColors.legible(colors.primary, fill);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dark ? colors.secondary : AppColors.aqua,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpace.sm - 2),
          Text(
            'Transporte Oficial',
            maxLines: 1,
            style: text.labelSmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón redondo del menú: una hoja blanca (o de superficie en oscuro) con
/// sombra suave, como en la referencia.
class _MenuButton extends StatelessWidget {
  const _MenuButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.pill);
    // En oscuro el botón sigue el lienzo: ícono y filete blancos, sin una
    // pastilla clara que compita con la marca.
    final iconInk = colors.onSurface;

    return PressScale(
      scale: 0.92,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: dark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  ...AppTheme.softShadow(opacity: 0.07, blur: 16, dy: 6),
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            splashColor: iconInk.withValues(alpha: 0.08),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [
                          colors.surface,
                          AppColors.tint(colors.primary, colors.surface, 0.10),
                        ]
                      : [
                          colors.surface,
                          AppColors.tint(AppColors.aqua, colors.surface, 0.08),
                        ],
                ),
                border: Border.all(
                  color: dark
                      ? AppColors.lineStrongDark
                      : colors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Center(
                child: Tooltip(
                  message: 'Menú',
                  child: Icon(Icons.menu_rounded, size: 22, color: iconInk),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Tu ubicación ›»: una píldora blanca centrada bajo la marca.
///
/// El estado de permisos se cuenta con el ícono y la etiqueta, y se toca para
/// activar o refrescar. Sin ubicación la píldora invita («Usar mi ubicación»);
/// con ubicación resume y deja refrescar.
class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final location = ref.watch(myLocationProvider);

    final ({IconData icon, String label, VoidCallback? onTap}) state = location
        .when(
          loading: () => (
            icon: Icons.location_searching_rounded,
            label: 'Buscando ubicación…',
            onTap: null,
          ),
          error: (error, _) => (
            icon: Icons.location_off_rounded,
            label: error is LocationFailure
                ? error.friendlyMessage
                : 'Ubicación no disponible',
            onTap: () => ref.invalidate(myLocationProvider),
          ),
          data: (position) => position == null
              ? (
                  icon: Icons.near_me_rounded,
                  label: 'Usar mi ubicación',
                  onTap: () => _activate(context, ref),
                )
              : (
                  icon: Icons.location_on_rounded,
                  label: 'Tu ubicación',
                  onTap: () => ref.invalidate(myLocationProvider),
                ),
        );

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md + 2,
        vertical: AppSpace.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(state.icon, size: 18, color: colors.primary),
          const SizedBox(width: AppSpace.xs + 2),
          Flexible(
            child: Text(
              state.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (state.onTap != null) ...[
            const SizedBox(width: AppSpace.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: colors.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    final radius = BorderRadius.circular(AppRadius.pill);
    final shell = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(
          color: dark
              ? AppColors.lineDark
              : colors.outlineVariant.withValues(alpha: 0.8),
        ),
        boxShadow: dark
            ? null
            : AppTheme.softShadow(opacity: 0.05, blur: 14, dy: 4),
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: state.onTap == null
            ? content
            : InkWell(
                onTap: state.onTap,
                borderRadius: radius,
                splashColor: colors.onSurface.withValues(alpha: 0.06),
                child: content,
              ),
      ),
    );

    return Center(child: shell);
  }

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    try {
      final outcome = await ref.requestMyLocation();
      if (outcome == PermissionOutcome.granted || !context.mounted) return;
      context.showSnack(
        outcome == PermissionOutcome.deniedForever
            ? 'Permiso bloqueado. Actívalo desde la configuración de tu teléfono.'
            : 'Permiso de ubicación denegado.',
        isError: true,
      );
    } on LocationFailure catch (failure) {
      if (context.mounted) {
        context.showSnack(failure.friendlyMessage, isError: true);
      }
    }
  }
}
