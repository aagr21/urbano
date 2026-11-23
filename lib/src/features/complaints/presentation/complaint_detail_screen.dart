import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/urbano_back_button.dart';
import '../../routes/data/route_models.dart';
import '../application/complaints_feed_controller.dart';
import '../application/passenger_controller.dart';
import '../data/complaint_repository.dart';
import '../domain/complaint_models.dart';
import 'widgets/complaint_detail_comment_composer.dart';
import 'widgets/complaint_detail_comments_section.dart';
import 'widgets/complaint_detail_like_bar.dart';
import 'widgets/complaint_detail_post_body.dart';

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
        leading: const UrbanoBackButton(),
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
                ComplaintDetailPostBody(complaint: live, route: widget.route),
                const SizedBox(height: AppSpace.sm),
                ComplaintDetailLikeBar(complaint: live, accent: accent),
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
                ComplaintDetailCommentsSection(
                  loading: _loadingComments,
                  error: _commentsError,
                  comments: _comments ?? const [],
                  onRetry: _load,
                ),
              ],
            ),
          ),
          ComplaintDetailCommentComposer(
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

/// Versión ampliada del post: ver [ComplaintDetailPostBody].
/// Pie social: ver [ComplaintDetailLikeBar].
/// Sección de comentarios: ver [ComplaintDetailCommentsSection].
/// Burbuja de comentario: ver [ComplaintDetailCommentTile].
/// Redactor: ver [ComplaintDetailCommentComposer].
