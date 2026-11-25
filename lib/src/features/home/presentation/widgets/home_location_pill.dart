// Píldora «Tu ubicación» de la cabecera: estado del GPS y activación.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';

/// «Tu ubicación ›»: estilo del HTML (glass-pill con punto esmeralda).
///
/// El estado de permisos se cuenta con el ícono y la etiqueta, y se toca para
/// activar o refrescar. Sin ubicación la píldora invita («Usar mi ubicación»);
/// con ubicación resume y deja refrescar.
class HomeLocationPill extends ConsumerWidget {
  const HomeLocationPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final location = ref.watch(myLocationProvider);

    // Colores del HTML: glass-pill blanco con borde esmeralda.
    final bg = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.82);
    final border = dark
        ? colors.primary.withValues(alpha: 0.2)
        : HtmlDesignTokens.emerald100;
    final ink = dark ? colors.onSurface : HtmlDesignTokens.slate700;
    const dotColor = HtmlDesignTokens.emerald500;

    final ({String label, VoidCallback? onTap, bool live}) state = location
        .when(
          loading: () =>
              (label: 'Buscando ubicación…', onTap: null, live: false),
          error: (error, _) => (
            label: error is LocationFailure
                ? error.friendlyMessage
                : 'Ubicación no disponible',
            onTap: () => ref.invalidate(myLocationProvider),
            live: false,
          ),
          data: (position) => position == null
              ? (
                  label: 'Usar mi ubicación',
                  onTap: () => _activate(context, ref),
                  live: false,
                )
              : (
                  label: 'Tu ubicación',
                  onTap: () => ref.invalidate(myLocationProvider),
                  live: true,
                ),
        );

    const radius = BorderRadius.all(Radius.circular(AppRadius.pill));
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md + 2,
        vertical: AppSpace.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: state.live
                  ? [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: AppSpace.xs + 2),
          Flexible(
            child: Text(
              state.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (state.onTap != null) ...[
            const SizedBox(width: AppSpace.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: dark ? colors.onSurfaceVariant : HtmlDesignTokens.slate400,
            ),
          ],
        ],
      ),
    );

    final shell = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: state.onTap == null
            ? content
            : InkWell(
                onTap: state.onTap,
                borderRadius: radius,
                splashColor: colors.onSurface.withValues(alpha: 0.06),
                child: content,
              ),
      ),
    );

    return Center(child: shell);
  }

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    try {
      final outcome = await ref.requestMyLocation();
      if (outcome == PermissionOutcome.granted || !context.mounted) return;
      context.showSnack(
        outcome == PermissionOutcome.deniedForever
            ? 'Permiso bloqueado. Actívalo desde la configuración de tu teléfono.'
            : 'Permiso de ubicación denegado.',
        isError: true,
      );
    } on LocationFailure catch (failure) {
      if (context.mounted) {
        context.showSnack(failure.friendlyMessage, isError: true);
      }
    }
  }
}
