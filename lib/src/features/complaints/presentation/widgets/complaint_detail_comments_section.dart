import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../domain/complaint_models.dart';
import 'complaint_detail_comment_tile.dart';

/// Sección de comentarios: shimmer de carga, vista de error, estado vacío o
/// lista de burbujas con animación de entrada.
class ComplaintDetailCommentsSection extends StatelessWidget {
  const ComplaintDetailCommentsSection({
    super.key,
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
            child: ComplaintDetailCommentTile(comment: comments[i]),
          ),
      ],
    );
  }
}
