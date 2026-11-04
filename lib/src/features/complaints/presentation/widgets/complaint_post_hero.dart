import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/photo_shine.dart';
import '../../application/complaints_feed_controller.dart';
import '../../data/complaint_repository.dart';
import 'complaint_chips.dart';
import 'complaint_photo.dart';

/// Héroe de una queja: la pieza que abre **la tarjeta del feed y el detalle**.
///
/// La foto manda y el título, las pastillas y la hora van **encima** de ella
/// (como en una red social), no en una cabecera aparte. Sin foto no queda un
/// hueco gris: se pinta el **póster** del motivo —degradado con el acento de la
/// categoría, los anillos de la ciudad en reposo y su ícono—, así que el reporte
/// sigue teniendo color e identidad.
///
/// Vive en su propio archivo precisamente para que abrir un reporte no cambie
/// su piel: el feed y el detalle montan el mismo widget.
class ComplaintPostHero extends StatelessWidget {
  const ComplaintPostHero({
    super.key,
    required this.complaint,
    required this.routeName,
    required this.routeColor,
    required this.meta,
    required this.accent,
    this.photo,
    this.showStatus = true,
  });

  final ComplaintSummary complaint;
  final String routeName;

  /// Color GTFS de la línea (ya convertido con [AppColors.fromHex]).
  final Color routeColor;

  /// `Recorrido · hora`, ya armado por quien monta el héroe.
  final String meta;

  /// Acento del motivo (ver [AppColors.categoryAccent]).
  final Color accent;

  /// Foto del héroe. `null` = póster del motivo. El detalle pasa `null` porque
  /// sus fotos viven en su propia galería (miniaturas + visor).
  final String? photo;

  /// El feed omite el estado cuando ya está verificado (para no crecer); el
  /// detalle lo pinta siempre.
  final bool showStatus;

  /// Alto con foto: la imagen manda, pero deja sitio al título y a las
  /// pastillas sin comerse la primera tarjeta al abrir la sección.
  static const double _photoHeight = 220;

  /// Alto del póster: algo más bajo que la foto (no hay imagen que mirar),
  /// pero con sitio para que la trama de anillos y el ícono respiren arriba.
  static const double _posterHeight = 196;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = complaint.photoUrls.length;
    final photo = this.photo;
    // Lo que va ENCIMA del medio se mide contra negro: ese es el color del velo
    // que se pinta entre la foto y la letra (el peor caso real detrás de un
    // texto claro).
    final onMedia = AppColors.onColor(Colors.black);
    return SizedBox(
      height: photo == null ? _posterHeight : _photoHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo == null)
            _Poster(accent: accent, category: complaint.category)
          else
            Positioned.fill(
              child: PhotoShine(
                // `SizedBox.expand`: [PhotoShine] envuelve el hijo con
                // restricciones flojas mientras dura el destello, y sin esto la
                // foto se encogía a su tamaño intrínseco durante esa pasada.
                child: SizedBox.expand(
                  child: ComplaintPhoto(
                    url: photo,
                    radius: BorderRadius.zero,
                    placeholderSurface: colors.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
          // Velo del héroe: arriba para que la insignia y el contador de fotos
          // se lean sobre cualquier imagen, abajo para el título. Es un SCRIM
          // (no tinta de contenido), igual que el de la galería del detalle.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x73000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xB3000000),
                ],
                stops: [0, 0.3, 0.46, 1],
              ),
            ),
          ),
          Positioned(
            top: AppSpace.md,
            left: AppSpace.md,
            child: MicroBadge(label: routeName, color: routeColor, size: 42),
          ),
          if (photo != null && total > 1)
            Positioned(
              top: AppSpace.md,
              right: AppSpace.md,
              child: PhotoScrimPill(
                label: '+${total - 1} fotos',
                icon: Icons.photo_library_rounded,
              ),
            ),
          Positioned(
            left: AppSpace.md,
            right: AppSpace.md,
            bottom: AppSpace.md,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Las pastillas van sobre el medio, así que su relleno se mide
                // contra negro: quedan oscuras y su letra clara, que es la única
                // forma de leerlas sobre una foto cualquiera.
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.xs,
                  children: [
                    CategoryChip(
                      category: complaint.category,
                      on: Colors.black,
                    ),
                    if (showStatus || complaint.status != 'approved')
                      StatusChip(status: complaint.status, on: Colors.black),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Micro $routeName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium?.copyWith(
                    color: onMedia,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: onMedia.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
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

/// Póster del motivo para reportes **sin foto**: el acento de la categoría en
/// diagonal (orilla clara → tono → profundo), los anillos de la ciudad en
/// reposo y el ícono de la categoría.
class _Poster extends StatelessWidget {
  const _Poster({required this.accent, required this.category});

  final Color accent;
  final String category;

  @override
  Widget build(BuildContext context) {
    final light = AppColors.tint(accent, Colors.white);
    final deep = AppColors.tint(accent, Colors.black, 0.55);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, accent, deep],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: Stack(
        children: [
          // Misma trama de anillos que la portada y el home, pero ESTÁTICA: una
          // tarjeta por fila no puede montar un ticker cada una.
          const Positioned.fill(child: CustomPaint(painter: _PosterRings())),
          Positioned(
            right: AppSpace.md,
            top: AppSpace.md,
            child: Icon(
              categoryIconOf(category),
              size: 76,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anillos de la ciudad en reposo para el póster: arcos concéntricos con sus
/// paradas, en blanco translúcido.
class _PosterRings extends CustomPainter {
  const _PosterRings();

  /// El centro queda fuera del lienzo, abajo a la derecha (como en la portada):
  /// los arcos entran por la izquierda y suben hacia la esquina superior.
  static const Offset _center = Offset(1.16, 1.02);
  static const List<double> _radii = [0.46, 0.66, 0.9];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final side = size.longestSide;
    final center = Offset(size.width * _center.dx, size.height * _center.dy);
    for (var i = 0; i < _radii.length; i++) {
      final radius = _radii[i] * side;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final lane = i == 1;
      canvas.drawArc(
        rect,
        math.pi,
        math.pi / 2,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: lane ? 0.24 : 0.13)
          ..strokeWidth = lane ? 2.6 : 1.8
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      // Paradas: la trama se lee como corredor de micro, no como adorno.
      for (var s = 0; s <= 3 + i; s++) {
        final angle = math.pi + (math.pi / 2) * (s / (3 + i));
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * radius,
          2.2,
          Paint()..color = Colors.white.withValues(alpha: lane ? 0.4 : 0.22),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PosterRings oldDelegate) => false;
}
