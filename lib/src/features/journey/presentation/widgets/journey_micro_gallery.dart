import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../core/widgets/photo_shine.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../../../core/widgets/route_photo.dart';
import '../../../routes/data/route_models.dart';
import '../../../routes/presentation/widgets/micro_bus_art.dart';
import '../../data/journey_models.dart';

/// Galería de los micros de una opción de viaje: una «postal» por micro que
/// hay que tomar, en el orden en que se toman, unidas por un nudo de
/// transbordo.
///
/// Cada postal es la FOTO real del micro (la misma de `micros.csv` que ve el
/// catálogo) con el numeral en el color con que se dibuja en el mapa arriba,
/// los minutos a bordo, y abajo el trayecto y dónde se sube. Así la opción se
/// reconoce por el micro que se va a ver llegar, no solo por un número.
/// Sin foto (o mientras llega `/routes/:id`), la postal es una placa del color
/// de la línea con el micro ilustrado: nunca un hueco.
///
/// Tocar una foto la abre a pantalla completa con el vuelo compartido de
/// [openPhotoViewer]; tocar el resto de la tarjeta la sigue abriendo/cerrando.
class JourneyMicroGallery extends StatelessWidget {
  const JourneyMicroGallery({
    super.key,
    required this.option,
    required this.alternativeColors,
    required this.routes,
    required this.heroScope,
  });

  final JourneyOption option;

  /// Colores de dibujo que cambian (índice de tramo → hex), ver
  /// `LegStrokeColors.forLegs`.
  final Map<int, String> alternativeColors;

  /// Ficha de cada línea por `routeId` (foto, trayecto). Puede venir vacía.
  final Map<String, RouteSummary> routes;

  /// Prefijo único de la tarjeta para los `Hero` de las fotos: la misma línea
  /// puede salir en varias opciones a la vez.
  final String heroScope;

  /// Alto de una postal: con un solo micro la foto respira más.
  static const double soloHeight = 150;
  static const double pairHeight = 112;

  @override
  Widget build(BuildContext context) {
    final shots = <Widget>[];
    var order = 0;
    final busCount = option.legs.where((l) => l.isBus).length;
    for (var i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      if (!leg.isBus) continue;
      if (shots.isNotEmpty) shots.add(const _TransferKnot());
      order++;
      shots.add(
        Expanded(
          child: _MicroShot(
            key: ValueKey('journey-micro-shot-$heroScope-$i'),
            leg: leg,
            route: routes[leg.routeId],
            drawColor: AppColors.fromHex(
              alternativeColors[i] ?? leg.routeColor ?? '64748B',
            ),
            order: busCount > 1 ? order : null,
            heroTag: photoHeroTag('journey-$heroScope-$i', leg.routeId ?? ''),
            compact: busCount > 1,
          ),
        ),
      );
    }
    if (shots.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: busCount > 1 ? pairHeight : soloHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: shots,
      ),
    );
  }
}

