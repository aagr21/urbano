import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../routes/data/route_models.dart';
import '../../application/complaints_feed_controller.dart';
import '../../domain/complaint_models.dart';
import 'complaint_photo_gallery.dart';
import 'complaint_post_hero.dart';

/// Versión ampliada del post (héroe + foto + texto completo) para el detalle.
///
/// Monta el MISMO [ComplaintPostHero] del feed (con póster en vez de foto: las
/// fotos viven en la galería, con sus miniaturas y el visor) y la misma piel
/// teñida del motivo: abrir un reporte no debe cambiarle la identidad.
class ComplaintDetailPostBody extends StatelessWidget {
  const ComplaintDetailPostBody({
    super.key,
    required this.complaint,
    this.route,
  });

  final ComplaintSummary complaint;
  final RouteSummary? route;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = AppColors.categoryAccent(complaint.category);
    // Mismo velo del motivo que la tarjeta del feed.
    final cardSurface = colors.surfaceContainerLow;
    final painted = AppColors.tint(accent, cardSurface, 0.055);
    final routeColor = AppColors.fromHex(route?.color);
    final routeName = route?.shortName.isNotEmpty ?? false
        ? route!.shortName
        : complaint.routeId;
    final subtitle = routeSubtitleOf(route);
    final meta = [
      ?subtitle,
      relativeDateLabel(complaint.createdAt),
    ].join(' · ');
    final photos = complaint.photoUrls;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: painted,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.tint(accent, colors.outlineVariant, 0.45),
        ),
        boxShadow: AppTheme.softShadow(
          color: accent,
          opacity: 0.1,
          blur: 18,
          dy: 6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El héroe del feed, con póster: la foto principal no se repite,
          // porque justo debajo viene la galería completa.
          ComplaintPostHero(
            complaint: complaint,
            routeName: routeName,
            routeColor: routeColor,
            meta: meta,
            accent: accent,
            // Aquí SÍ se pinta el estado siempre; la tarjeta del feed lo omite
            // cuando el reporte ya está verificado para no crecer.
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photos.isNotEmpty) ...[
                  // TODAS las adjuntas: la principal, las demás en miniatura y
                  // el visor a pantalla completa al tocar.
                  ComplaintPhotoGallery(
                    key: ValueKey('complaint-photos-${complaint.id}'),
                    urls: photos,
                  ),
                  if (photos.length > 1) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      '${photos.length} fotos adjuntas',
                      style: context.text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
                if (complaint.description.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    complaint.description,
                    style: context.text.bodyLarge?.copyWith(height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
