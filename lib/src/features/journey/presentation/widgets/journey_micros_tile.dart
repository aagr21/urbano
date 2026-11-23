import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../../core/widgets/route_photo.dart';
import '../../../routes/data/route_models.dart';
import '../../application/micros_catalog.dart';
import 'journey_direction_chip.dart';
import 'journey_meta_pill.dart';

// Tarjetas del **panel de micros**: la tarjeta de una línea (con sus botones
// Ida/Vuelta) y la píldora de recorridos dibujados. Es UI pura por props y
// callbacks: el estado (qué recorridos están en el mapa, la búsqueda, el
// scroll) vive en el controller del panel y en su sesión.

/// Tarjeta de una línea: **foto del micro como banner a todo el ancho** del
/// card (si el feed la trae), con el numeral flotando a la izquierda y la
/// píldora de recorridos a la derecha —ambas sobre la imagen—, y el nombre, los
/// datos de la línea y los botones Ida/Vuelta debajo. Sin foto, la franja del
/// banner la ocupa el tinte GTFS de la línea (en degradado). La tarjeta
/// **responde al estado**: con recorrido dibujado se tiñe, el borde se engrosa,
/// flota una sombra de color y el numeral da un salto; mientras su toggle anda
/// en vuelo la tarjeta se atenúa apenas (lo justo para no verse muerta — la
/// foto sigue viva) y el botón de la dirección que se está cargando se llena de
/// un barrido de luz del color de la línea sobre su disco girando. `locked`
/// bloquea los toques cuando OTRA dirección está en vuelo.
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
    // Fondo **real** de la tarjeta: el tinte del GTFS va mezclado al 3.5%
    // sobre la superficie (8% con recorrido dibujado). Se calcula aquí porque
    // todo lo que se pinte encima tiene que contrastar con lo que hay detrás de
    // verdad (regla de la casa: nada oscuro sobre oscuro). El color de línea
    // puede ser `2C3E50` (casi negro) o `F1C40F` (casi blanco), así que nunca se
    // usa tal cual para letras.
    final cardBackground = Color.lerp(
      colors.surface,
      tint,
      alive ? 0.08 : 0.035,
    )!;
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
      // Solo un velo: la tarjeta entera (foto incluida) NO se apaga, la espera
      // la carga el chip de la dirección que está en vuelo (barrido + giro).
      opacity: busy ? 0.82 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        scale: busy ? 0.99 : 1,
        child: AnimatedContainer(
          duration: Motion.release,
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
                //
                // La foto es TOCABLE: se abre a pantalla completa con un vuelo
                // desde esta misma franja ([openPhotoViewer]); sin foto no hay
                // gesto (la franja es solo el tinte de la línea).
                PressScale(
                  enabled: micro.imageUrl != null,
                  child: GestureDetector(
                    onTap: micro.imageUrl == null
                        ? null
                        : () => openPhotoViewer(
                            context,
                            url: micro.imageUrl!,
                            tag: photoHeroTag('panel', micro.id),
                            title: micro.longName,
                            subtitle: 'Foto del micro',
                            accent: tint,
                          ),
                    child: Container(
                      height: 132,
                      // Sin foto la franja la pinta la LÍNEA: un degradado de su
                      // color al mismo tono hundido, nunca un bloque plano.
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [tint, Color.lerp(tint, Colors.black, 0.45)!],
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (micro.imageUrl != null)
                            Hero(
                              tag: photoHeroTag('panel', micro.id),
                              child: RoutePhoto(
                                url: micro.imageUrl!,
                                radius: BorderRadius.zero,
                                fit: BoxFit.fitHeight,
                                showFull: true,
                              ),
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
                                  Colors.black.withValues(alpha: 0.16),
                                  Colors.transparent,
                                  // El pie se hunde hacia el color de la línea
                                  // (30%): la tarjeta sigue diciendo «de qué micro
                                  // es» aunque la foto sea de un cielo claro.
                                  Color.lerp(
                                    Colors.black,
                                    tint,
                                    0.3,
                                  )!.withValues(alpha: 0.8),
                                ],
                                stops: const [0, 0.42, 1],
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
                              duration: Motion.settle,
                              curve: Curves.easeOutCubic,
                              height: alive ? 3 : 0,
                              // Barra con brillo en el color de la línea: el
                              // recorrido dibujado se marca con SU luz.
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    tint,
                                    Color.lerp(tint, Colors.white, 0.4)!,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Numeral: literal el cartel del parabrisas, flotando
                          // del banner.
                          Positioned(
                            left: 12,
                            bottom: 10,
                            child: AnimatedScale(
                              duration: Motion.transition,
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
                                duration: Motion.settle,
                                curve: Curves.easeOutBack,
                                scale: alive ? 1 : 0.5,
                                child: ActivePill(
                                  count: activeCount,
                                  tint: tint,
                                  cardBackground: colors.surface,
                                ),
                              ),
                            ),
                          ),
                          // Señal de que la foto se abre: «expandir» discreto abajo
                          // a la derecha, donde no pelea con el numeral (izquierda)
                          // ni con la píldora de recorridos (arriba).
                          if (micro.imageUrl != null)
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: IgnorePointer(
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.34),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.open_in_full_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Contenido debajo del banner: nombre, datos de la línea y
                // botones.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              micro.longName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium?.copyWith(
                                height: 1.2,
                                fontWeight: FontWeight.w600,
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
                      // Datos de la línea en píldoras teñidas con su color:
                      // la tarjeta se lee aunque no tenga foto.
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _LineMeta(
                          micro: micro,
                          tint: tint,
                          background: cardBackground,
                        ),
                      ),
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
                          child: DirectionChip(
                            direction: directions[i],
                            tint: tint,
                            foreground: onTint,
                            active: activeDirectionKeys.contains(
                              microDirectionKey(
                                micro.id,
                                directions[i].directionId,
                              ),
                            ),
                            loading:
                                busyKey ==
                                microDirectionKey(
                                  micro.id,
                                  directions[i].directionId,
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

/// Datos de la línea bajo el nombre, en píldoras teñidas con SU color: si
/// tiene ida y vuelta o solo ida. La tinta se calcula contra la mezcla que se
/// pinta de verdad (`legible`), nunca se usa el tinte crudo como letra (un
/// `F1C40F` de GTFS sobre hoja clara desaparecería).
class _LineMeta extends StatelessWidget {
  const _LineMeta({
    required this.micro,
    required this.tint,
    required this.background,
  });

  final RouteSummary micro;
  final Color tint;

  /// Superficie REAL de la tarjeta (tinte ya mezclado), para el contraste.
  final Color background;

  @override
  Widget build(BuildContext context) {
    final fill = Color.lerp(background, tint, 0.14)!;
    final ink = AppColors.legible(tint, fill);
    final lines = micro.directionsCount > 1;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        MetaPill(
          icon: lines ? Icons.swap_horiz_rounded : Icons.arrow_forward_rounded,
          label: lines ? 'Ida y vuelta' : 'Solo ida',
          fill: fill,
          ink: ink,
        ),
      ],
    );
  }
}
