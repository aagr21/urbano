import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/photo_shine.dart';
import '../../../routes/data/route_models.dart';
import '../../application/complaints_feed_controller.dart';
import '../../domain/complaint_models.dart';
import '../complaint_detail_screen.dart';
import 'complaint_chips.dart';
import 'complaint_photo.dart';
import 'complaint_post_hero.dart';
import 'like_button.dart';

/// Publicación del feed de quejas con pinta de red social.
///
/// La identidad la lleva el **héroe** ([ComplaintPostHero]): foto a sangre (o
/// póster del motivo) con la insignia GTFS de la línea, las pastillas de motivo
/// y estado, el número del micro y el `recorrido · hora` encima. Debajo queda el
/// relato y el pie social con el apoyo y los comentarios. El toque abre el
/// detalle; el doble toque sobre la foto apoya el reporte.
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
    if (!complaint.likedByMe) {
      HapticFeedback.lightImpact();
      setState(() => _burst++);
    }
    ref.read(complaintsFeedProvider.notifier).toggleLike(complaint);
  }

  /// Doble toque sobre la foto: **apoya**, nunca quita el apoyo (como en las
  /// redes: el gesto rápido solo suma). Si ya estaba apoyado, el corazón late
  /// igual para confirmar que el gesto llegó.
  void _supportFromPhoto() {
    if (complaint.likedByMe) {
      HapticFeedback.lightImpact();
      setState(() => _burst++);
      return;
    }
    _toggleLike();
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
      subtitle ?? 'Reporte anónimo',
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
                    _PostHeader(
                      routeName: routeName,
                      routeColor: routeColor,
                      meta: meta,
                      status: complaint.status,
                      on: painted,
                    ),
                    // El doble toque vive SOLO en la foto: el resto de la
                    // tarjeta abre el detalle al primer toque, sin la espera
                    // que impone reconocer un doble toque.
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                      ),
                      child: GestureDetector(
                        key: ValueKey('complaint-hero-${complaint.id}'),
                        onDoubleTap: _supportFromPhoto,
                        onTap: () => _openDetail(context, ref),
                        child: _PostMedia(
                          complaint: complaint,
                          accent: accent,
                          burst: _burst,
                        ),
                      ),
                    ),
                    if (complaint.description.trim().isNotEmpty)
                      _PostBody(
                        text: complaint.description.trim(),
                        accent: accent,
                        on: painted,
                      )
                    else
                      const SizedBox(height: AppSpace.md),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: AppSpace.md,
                      endIndent: AppSpace.md,
                      color: colors.outlineVariant,
                    ),
                    // Barra de acciones repartida a lo ancho, como en una red
                    // social: cada acción tiene su tercio.
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xs,
                        vertical: AppSpace.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            // Cada acción se achica en su tercio antes que
                            // desbordar (letra grande del sistema, pantalla
                            // angosta).
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: LikeButton(
                                liked: complaint.likedByMe,
                                count: complaint.likeCount,
                                on: painted,
                                onTap: _toggleLike,
                              ),
                            ),
                          ),
                          Expanded(
                            // Cada acción se achica en su tercio antes que
                            // desbordar (letra grande del sistema, pantalla
                            // angosta).
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _CommentPill(
                                count: complaint.commentCount,
                                on: painted,
                                accent: accent,
                                onTap: () => _openDetail(context, ref),
                              ),
                            ),
                          ),
                          Expanded(
                            // Cada acción se achica en su tercio antes que
                            // desbordar (letra grande del sistema, pantalla
                            // angosta).
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _OpenHint(
                                accent: accent,
                                on: painted,
                                onTap: () => _openDetail(context, ref),
                              ),
                            ),
                          ),
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

/// Tercera acción del pie: «Ver reporte», con el acento del motivo.
class _OpenHint extends StatelessWidget {
  const _OpenHint({
    required this.accent,
    required this.on,
    required this.onTap,
  });

