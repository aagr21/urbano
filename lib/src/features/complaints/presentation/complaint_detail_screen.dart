import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/motion.dart';
import '../../../core/identity/passenger_identity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../routes/data/route_models.dart';
import '../application/complaints_feed_controller.dart';
import '../application/passenger_controller.dart';
import '../data/complaint_repository.dart';
import 'widgets/complaint_chips.dart';
import 'widgets/complaint_photo_gallery.dart';
import 'widgets/complaint_post_hero.dart';
import 'widgets/like_button.dart';
import 'widgets/passenger_avatar.dart';

/// Detalle de una queja como publicación social: post completo, barra de
/// apoyo compartida con el feed e hilo de comentarios con su propio redactor.
class ComplaintDetailScreen extends ConsumerStatefulWidget {
  const ComplaintDetailScreen({super.key, required this.complaint, this.route});

  final ComplaintSummary complaint;
  final RouteSummary? route;

  @override
  ConsumerState<ComplaintDetailScreen> createState() =>
      _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends ConsumerState<ComplaintDetailScreen> {
  final _controller = TextEditingController();
  List<ComplaintComment>? _comments;
  Object? _commentsError;
  bool _loadingComments = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _commentsError = null;
    _loadingComments = true;
    try {
      final comments = await ref
          .read(complaintRepositoryProvider)
          .comments(widget.complaint.id);
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (error) {
      if (mounted) setState(() => _commentsError = error);
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (_sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final identity = await ref.read(passengerControllerProvider.future);
      final comment = await ref
          .read(complaintRepositoryProvider)
          .addComment(
            complaintId: widget.complaint.id,
            deviceKey: identity.deviceKey,
            authorName: identity.nickname,
            body: text,
          );
      _controller.clear();
      // El comentario se añade a la lista ya cargada: no se recarga el hilo.
      setState(() => _comments = [...?_comments, comment]);
      ref
          .read(complaintsFeedProvider.notifier)
          .registerComment(widget.complaint.id);
    } catch (error) {
      if (mounted) {
        context.showSnack('No se pudo comentar: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Like/contador en vivo desde el feed compartido (fallback al que llegó).
    final live =
        ref
            .watch(complaintsFeedProvider)
            .valueOrNull
            ?.firstWhere(
              (item) => item.id == widget.complaint.id,
              orElse: () => widget.complaint,
            ) ??
        widget.complaint;

    // El acento del motivo manda en toda la pantalla: si se pinta como texto
    // (contador de comentarios), se mide contra lo que REALMENTE hay detrás,
    // que es el fondo del scaffold = `surfaceContainerLowest`.
    final accent = AppColors.categoryAccent(live.category);
    final colors = context.colors;
    final page = colors.surfaceContainerLowest;
    final routeName = widget.route?.shortName.isNotEmpty ?? false
        ? widget.route!.shortName
        : live.routeId;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Reporte'),
            Text(
              'Micro $routeName · ${categoryLabelOf(live.category)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.lg),
              children: [
                _PostBody(complaint: live, route: widget.route),
                const SizedBox(height: AppSpace.sm),
                _LikeBar(complaint: live, accent: accent),
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      margin: const EdgeInsets.only(right: AppSpace.sm),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primary, AppColors.aqua],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Comentarios',
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (!_loadingComments)
                      CountUp(
                        value: live.commentCount,
                        format: (count) =>
                            count == 1 ? '1 comentario' : '$count comentarios',
                        style: TextStyle(
                          color: AppColors.legible(accent, page),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                _CommentsSection(
                  loading: _loadingComments,
                  error: _commentsError,
                  comments: _comments ?? const [],
                  onRetry: _load,
                ),
              ],
            ),
          ),
          _CommentComposer(
            controller: _controller,
            sending: _sending,
            onSend: _send,
            identity: ref.watch(passengerControllerProvider).valueOrNull,
          ),
        ],
      ),
    );
  }
}

/// Versión ampliada del post (héroe + foto + texto completo) para el detalle.
///
/// Monta el MISMO [ComplaintPostHero] del feed (con póster en vez de foto: las
/// fotos viven en la galería, con sus miniaturas y el visor) y la misma piel
/// teñida del motivo: abrir un reporte no debe cambiarle la identidad.
class _PostBody extends StatelessWidget {
  const _PostBody({required this.complaint, this.route});

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

/// Pie social del post: el apoyo a la izquierda y la cuenta de conversación a
/// la derecha, sobre la misma superficie teñida con el motivo del reporte.
class _LikeBar extends ConsumerWidget {
  const _LikeBar({required this.complaint, required this.accent});

  final ComplaintSummary complaint;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final barSurface = colors.surfaceContainerLow;
    final lively = complaint.commentCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: barSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.tint(accent, colors.outlineVariant, 0.35),
        ),
      ),
      child: Row(
        children: [
          LikeButton(
            liked: complaint.likedByMe,
            count: complaint.likeCount,
            on: barSurface,
            onTap: () =>
                ref.read(complaintsFeedProvider.notifier).toggleLike(complaint),
          ),
          const Spacer(),
          ComplaintPill(
            label: !lively
                ? 'Sin comentarios'
                : complaint.commentCount == 1
                ? '1 comentario'
                : '${complaint.commentCount} comentarios',
            icon: Icons.mode_comment_rounded,
            accent: lively ? colors.primary : colors.onSurfaceVariant,
            on: barSurface,
            emphasized: false,
          ),
          const SizedBox(width: AppSpace.xs),
        ],
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.loading,
    required this.error,
    required this.comments,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final List<ComplaintComment> comments;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Column(
          children: [
            LoadingShimmer(height: 44),
            SizedBox(height: AppSpace.md),
            LoadingShimmer(height: 44),
          ],
        ),
      );
    }
    if (error != null) {
      return ErrorView(
        error: error!,
        title: 'No se pudieron cargar los comentarios',
        onRetry: onRetry,
        compact: true,
      );
    }
    if (comments.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.xl,
        ),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 26,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Sé el primero en comentar.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < comments.length; i++)
          Reveal(
            key: ValueKey(comments[i].id),
            index: i,
            slide: 8,
            child: _CommentTile(comment: comments[i]),
          ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final ComplaintComment comment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final authorColor = AppColors.fromHex(comment.authorColor);
    // La burbuja se tiñe con el color del autor (el mismo del avatar) para que
    // el hilo se escanee por persona; el nombre se mide contra ESE relleno.
    final bubble = AppColors.tint(
      authorColor,
      colors.surfaceContainerHigh,
      0.12,
    );
    final nameInk = AppColors.legible(authorColor, bubble);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PassengerAvatar(
            colorHex: comment.authorColor,
            initials: comment.authorName.isEmpty
                ? '?'
                : comment.authorName.substring(0, 1).toUpperCase(),
            size: 36,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.sm,
              ),
              decoration: BoxDecoration(
                color: bubble,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(
                  color: AppColors.tint(
                    authorColor,
                    colors.outlineVariant,
                    0.3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: nameInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        relativeDateLabel(comment.createdAt),
                        style: context.text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(comment.body, style: context.text.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.identity,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final PassengerIdentity? identity;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.sm,
          AppSpace.md,
          AppSpace.sm,
        ),
        // Redactor flotante: una barra pegada al borde inferior parecía parte
        // del sistema; esta se separa del contenido con su propia sombra.
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.sm,
            AppSpace.xs,
            AppSpace.xs,
            AppSpace.xs,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: AppTheme.softShadow(
              color: colors.onSurface,
              opacity: 0.06,
              blur: 16,
              dy: 4,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (identity != null)
                PassengerAvatar.from(identity!, size: 36)
              else
                const SizedBox(width: 36, height: 36),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: identity == null
                        ? 'Comentando como…'
                        : 'Comenta como ${identity!.nickname}',
                    filled: true,
                    fillColor: colors.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                      vertical: AppSpace.md,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              IconButton.filled(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
