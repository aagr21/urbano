import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../routes/data/route_models.dart';
import '../../application/complaints_feed_controller.dart';
import '../../domain/complaint_models.dart';
import '../complaint_detail_screen.dart';
import 'complaint_post_hero.dart';
import 'like_button.dart';

/// Publicación del feed de quejas con pinta de red social.
///
/// La identidad la lleva el **héroe** ([ComplaintPostHero]): foto a sangre (o
/// póster del motivo) con la insignia GTFS de la línea, las pastillas de motivo
/// y estado, el número del micro y el `recorrido · hora` encima. Debajo queda el
/// relato y el pie social con el apoyo y los comentarios. El toque abre el
/// detalle.
class ComplaintPostCard extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<ComplaintPostCard> createState() => _ComplaintPostCardState();
}

class _ComplaintPostCardState extends ConsumerState<ComplaintPostCard> {
  /// Sube cada vez que el pasajero DA su apoyo: es la clave del corazón que
  /// late sobre la foto (una clave nueva = una animación nueva). Quitar el
  /// apoyo no lo dispara: el gesto que se celebra es apoyar.
  int _burst = 0;

  ComplaintSummary get complaint => widget.complaint;
  RouteSummary? get route => widget.route;

  void _toggleLike() {
    if (!complaint.likedByMe) setState(() => _burst++);
    ref.read(complaintsFeedProvider.notifier).toggleLike(complaint);
  }

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
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Fondo real de la tarjeta: todo tinte/letra de la tarjeta se mide contra él.
    final cardSurface = colors.surfaceContainerLow;
    final accent = AppColors.categoryAccent(complaint.category);
    // Velo del motivo: la tarjeta deja de ser un rectángulo blanco más y cada
    // reporte se reconoce por su color antes de leer una letra.
    final painted = AppColors.tint(accent, cardSurface, 0.055);
    final routeColor = AppColors.fromHex(route?.color);
    final routeName = route?.shortName.isNotEmpty ?? false
        ? route!.shortName
        : complaint.routeId;
    final subtitle = routeSubtitleOf(route);
    // Recorrido + hora en UNA línea: la hora suelta en la esquina competía con
    // el título y el subtítulo, y en pantalla angosta desbordaba.
    final meta = [
      ?subtitle,
      relativeDateLabel(complaint.createdAt),
    ].join(' · ');

    return Reveal(
      key: ValueKey('complaint-${complaint.id}'),
      index: widget.index,
      slide: 10,
      child: PressScale(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: painted,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: AppColors.tint(accent, colors.outlineVariant, 0.55),
            ),
            // Sombra del motivo: la tarjeta se despega del lienzo con el color
            // de su categoría, no con un gris genérico. Baja y difusa: con
            // más desplazamiento y opacidad se leía como una losa pegada.
            boxShadow: AppTheme.softShadow(
              color: accent,
              opacity: 0.1,
              blur: 28,
              dy: 10,
            ),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.card,
            child: Material(
              // El material transparente permite que el ripple del InkWell se
              // pinte sobre la foto del héroe.
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openDetail(context, ref),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ComplaintPostHero(
                          complaint: complaint,
                          routeName: routeName,
                          routeColor: routeColor,
                          meta: meta,
                          accent: accent,
                          photo: complaint.photoUrls.firstOrNull,
                          // El feed omite el estado verificado para no crecer.
                          showStatus: false,
                        ),
                        if (_burst > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _HeartBurst(key: ValueKey(_burst)),
                            ),
                          ),
                      ],
                    ),
                    if (complaint.description.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.md,
                          AppSpace.md,
                          AppSpace.md,
                          AppSpace.sm,
                        ),
                        child: Text(
                          complaint.description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                        ),
                      ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.outlineVariant,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.xs,
                        AppSpace.xs,
                        AppSpace.sm,
                        AppSpace.xs,
                      ),
                      child: Row(
                        children: [
                          LikeButton(
                            liked: complaint.likedByMe,
                            count: complaint.likeCount,
                            on: painted,
                            onTap: _toggleLike,
                          ),
                          const SizedBox(width: AppSpace.xs),
                          _CommentPill(
                            count: complaint.commentCount,
                            on: painted,
                            accent: accent,
                            onTap: () => _openDetail(context, ref),
                          ),
                          const Spacer(),
                          _OpenHint(accent: accent, on: painted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Corazón que late sobre la foto cuando el pasajero da su apoyo: crece con
/// rebote, queda un instante y se desvanece hacia arriba. Es una animación
/// implícita de una sola pasada (`TweenAnimationBuilder`), sin controller
/// propio ni ticker eterno, así que no estorba a `pump()`/`pumpAndSettle()`.
class _HeartBurst extends StatelessWidget {
  const _HeartBurst({super.key});

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return const SizedBox.shrink();
    final colors = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (context, t, child) {
        // 0 → 0,35: entra con rebote; 0,35 → 0,7: late; 0,7 → 1: se va.
        final grow = Curves.elasticOut.transform((t / 0.35).clamp(0.0, 1.0));
        final leave = Curves.easeIn.transform(
          ((t - 0.7) / 0.3).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: (1 - leave).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -24 * leave),
            child: Transform.scale(scale: 0.3 + 0.7 * grow, child: child),
          ),
        );
      },
      child: Center(
        child: Icon(
          Icons.favorite_rounded,
          size: 96,
          color: colors.error,
          shadows: [
            Shadow(
              color: colors.shadow.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pista de navegación del pie: deja claro que la tarjeta se abre entera.
class _OpenHint extends StatelessWidget {
  const _OpenHint({required this.accent, required this.on});

  final Color accent;
  final Color on;

  @override
  Widget build(BuildContext context) {
    final fill = AppColors.tint(accent, on, 0.12);
    final ink = AppColors.legible(accent, fill);
    return Tooltip(
      message: 'Abrir reporte',
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: Icon(Icons.arrow_forward_rounded, size: 16, color: ink),
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
    required this.accent,
    required this.onTap,
  });

  final int count;
  final Color on;

  /// Acento del motivo, solo para el fondo del pie.
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lively = count > 0;
    final tone = lively ? colors.primary : colors.onSurfaceVariant;
    // El fondo siempre está: un pie con dos acciones de las cuales una es
    // invisible deja el borde de la tarjeta cojo.
    final fill = AppColors.tint(
      lively ? tone : accent,
      on,
      lively ? 0.14 : 0.07,
    );
    final ink = AppColors.legible(tone, fill);
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
