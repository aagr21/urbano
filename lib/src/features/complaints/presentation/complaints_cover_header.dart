// Cabecera del feed de quejas: portada con título, CTA «Crear» y
// las tres estadísticas (ver la regla de la cortina en AGENTS.md).

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/identity/passenger_identity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/loading_shimmer.dart' show LoadingShimmer;
import '../../home/presentation/widgets/home_route_lattice.dart';
import '../application/complaints_feed_controller.dart';
import 'widgets/passenger_avatar.dart';

/// Portada de la sección: un campo de marca **a sangre** (sin AppBar) con los
/// anillos de la ciudad, el título, el CTA de crear, el apodo y las cifras de la
/// comunidad rodando con [CountUp].
///
/// Sustituye a la tarjeta CTA flotante de la iteración anterior: una tarjeta
/// dentro de una pantalla con AppBar seguía leyéndose como «un listado más».
/// Aquí la pantalla arranca en la marca y el contenido entra debajo.
class ComplaintsCoverHeader extends StatelessWidget {
  const ComplaintsCoverHeader({
    super.key,
    required this.stats,
    required this.sort,
    required this.onSort,
    required this.loading,
    required this.identity,
    required this.onCreate,
    required this.onIdentity,
    this.leading,
  });

  final ({int reports, int supports, int comments}) stats;

  /// Orden activo del feed: su cifra se resalta en la portada.
  final ComplaintSort sort;
  final ValueChanged<ComplaintSort> onSort;
  final bool loading;
  final PassengerIdentity? identity;
  final VoidCallback onCreate;
  final VoidCallback onIdentity;

  /// Flecha de retroceso que comparte la fila del título: entra en el alto que
  /// ya ocupaba la columna del título, sin robarle píxeles a la primera queja.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    // El campo es el degradado de verdes de la marca (el mismo de la tarjeta
    // «Planifica tu viaje»), con la tinta blanca de la marca encima, siempre
    // en negrita. El CTA «Crear» es la píldora blanca con el naranja, como en
    // el diseño «Pantalla Quejas».
    const ink = AppColors.onBrand;
    // Vidrio de las cifras: blanco al 12 %, con filo blanco del 55 %.
    final veil = ink.withValues(alpha: 0.12);
    final edge = ink.withValues(alpha: 0.55);

    return ClipRRect(
      // Esquinas inferiores: la portada es una hoja de marca, no una banda que
      // corta la pantalla en dos.
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.xl),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: urbanoGradient),
        child: Stack(
          children: [
            // Los anillos de la ciudad que ya pinta el home: la misma textura de
            // marca, con la unidad circulando. No ocupa layout (va de fondo) y es
            // `IgnorePointer`, así que no roba toques al CTA.
            const Positioned.fill(child: HomeRouteLattice()),
            // Riel de marca al pie de la portada.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.lime,
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.sm,
                  AppSpace.md,
                  AppSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: AppSpace.xs),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quejas',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleLarge?.copyWith(
                                  color: ink,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  // Punto naranja: el acento de la marca en el
                                  // lugar más pequeño de la portada.
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpace.sm),
                                  // `FittedBox` en vez de elipsis: el lema es lo
                                  // primero que se lee de la sección y con la
                                  // etiqueta del CTA se quedaba en «La voz del
                                  // pasaj…». Si no cabe, se achica, nunca se
                                  // corta.
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'La voz del pasajero',
                                        maxLines: 1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: ink,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        // El CTA va pegado al título, no ocupando una fila de
                        // 48 px para él solo. La etiqueta es corta por lo mismo:
                        // el espacio que usa se lo quita al título; el tooltip
                        // dice el nombre completo.
                        Tooltip(
                          message: 'Crear queja',
                          child: FilledButton.icon(
                            onPressed: onCreate,
                            icon: const Icon(
                              Icons.add_comment_rounded,
                              size: 16,
                            ),
                            label: const Text('Crear'),
                            style: FilledButton.styleFrom(
                              foregroundColor: AppColors.accentDeep,
                              backgroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.md,
                                vertical: AppSpace.sm,
                              ),
                              // Se parte de un estilo del tema (titleSmall ya
                              // trae Montserrat) en vez de un `TextStyle` desnudo:
                              // sin familia el botón cae en la fuente por
                              // defecto y gasta ancho de más, que es justo el
                              // que necesita el título para no cortarse.
                              textStyle: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: identity == null
                              ? 'Tu apodo'
                              : 'Tu apodo: ${identity!.nickname}',
                          onPressed: onIdentity,
                          visualDensity: VisualDensity.compact,
                          icon: identity == null
                              ? const Icon(
                                  Icons.account_circle_outlined,
                                  color: ink,
                                  size: 26,
                                )
                              : PassengerAvatar.from(identity!, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        ComplaintsStatTile(
                          value: stats.reports,
                          label: 'reportes',
                          selected: sort == ComplaintSort.recent,
                          onTap: () => onSort(ComplaintSort.recent),
                          icon: Icons.forum_rounded,
                          veil: veil,
                          ink: ink,
                          edge: edge,
                          loading: loading,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        ComplaintsStatTile(
                          value: stats.supports,
                          label: 'apoyos',
                          selected: sort == ComplaintSort.supported,
                          onTap: () => onSort(ComplaintSort.supported),
                          icon: Icons.favorite_rounded,
                          veil: veil,
                          ink: ink,
                          edge: edge,
                          loading: loading,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        ComplaintsStatTile(
                          value: stats.comments,
                          label: 'comentarios',
                          selected: sort == ComplaintSort.discussed,
                          onTap: () => onSort(ComplaintSort.discussed),
                          icon: Icons.chat_bubble_rounded,
                          veil: veil,
                          ink: ink,
                          edge: edge,
                          loading: loading,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cifra de la portada que también ORDENA el feed: «apoyos» pone arriba lo
/// más apoyado, «comentarios» lo más comentado y «reportes» vuelve a lo
/// reciente. La elegida se ilumina (vidrio más claro, filo firme y una flecha
/// de orden), así la cifra dice a la vez cuánto hay y cómo se está mirando.
class ComplaintsStatTile extends StatelessWidget {
  const ComplaintsStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.veil,
    required this.ink,
    required this.edge,
    required this.loading,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color veil;
  final Color ink;
  final Color edge;
  final bool loading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Ordenar por $label',
        child: PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: AnimatedContainer(
              duration: Motion.quick,
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: AppSpace.xs + 2,
              ),
              decoration: BoxDecoration(
                color: selected ? ink.withValues(alpha: 0.2) : veil,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected ? ink.withValues(alpha: 0.7) : edge,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: ink.withValues(alpha: 0.8)),
                      const SizedBox(width: AppSpace.xs),
                      if (loading)
                        const LoadingShimmer(width: 24, height: 18)
                      else
                        CountUp(
                          value: value,
                          format: (count) => '$count',
                          style: text.titleMedium?.copyWith(
                            color: ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      const Spacer(),
                      AnimatedOpacity(
                        duration: Motion.quick,
                        opacity: selected ? 1 : 0,
                        child: Icon(Icons.south_rounded, size: 13, color: ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: ink.withValues(alpha: selected ? 1 : 0.82),
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
