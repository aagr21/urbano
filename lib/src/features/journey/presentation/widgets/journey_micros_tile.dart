import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../../core/widgets/route_photo.dart';
import '../../../routes/data/route_models.dart';
import 'journey_micros_sheet.dart';

// Tarjetas del **panel de micros**: la tarjeta de una línea (con sus botones
// Ida/Vuelta) y la píldora de recorridos dibujados. Es UI pura por props y
// callbacks: el estado (qué recorridos están en el mapa, la búsqueda, el
// scroll) vive en la pantalla padre y en la sesión del panel.

/// Una dirección de un micro: id GTFS (0 = ida, 1 = vuelta) + headsign
/// conocido (vacío si el detalle aún no se cargó).
class MicroDirection {
  const MicroDirection(this.directionId, this.headsign);

  final int directionId;
  final String headsign;

  String get label => directionId == 0 ? 'Ida' : 'Vuelta';
}

/// Tarjeta de una línea: **foto del micro como banner a todo el ancho** del
/// card (si el feed la trae), con el numeral flotando a la izquierda y la
/// píldora de recorridos a la derecha —ambas sobre la imagen—, y el nombre y
/// los botones Ida/Vuelta debajo. Sin foto, la franja del banner la ocupa el
/// tinte GTFS de la línea. La tarjeta **responde al estado**: con recorrido
/// dibujado se tiñe, el borde se engrosa, flota una sombra de color y el
/// numeral da un salto; mientras su toggle anda en vuelo se atenúa apenas.
/// `locked` bloquea los toques cuando OTRA dirección está en vuelo.
class JourneyMicroTile extends StatelessWidget {
  const JourneyMicroTile({
    super.key,
    required this.micro,
    required this.directions,
    required this.activeDirectionKeys,
    required this.busyKey,
    required this.locked,
    required this.onToggle,
  });

