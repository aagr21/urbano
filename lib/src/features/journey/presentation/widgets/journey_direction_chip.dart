import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../application/micros_catalog.dart';
import 'journey_disc_spinner.dart';

/// Chip botón de una dirección (Ida/Vuelta): forma de píldora; el relleno se
/// anima hacia el color de la línea, el texto y el icono viran al foreground
/// calculado por la tarjeta (de forma interpolada) y el check entra con
/// rebote al dibujarse. Iconos circulares (`arrow_circle`) para el sentido.
/// Muestra el headsign si el detalle de la línea ya se conoce —y sigue
/// conociéndose al reabrir el panel, porque vive en la sesión—.
class DirectionChip extends StatelessWidget {
  const DirectionChip({
    super.key,
    required this.direction,
    required this.tint,
    required this.foreground,
    required this.active,
    required this.loading,
    required this.onTap,
  });

  final MicroDirection direction;
  final Color tint;

  /// Texto/íconos sobre el relleno sólido [tint] cuando el chip está activo.
  /// Sale de `AppColors.onColor`, porque un color de línea claro (`F1C40F`)
  /// con blanco encima es tan ilegible como un oscuro sobre fondo oscuro.
  final Color foreground;
  final bool active;

  /// `true` mientras ESTE recorrido (ida/vuelta) se está cargando: el disco del
  /// sentido gira como señal de espera en lugar de mostrar su flecha.
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final headsign = direction.headsign;
    final radius = BorderRadius.circular(AppRadius.pill);
    // Relleno "vivo" del chip inactivo: una insinuación del color de la
    // línea (9%) sobre la superficie, con borde del mismo tinte — el botón
    // siempre sabe de qué línea es. Activo: relleno sólido con sombra.
    final inactiveFill = Color.lerp(colors.surface, tint, 0.09)!;
    final inactiveInk = AppColors.legible(
      colors.onSurfaceVariant,
      inactiveFill,
    );
    // Disco del ícono: el sentido se pinta en un círculo con el color de la
    // línea incluso apagado (la tarjeta es un objeto de color, no un formulario).
    final discFill = active
        ? foreground.withValues(alpha: 0.2)
        : Color.lerp(inactiveFill, tint, 0.2)!;
    final discInk = active
        ? foreground
        : AppColors.legible(tint, discFill, minContrast: 3);

    final chip = AnimatedContainer(
      duration: Motion.release,
      curve: Curves.easeOutCubic,
      height: 40,
      decoration: BoxDecoration(
        color: active ? tint : inactiveFill,
        borderRadius: radius,
        border: Border.all(
          color: active ? Colors.transparent : tint.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: active ? 0.32 : 0),
            blurRadius: active ? 12 : 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            // Un solo color interpolado para todo el contenido: texto e
            // iconos lo hereda, así el cambio ida↔activo no es un salto.
            child: TweenAnimationBuilder<Color?>(
              duration: Motion.release,
              curve: Curves.easeOut,
              tween: ColorTween(end: active ? foreground : inactiveInk),
              builder: (_, color, child) => IconTheme(
                data: IconThemeData(size: 17, color: color),
                child: DefaultTextStyle(
                  style: DefaultTextStyle.of(context).style
                      .copyWith(color: color),
                  child: child!,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Disco del sentido: el ícono lleva el color de la línea
                  // dentro de un círculo (el chip apagado también dice de
                  // quién es, sin gritar).
                  AnimatedContainer(
                    duration: Motion.release,
                    curve: Curves.easeOutCubic,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: discFill,
                    ),
                    child: TweenAnimationBuilder<Color?>(
                      duration: Motion.release,
                      curve: Curves.easeOut,
                      tween: ColorTween(end: discInk),
                      builder: (_, color, _) => loading
                          ? DiscSpinner(color: color ?? discInk)
                          : Icon(
                              direction.directionId == 0
                                  ? Icons.arrow_circle_right_outlined
                                  : Icons.arrow_circle_left_outlined,
                              size: 16,
                              color: color,
                            ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      direction.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (text.labelMedium ?? text.bodySmall)?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (headsign.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        headsign,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (text.bodySmall ?? text.labelSmall)?.copyWith(
                          fontSize: 10.5,
                          color: active
                              ? foreground.withValues(alpha: 0.88)
                              : inactiveInk,
                        ),
                      ),
                    ),
                  ],
                  if (active && !loading) ...[
                    const SizedBox(width: 5),
                    // El check entra con rebote la primera vez que se
                    // dibuja (TweenAnimationBuilder arranca en `begin`).
                    TweenAnimationBuilder<double>(
                      duration: Motion.morph,
                      curve: Curves.easeOutBack,
                      tween: Tween(begin: 0.3, end: 1),
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: const Icon(Icons.check_circle_rounded, size: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // La píldora marca y da tamaño al Stack; el barrido de espera va ENCIMA,
    // recortado al radio de la píldora e ignorando toques (el InkWell sigue
    // siendo el dueño del gesto).
    return Stack(
      children: [
        chip,
        if (loading)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: radius,
              child: IgnorePointer(child: _ChipShimmer(tint: tint)),
            ),
          ),
      ],
    );
  }
}

/// Barrido de espera que recorre el chip mientras se pide SU recorrido. Es el
/// mismo lenguaje del [LoadingShimmer] de la casa (un destello que entra y sale
/// por los bordes, leído como «está pasando algo», no como espera muerta), pero
/// teñido con el color de la línea: una franja clara cruza la píldora de
/// izquierda a derecha. Lo mueve un [Ambient] —kit sancionado—, así respeta
/// «reducir animaciones» (banda fuera de escena, quieta) y acota sus vueltas
/// bajo `flutter test` para que `pumpAndSettle` converja.
class _ChipShimmer extends StatelessWidget {
  const _ChipShimmer({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Ambient(
      period: const Duration(milliseconds: 1300),
      builder: (context, _, phase, _) {
        // Viaja de fuera-del-borde-izquierdo a fuera-del-borde-derecho; en los
        // extremos la banda está entera fuera, así el reinicio del bucle no
        // produce salto visible.
        final cx = -1.6 + 3.2 * phase;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(cx - 0.5, -0.3),
              end: Alignment(cx + 0.5, 0.3),
              colors: [
                Colors.transparent,
                Color.lerp(tint, Colors.white, 0.6)!.withValues(alpha: 0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
