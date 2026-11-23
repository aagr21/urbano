import 'package:flutter/material.dart';

import '../../../../core/identity/passenger_identity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import 'passenger_avatar.dart';

/// Barra de redactar comentario: avatar del usuario, campo de texto y botón
/// enviar, flotando sobre el borde inferior con su propia sombra.
class ComplaintDetailCommentComposer extends StatelessWidget {
  const ComplaintDetailCommentComposer({
    super.key,
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