/// Nudo entre dos postales: el transbordo, en el coral de la app. Flecha de
/// UN sentido (→): se baja de un micro y se sube al siguiente, no se vuelve.
class _TransferKnot extends StatelessWidget {
  const _TransferKnot();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const accent = AppColors.accent;
    final fill = AppColors.tint(accent, colors.surface);
    return SizedBox(
      width: 30,
      child: Center(
        child: Tooltip(
          message: 'Transbordo',
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2),
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 15,
              color: AppColors.legible(accent, fill),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una postal: foto (o placa ilustrada) + numeral + minutos + trayecto.
class _MicroShot extends StatelessWidget {
  const _MicroShot({
    super.key,
    required this.leg,
    required this.route,
    required this.drawColor,
    required this.order,
    required this.heroTag,
    required this.compact,
  });

  final JourneyLeg leg;
  final RouteSummary? route;

  /// Color con el que este tramo se dibuja en el mapa (puede no ser el GTFS).
  final Color drawColor;

  /// 1, 2… cuando el viaje tiene más de un micro; `null` si es directo.
  final int? order;
  final String heroTag;
  final bool compact;

  String get _name => (leg.routeShortName ?? leg.routeId ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final radius = BorderRadius.circular(AppRadius.tile);
    final url = route?.imageUrl;
    final longName = route?.longName.trim() ?? '';
    final board = leg.fromStop?.name.trim() ?? '';
    // El velo inferior es siempre oscuro (sobre una foto arbitraria): la
    // tinta se mide contra él, nunca se fija en blanco.
    final scrim = colors.scrim;
    final scrimInk = AppColors.onColor(scrim);

    final Widget backdrop = url == null
        ? _ArtPlate(color: drawColor)
        : Hero(
            tag: heroTag,
            child: PhotoShine(
              // Con un solo micro la postal es ancha: la foto se ve ENTERA
              // (ajustada al alto) y los costados los rellena ella misma
              // difuminada, con los bordes fundidos. En pareja, recorte.
              child: compact
                  ? RoutePhoto(url: url, radius: BorderRadius.zero)
                  : RoutePhoto(
                      url: url,
                      radius: BorderRadius.zero,
                      showFull: true,
                      featherEdges: true,
                    ),
            ),
          );

    final shot = ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          backdrop,
          // Velo de abajo: hace legible el trayecto sobre cualquier foto.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.35, 1],
                    colors: [
                      scrim.withValues(alpha: 0),
                      scrim.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Arriba: numeral en el color del trazo + minutos a bordo.
          Positioned(
            left: AppSpace.sm,
            top: AppSpace.sm,
            right: AppSpace.sm,
            // Sin `Spacer`: junto a un `Flexible` se reparte el ancho a
            // medias y truncaba «101 ANGOSTURA» aunque cupiera.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // El orden (1, 2) va APARTE, en su propio círculo: dentro
                // del numeral se leía como parte del nombre de la línea.
                // Ambos viajan juntos a la izquierda.
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (order case final step?) ...[
                        _StepDot(step: step),
                        const SizedBox(width: AppSpace.xs),
                      ],
                      Flexible(
                        child: _LinePill(name: _name, color: drawColor),
                      ),
                    ],
                  ),
                ),
                if (leg.durationMinutes != null) ...[
                  const SizedBox(width: AppSpace.xs),
                  _GlassPill(
                    icon: Icons.schedule_rounded,
                    label: Fmt.duration(leg.durationMinutes),
                  ),
                ] else if (url != null) ...[
                  const SizedBox(width: AppSpace.xs),
                  const _GlassPill(icon: Icons.zoom_out_map_rounded),
                ],
              ],
            ),
          ),
          // Abajo: trayecto + dónde se sube.
          Positioned(
            left: AppSpace.sm + 2,
            right: AppSpace.sm + 2,
            bottom: AppSpace.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (longName.isNotEmpty)
                  Text(
                    longName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(
                      color: scrimInk,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                if (board.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.trip_origin_rounded,
                        size: 11,
                        color: scrimInk.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          compact ? board : 'Sube en «$board»',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            color: scrimInk.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Filo del color del trazo: la postal se ata a su línea del mapa.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 3,
            child: ColoredBox(color: drawColor),
          ),
        ],
      ),
    );

    final label = [
      'Micro $_name',
      if (longName.isNotEmpty) longName,
      if (board.isNotEmpty) 'sube en $board',
    ].join(', ');

    if (url == null) return Semantics(label: label, child: shot);
    return Semantics(
      button: true,
      label: '$label. Ver foto',
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => openPhotoViewer(
            context,
            url: url,
            tag: heroTag,
            title: 'Micro $_name',
            subtitle: longName.isEmpty ? null : longName,
            accent: drawColor,
            sourceRadius: AppRadius.tile,
          ),
          child: shot,
        ),
      ),
    );
  }
}

/// Placa sin foto: degradado del color de la línea con el micro ilustrado
/// sobre un halo de su tinta, para que el micro no se funda con la placa.
class _ArtPlate extends StatelessWidget {
  const _ArtPlate({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final shadow = context.colors.shadow;
    final glow = AppColors.onColor(color);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, shadow, 0.1)!,
            Color.lerp(color, shadow, 0.55)!,
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.5, -0.1),
            radius: 0.75,
            colors: [glow.withValues(alpha: 0.3), glow.withValues(alpha: 0)],
          ),
        ),
        child: Align(
          alignment: const Alignment(0.5, -0.1),
          child: MicroBusArt(color: color, size: const Size(84, 56)),
        ),
      ),
    );
  }
}

/// Numeral de la línea sobre el color con que se dibuja en el mapa.
class _LinePill extends StatelessWidget {
  const _LinePill({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.onColor(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: ink.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_bus_rounded, size: 13, color: ink),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Orden del micro en el viaje (1.º, 2.º), separado del numeral de la línea.
class _StepDot extends StatelessWidget {
  const _StepDot({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'Micro $step',
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.inverseSurface.withValues(alpha: 0.88),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$step',
          style: context.text.labelSmall?.copyWith(
            color: colors.onInverseSurface,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Píldora discreta sobre la foto (superficie invertida, legible siempre).
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = label;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.inverseSurface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: colors.onInverseSurface),
            if (text != null) ...[
              const SizedBox(width: 2),
              Text(
                text,
                style: context.text.labelSmall?.copyWith(
                  color: colors.onInverseSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
