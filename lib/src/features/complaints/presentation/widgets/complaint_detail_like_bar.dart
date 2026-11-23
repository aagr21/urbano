import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../application/complaints_feed_controller.dart';
import '../../domain/complaint_models.dart';
import 'complaint_chips.dart';
import 'like_button.dart';

/// Pie social del post: el apoyo a la izquierda y la cuenta de conversación a
/// la derecha, sobre la misma superficie teñida con el motivo del reporte.
class ComplaintDetailLikeBar extends ConsumerWidget {
  const ComplaintDetailLikeBar({
    super.key,
    required this.complaint,
    required this.accent,
  });

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
