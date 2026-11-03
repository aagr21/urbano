import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../routes/data/route_models.dart';
import '../../application/complaints_feed_controller.dart';
import '../../data/complaint_repository.dart';
import '../complaint_detail_screen.dart';
import 'complaint_chips.dart';
import 'like_button.dart';

/// Publicación del feed de quejas con pinta de red social.
///
/// Identidad visual por motivos: el **riel** superior y la pastilla llevan el
/// color de la categoría, la insignia el color GTFS de la línea, y la barra de
/// acciones separa el apoyo del comentario. El toque abre el detalle.
class ComplaintPostCard extends ConsumerWidget {
  const ComplaintPostCard({
    super.key,
    required this.complaint,
    this.route,
    this.index = 0,
  });

  final ComplaintSummary complaint;
  final RouteSummary? route;

  /// Posición en la lista: solo para escalonar la entrada con [Reveal].
  final int index;

  void _openDetail(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Consumer(
          builder: (context, detailRef, _) => ComplaintDetailScreen(
            // Se lee siempre la versión viva del feed (tras un like optimista).
            complaint:
                detailRef
                    .read(complaintsFeedProvider)
                    .valueOrNull
                    ?.firstWhere(
                      (item) => item.id == complaint.id,
                      orElse: () => complaint,
                    ) ??
                complaint,
            route: route,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // Fondo real de la tarjeta: todo tinte/letra de la tarjeta se mide contra él.
    final cardSurface = colors.surfaceContainerLow;
    final accent = AppColors.categoryAccent(complaint.category);
    final routeColor = AppColors.fromHex(route?.color);
    final routeName = route?.shortName.isNotEmpty ?? false
        ? route!.shortName
        : complaint.routeId;
    final photos = complaint.photoUrls;
    final photo = photos.firstOrNull;

    return Reveal(
      key: ValueKey('complaint-${complaint.id}'),
      index: index,
      slide: 10,
      child: PressScale(
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: cardSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.card,
            // El borde se tiñe con el motivo: dos reportes distintos se
            // distinguen antes incluso de leer el texto.
            side: BorderSide(
              color: AppColors.tint(accent, colors.outlineVariant, 0.45),
            ),
          ),
          child: InkWell(
            onTap: () => _openDetail(context, ref),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Riel del color del motivo, desvaneciéndose hacia la derecha
                // para que no parezca una barra de progreso.
                SizedBox(
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          AppColors.tint(accent, cardSurface, 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.md,
                    AppSpace.md,
                    AppSpace.md,
                    AppSpace.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MicroBadge(label: routeName, color: routeColor),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Micro $routeName',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpace.sm),
                                Text(
                                  relativeDateLabel(complaint.createdAt),
                                  style: context.text.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpace.xs),
                            // `Wrap`, no `Row`: con el nombre largo de la línea
                            // y dos pastillas, un Row desbordaba la tarjeta.
                            Wrap(
                              spacing: AppSpace.sm,
                              runSpacing: AppSpace.xs,
                              children: [
                                CategoryChip(
                                  category: complaint.category,
                                  on: cardSurface,
                                ),
                                if (complaint.status != 'approved')
                                  StatusChip(
                                    status: complaint.status,
                                    on: cardSurface,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (photo != null)
                  _PhotoStrip(photo: photo, total: photos.length),
                if (complaint.description.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      AppSpace.sm,
                      AppSpace.md,
                      AppSpace.md,
                    ),
                    child: Text(
                      complaint.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                Divider(height: 1, thickness: 1, color: colors.outlineVariant),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.xs,
                    vertical: AppSpace.xs,
                  ),
                  child: Row(
                    children: [
                      LikeButton(
                        liked: complaint.likedByMe,
                        count: complaint.likeCount,
                        onTap: () => ref
                            .read(complaintsFeedProvider.notifier)
                            .toggleLike(complaint),
                      ),
                      const Spacer(),
                      _CommentPill(
                        count: complaint.commentCount,
                        on: cardSurface,
                        onTap: () => _openDetail(context, ref),
                      ),
                      const SizedBox(width: AppSpace.xs),
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

/// Foto principal a sangre con la cuenta de adjuntos encima.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photo, required this.total});

  final String photo;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 188,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photo,
            fit: BoxFit.cover,
            // Si la imagen no carga queda un hueco del tema (no negro/blanco
            // fijos) con su ícono, para que la tarjeta no parezca rota.
            errorBuilder: (_, _, _) => ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image_outlined,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          if (total > 1)
            Positioned(
              right: AppSpace.sm,
              bottom: AppSpace.sm,
              // `inverseSurface` en vez de negro+blanco: la misma pastilla se
              // lee en tema claro (oscura) y en oscuro (clara).
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.inverseSurface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: AppSpace.xs,
                  ),
                  child: Text(
                    '+${total - 1} fotos',
                    style: TextStyle(
                      color: colors.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Contador de comentarios navegable (abre el detalle en el hilo).
///
/// Con comentarios se tiñe de primario para que el ojo vaya a la conversación;
/// vacío queda discreto y dice «Comentar».
class _CommentPill extends StatelessWidget {
  const _CommentPill({
    required this.count,
    required this.on,
    required this.onTap,
  });

  final int count;
  final Color on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lively = count > 0;
    final accent = lively ? colors.primary : colors.onSurfaceVariant;
    final fill = AppColors.tint(accent, on, lively ? 0.14 : 0);
    final ink = AppColors.legible(accent, fill);
    return PressScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.xs,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                lively
                    ? Icons.mode_comment_rounded
                    : Icons.mode_comment_outlined,
                size: 20,
                color: ink,
              ),
              const SizedBox(width: AppSpace.xs),
              CountUp(
                value: count,
                format: (value) => value == 0 ? 'Comentar' : '$value',
                style: TextStyle(
                  fontSize: 14,
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
