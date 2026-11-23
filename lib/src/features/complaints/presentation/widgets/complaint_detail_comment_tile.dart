import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../application/complaints_feed_controller.dart';
import '../../domain/complaint_models.dart';
import 'passenger_avatar.dart';

/// Burbuja de un comentario: avatar del autor, nombre, fecha y texto, todo
/// teñido con el color del autor para que el hilo se escanee por persona.
class ComplaintDetailCommentTile extends StatelessWidget {
  const ComplaintDetailCommentTile({super.key, required this.comment});

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