  final RouteSummary micro;
  final List<MicroDirection> directions;
  final Set<String> activeDirectionKeys;
  final String? busyKey;
  final bool locked;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final tint = AppColors.fromHex(micro.color);
    final busy = (busyKey ?? '').startsWith('${micro.id}#');
    final activeCount = directions
        .map((d) => microDirectionKey(micro.id, d.directionId))
        .where(activeDirectionKeys.contains)
        .length;
    final alive = activeCount > 0;
    // Fondo **real** de la tarjeta: el tinte del GTFS va mezclado al 7% sobre
    // la superficie. Se calcula aquí porque todo lo que se pinte encima tiene
    // que contrastar con lo que hay detrás de verdad (regla de la casa: nada
    // oscuro sobre oscuro). El color de línea puede ser `2C3E50` (casi negro)
    // o `F1C40F` (casi blanco), así que nunca se usa tal cual para letras.
    final cardBackground = Color.lerp(colors.surface, tint, alive ? 0.07 : 0)!;
    final border = alive
        ? AppColors.legible(tint, cardBackground, minContrast: 3)
        : colors.outlineVariant;
    // Foreground sobre el relleno **sólido** del chip: lo decide el contraste
    // contra el color de la línea, respetando el `textColor` del feed.
    final onTint = AppColors.onColor(
      tint,
      preferred: AppColors.fromHex(micro.textColor),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 170),
      opacity: busy ? 0.62 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        scale: busy ? 0.985 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border, width: alive ? 1.4 : 1),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: alive ? 0.16 : 0),
                blurRadius: alive ? 16 : 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner a todo el ancho: la foto se ve COMPLETA a lo
                // vertical (el sobrante horizontal lo rellena la misma foto
                // difuminada); numeral flotando abajo a la izquierda y
                // píldora de recorridos arriba a la derecha.
                Container(
                  height: 132,
                  color: tint,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (micro.imageUrl != null)
                        RoutePhoto(
                          url: micro.imageUrl!,
                          radius: BorderRadius.zero,
                          fit: BoxFit.fitHeight,
                          showFull: true,
                        ),
                      // Un solo scrub que cubre de arriba a abajo para
                      // garantizar contraste para numeral y píldora sin
                      // importar la foto (cielo claro, techo blanco…).
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.62),
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                        ),
                      ),
                      // Barra acento al pie del banner: existe VISIBLEMENTE
                      // cuando la línea tiene recorrido dibujado.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AnimatedContainer(
                          key: const ValueKey('route-accent-bar'),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: alive ? 3 : 0,
                          color: tint,
                        ),
                      ),
                      // Numeral: literal el cartel del parabrisas, flotando
                      // del banner.
                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutBack,
                          scale: alive ? 1.06 : 1,
                          child: RouteBadge(
                            label: micro.shortName,
                            colorHex: micro.color,
                            textColorHex: micro.textColor,
                          ),
                        ),
                      ),
                      // Píldora con los recorridos dibujados: siempre en el
                      // árbol (a escala 0 si no hay nada) para que al
                      // activar la fila no salte.
                      Positioned(
                        right: 10,
                        top: 10,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: alive ? 1 : 0,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            scale: alive ? 1 : 0.5,
                            child: _ActivePill(
                              count: activeCount,
                              tint: tint,
                              cardBackground: colors.surface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenido debajo del banner: nombre y botones.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          micro.longName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (micro.imageUrl == null) ...[
                        const SizedBox(width: 8),
                        // Sin foto el numeral acompaña al nombre, como
                        // pasaba antes, en tamaño reducido.
                        RouteBadge(
                          label: micro.shortName,
                          colorHex: micro.color,
                          textColorHex: micro.textColor,
                          size: RouteBadgeSize.small,
                        ),
                      ],
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Row(
                    children: [
                      for (var i = 0; i < directions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _DirectionChip(
                            direction: directions[i],
                            tint: tint,
                            foreground: onTint,
                            active: activeDirectionKeys.contains(
                              microDirectionKey(
                                micro.id,
                                directions[i].directionId,
                              ),
                            ),
                            onTap: locked
                                ? null
                                : () => onToggle(directions[i].directionId),
                          ),
                        ),
                      ],
                    ],
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

/// Píldora con el número de recorridos activos de una línea.
class _ActivePill extends StatelessWidget {
  const _ActivePill({
    required this.count,
    required this.tint,
    required this.cardBackground,
  });

  final int count;
  final Color tint;

  /// Color de la tarjeta detrás de la píldora, para calcular el contraste.
  final Color cardBackground;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    // El relleno de la píldora es el tinte al 16% sobre la tarjeta: el número
    // y el ícono contrastan contra **esa mezcla**, no contra la superficie ni
    // contra el tinte puro (un `2C3E50` sobre una hoja oscura sería ilegible).
    final background = Color.lerp(cardBackground, tint, 0.16)!;
    final ink = AppColors.legible(tint, background);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 11, color: ink),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: (text.labelSmall ?? text.bodySmall)?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip botón de una dirección (Ida/Vuelta): forma de píldora; el relleno se
/// anima hacia el color de la línea, el texto y el icono viran al foreground
/// calculado por la tarjeta (de forma interpolada) y el check entra con
/// rebote al dibujarse. Iconos circulares (`arrow_circle`) para el sentido.
/// Muestra el headsign si el detalle de la línea ya se conoce —y sigue
/// conociéndose al reabrir el panel, porque vive en la sesión—.
class _DirectionChip extends StatelessWidget {
  const _DirectionChip({
    required this.direction,
    required this.tint,
    required this.foreground,
    required this.active,
    required this.onTap,
  });

  final MicroDirection direction;
  final Color tint;

  /// Texto/íconos sobre el relleno sólido [tint] cuando el chip está activo.
  /// Sale de `AppColors.onColor`, porque un color de línea claro (`F1C40F`)
  /// con blanco encima es tan ilegible como un oscuro sobre fondo oscuro.
  final Color foreground;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final headsign = direction.headsign;
    final radius = BorderRadius.circular(AppRadius.pill);
    // Relleno "vivo" del chip inactivo: una insinuación del color de la
    // línea (8%) sobre la superficie, con borde del mismo tinte — el botón
    // siempre sabe de qué línea es. Activo: relleno sólido con sombra.
    final Color inactiveFill = colors.surfaceContainerHighest.withValues(
      alpha: colors.brightness == Brightness.dark ? 0.55 : 0.85,
    );

    return PressScale(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
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
              // iconos lo heredan, así el cambio ida↔activo no es un salto.
              child: TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                tween: ColorTween(
                  end: active ? foreground : colors.onSurfaceVariant,
                ),
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
                    Icon(
                      direction.directionId == 0
                          ? Icons.arrow_circle_right_outlined
                          : Icons.arrow_circle_left_outlined,
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
                                ? foreground.withValues(alpha: 0.85)
                                : colors.onSurfaceVariant.withValues(
                                    alpha: 0.8,
                                  ),
                          ),
                        ),
                      ),
                    ],
                    if (active) ...[
                      const SizedBox(width: 5),
                      // El check entra con rebote la primera vez que se
                      // dibuja (TweenAnimationBuilder arranca en `begin`).
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 260),
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
      ),
    );
  }
}
