import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../../core/widgets/route_photo.dart';
import '../../../../core/widgets/urbano_back_button.dart';
import '../../data/route_facts.dart';
import '../../data/route_models.dart';
import 'micro_bus_art.dart';

/// Fondo sólido de la línea (cabecera sin foto, barra contraída, sentido
/// elegido). En oscuro se templa hacia la superficie para no encandilar.
Color routeHeroFill(BuildContext context, Color routeColor) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark
      ? Color.lerp(routeColor, context.colors.surface, 0.35)!
      : routeColor;
}

/// Cabecera plegable del detalle: **el micro primero**.
///
/// Lo primero que ve el pasajero es el micro que tiene que esperar: la FOTO
/// real a sangre (tocarla la abre completa) o, si la línea no tiene foto, el
/// micro ilustrado en grande sobre su color. Encima, solo el numeral y el
/// nombre del recorrido. Al hacer scroll se contrae a una barra del color de
/// la línea con «101 · Nombre».
class RouteDetailHero extends StatelessWidget {
  const RouteDetailHero({
    super.key,
    required this.detail,
    required this.heroTag,
    required this.onRefresh,
  });

  final RouteDetail detail;
  final String heroTag;
  final VoidCallback onRefresh;

  /// Frase de estado del servicio (pública para testing). Es lectura del
  /// horario programado, no tiempo real, y no promete frecuencia.
  static String? statusLabel(RouteDirection? direction, DateTime now) {
    final window = ServiceWindow.from(
      direction?.firstDeparture,
      direction?.lastDeparture,
    );
    if (window == null) return null;
    return switch (window.phaseAt(now)) {
      ServicePhase.running => 'En servicio hasta las ${window.endLabel}',
      ServicePhase.beforeStart =>
        'Todavía no sale · primer micro a las ${window.startLabel}',
      ServicePhase.ended =>
        'Ya no pasa hoy · vuelve a las ${window.startLabel}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.fromHex(detail.color);
    final fill = routeHeroFill(context, accent);
    final barInk = AppColors.onColor(
      fill,
      preferred: AppColors.fromHex(detail.textColor),
    );
    final photo = detail.imageUrl;
    // Con foto, el texto va sobre un degradado oscuro: blanco es la única
    // tinta segura sobre una imagen arbitraria.
    final titleInk = photo != null ? Colors.white : barInk;
    final name = detail.longName.isNotEmpty
        ? detail.longName
        : 'Línea ${detail.shortName}';
    final expanded = photo != null ? 300.0 : 240.0;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expanded,
      backgroundColor: fill,
      surfaceTintColor: Colors.transparent,
      foregroundColor: barInk,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarIconBrightness:
            photo != null || barInk.computeLuminance() > 0.5
            ? Brightness.light
            : Brightness.dark,
      ),
      leading: const Padding(
        padding: EdgeInsets.only(left: AppSpace.xs),
        child: UrbanoBackButton(),
      ),
      actions: [
        _CircleAction(
          tooltip: 'Actualizar',
          icon: Icons.refresh_rounded,
          onPressed: onRefresh,
        ),
        const SizedBox(width: AppSpace.sm),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = MediaQuery.paddingOf(context).top;
          final minExtent = kToolbarHeight + top;
          final maxExtent = expanded + top;
          // 1 = desplegada, 0 = contraída a la barra.
          final t =
              ((constraints.maxHeight - minExtent) / (maxExtent - minExtent))
                  .clamp(0.0, 1.0);
          final contentOpacity = Curves.easeOut.transform(
            ((t - 0.3) / 0.7).clamp(0.0, 1.0),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              // El micro: foto real o ilustración. Se desvanece hacia el
              // color de la línea al contraerse.
              Opacity(
                opacity: t,
                child: photo != null
                    ? GestureDetector(
                        onTap: () => openPhotoViewer(
                          context,
                          url: photo,
                          tag: photoHeroTag('detail', detail.id),
                          title: name,
                          subtitle: 'Foto del micro',
                          accent: accent,
                          sourceRadius: 0,
                        ),
                        child: Hero(
                          tag: photoHeroTag('detail', detail.id),
                          child: RoutePhoto(
                            url: photo,
                            radius: BorderRadius.zero,
                          ),
                        ),
                      )
                    : _IllustratedMicro(color: accent, ink: barInk, top: top),
              ),
              if (photo != null)
                IgnorePointer(
                  child: Opacity(
                    opacity: t,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, 0.3, 0.55, 1],
                          colors: [
                            Color(0x66000000),
                            Color(0x00000000),
                            Color(0x1A000000),
                            Color(0xB3000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Numeral + nombre, abajo a la izquierda.
              Positioned(
                left: AppSpace.lg,
                right: AppSpace.lg,
                bottom: AppSpace.lg,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: contentOpacity,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Marco blanco: el badge se lee sobre la foto y
                          // sobre su propio color.
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: photo != null ? Colors.white : barInk,
                              // Radio del badge grande (13) + el marco (3).
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: RouteBadge(
                              label: detail.shortName,
                              colorHex: detail.color,
                              textColorHex: detail.textColor,
                              size: RouteBadgeSize.large,
                              heroTag: heroTag,
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                                letterSpacing: -0.3,
                                color: titleInk,
                                shadows: photo != null
                                    ? const [
                                        Shadow(
                                          color: Color(0x66000000),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Título compacto de la barra contraída.
              Positioned(
                left: 64,
                right: 64,
                top: top,
                height: kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: ((0.3 - t) / 0.3).clamp(0.0, 1.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${detail.shortName} · $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: barInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sin foto: el micro ilustrado en grande, en el color real de la línea,
/// sobre una banda un poco más oscura y los anillos de Santa Cruz.
class _IllustratedMicro extends StatelessWidget {
  const _IllustratedMicro({
    required this.color,
    required this.ink,
    required this.top,
  });

  final Color color;
  final Color ink;
  final double top;

  @override
  Widget build(BuildContext context) {
    final fill = routeHeroFill(context, color);
    // El micro necesita contraste con la banda: se pinta sobre una placa
    // clara/oscura según la tinta.
    final plate = ink.withValues(alpha: 0.16);
    return ColoredBox(
      color: fill,
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: top - 30,
            child: _Rings(color: ink.withValues(alpha: 0.10)),
          ),
          Positioned(
            right: AppSpace.lg,
            top: top + kToolbarHeight + AppSpace.xs,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              decoration: BoxDecoration(
                color: plate,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: MicroBusArt(
                color: Color.lerp(color, ink, 0.12)!,
                size: const Size(132, 88),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acción circular de la cabecera: mismo círculo que [UrbanoBackButton].
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: PressScale(
        scale: 0.95,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: colors.surface,
            foregroundColor: colors.onSurface,
            side: BorderSide(
              color: dark
                  ? AppColors.lineStrongDark
                  : colors.outlineVariant.withValues(alpha: 0.8),
            ),
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            fixedSize: const Size.square(40),
          ),
        ),
      ),
    );
  }
}

/// Anillos concéntricos (los de Santa Cruz) como textura.
class _Rings extends StatelessWidget {
  const _Rings({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 240,
      child: CustomPaint(painter: _RingsPainter(color)),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, size.shortestSide / 2 * (i / 4), paint);
    }
    canvas.drawLine(
      center,
      center + Offset.fromDirection(math.pi * 0.75, size.shortestSide / 2),
      paint..strokeWidth = 6,
    );
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) =>
      oldDelegate.color != color;
}