  final Color accent;
  final Color on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = AppColors.tint(accent, on, 0.12);
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
              Text(
                'Ver',
                style: TextStyle(
                  fontSize: 14,
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Icon(Icons.arrow_forward_rounded, size: 18, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera de la publicación, como el «autor» de una red social: la insignia
/// del micro con su color GTFS, «Micro N» y «recorrido · hace cuánto», y el
/// estado a la derecha (solo si no está verificada: la verificada no lo repite).
class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.routeName,
    required this.routeColor,
    required this.meta,
    required this.status,
    required this.on,
  });

  final String routeName;
  final Color routeColor;
  final String meta;
  final String status;

  /// Superficie pintada de la tarjeta (contra ella se mide el estado).
  final Color on;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.md,
        AppSpace.md,
        AppSpace.md,
      ),
      child: Row(
        children: [
          MicroBadge(label: routeName, color: routeColor, size: 42),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Micro $routeName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (status != 'approved') ...[
            const SizedBox(width: AppSpace.sm),
            StatusChip(status: status, on: on),
          ],
        ],
      ),
    );
  }
}

/// Foto (o póster del motivo) con márgenes y esquinas redondeadas dentro de la
/// tarjeta. Encima solo va lo que describe la imagen: el motivo abajo y el
/// contador de fotos arriba. El corazón del apoyo late aquí.
class _PostMedia extends StatelessWidget {
  const _PostMedia({
    required this.complaint,
    required this.accent,
    required this.burst,
  });

  final ComplaintSummary complaint;
  final Color accent;

  /// Clave del corazón: cada apoyo nuevo es una animación nueva.
  final int burst;

  static const double _photoHeight = 196;
  static const double _posterHeight = 124;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final photo = complaint.photoUrls.firstOrNull;
    final total = complaint.photoUrls.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: photo == null ? _posterHeight : _photoHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo == null)
              ComplaintCategoryPoster(
                accent: accent,
                category: complaint.category,
              )
            else
              PhotoShine(
                // `SizedBox.expand`: [PhotoShine] afloja las restricciones
                // mientras dura el destello y la foto se encogía.
                child: SizedBox.expand(
                  child: ComplaintPhoto(
                    url: photo,
                    radius: BorderRadius.zero,
                    placeholderSurface: colors.surfaceContainerHighest,
                  ),
                ),
              ),
            // Velo SOLO abajo, para el motivo: la foto se ve limpia arriba.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x8C000000)],
                  stops: [0.55, 1],
                ),
              ),
            ),
            Positioned(
              left: AppSpace.sm + 2,
              bottom: AppSpace.sm + 2,
              right: AppSpace.sm + 2,
              child: Align(
                alignment: Alignment.centerLeft,
                // Sobre el medio: el relleno se mide contra negro (el velo).
                child: CategoryChip(
                  category: complaint.category,
                  on: Colors.black,
                ),
              ),
            ),
            if (photo != null && total > 1)
              Positioned(
                top: AppSpace.sm + 2,
                right: AppSpace.sm + 2,
                child: PhotoScrimPill(
                  label: '+${total - 1} fotos',
                  icon: Icons.photo_library_rounded,
                ),
              ),
            if (burst > 0)
              Positioned.fill(
                child: IgnorePointer(child: _HeartBurst(key: ValueKey(burst))),
              ),
          ],
        ),
      ),
    );
  }
}

/// El relato, con un filete del color del motivo a la izquierda (como una
/// cita): se lee como lo que el pasajero contó, no como un pie de foto.
class _PostBody extends StatelessWidget {
  const _PostBody({required this.text, required this.accent, required this.on});

  final String text;
  final Color accent;
  final Color on;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.md,
        AppSpace.md,
        AppSpace.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppColors.tint(accent, on, 0.7), width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpace.md),
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyLarge?.copyWith(
              height: 1.4,
              color: context.colors.onSurface,
            ),
          ),
        ),
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
