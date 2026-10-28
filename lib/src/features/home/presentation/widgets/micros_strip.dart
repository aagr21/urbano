import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../../../core/widgets/photo_shine.dart';
import '../../../../core/widgets/route_photo.dart';
import '../../../routes/data/route_models.dart';
import '../../../routes/presentation/route_providers.dart';

/// Tirilla horizontal "Tus micros": una tarjeta por línea, pintada con el
/// **color GTFS real** del micro (los micros cruceños se pintan de verdad, la
/// interfaz lo cuenta). Sustituye a la lista vertical "Rutas populares": su
/// contenido era el listado del catálogo duplicado; la tirilla ahora se lee
/// como un carrusel de color y el catálogo completo vive en "Ver todas".
///
/// Tocar abre el detalle de la línea. La entrada en cascada la pone el home;
/// cada tarjeta, además, sube con su propio [Reveal] al entrar al viewport.
class MicrosStrip extends ConsumerWidget {
  const MicrosStrip({super.key});

  static const _query = RoutesQuery(limit: 6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesListProvider(_query));

    return AsyncValueView(
      value: routes,
      onRetry: () => ref.invalidate(routesListProvider(_query)),
      // Catálogo vacío: la sección no es indispensable, se retira en silencio.
      isEmpty: (page) => page.items.isEmpty,
      onEmpty: () => const SizedBox.shrink(),
      loadingCount: 3,
      loading: () => Reveal(
        slide: 8,
        child: SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: 2,
            ),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
            itemBuilder: (_, _) => const LoadingShimmer(
              width: 150,
              height: 148,
              radius: AppRadius.md,
            ),
          ),
        ),
      ),
      data: (page) => SizedBox(
        height: 180,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          itemCount: page.items.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
          itemBuilder: (context, i) => _MicroCard(
            key: ValueKey(page.items[i].id),
            route: page.items[i],
            index: i,
            onTap: () => context.push(
              UrbanoRoutes.routeDetail(page.items[i].id, from: 'home'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una línea: su color de micro, su nombre y su horizonte (ida y vuelta).
class _MicroCard extends StatelessWidget {
  const _MicroCard({
    super.key,
    required this.route,
    required this.index,
    required this.onTap,
  });

  final RouteSummary route;

  /// Posición en la tirilla: fija lo que tarda en entrar la tarjeta.
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    // Color GTFS arbitrario y texto GTFS arbitrario encima: [onColor] decide
    // (y respeta `textColor` del feed si contrasta).
    final background = AppColors.fromHex(
      route.color,
      fallback: AppColors.primary,
    );
    final foreground = AppColors.onColor(
      background,
      preferred: AppColors.fromHex(route.textColor),
    );

    final radius = BorderRadius.circular(AppRadius.md);
    final photoUrl = route.imageUrl;

    return Reveal(
      index: index,
      slide: 8,
      child: PressScale(
        child: Container(
          width: 172,
          decoration: BoxDecoration(color: background, borderRadius: radius),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: photoUrl != null
                  ? // Vitrina: foto a sangre, scrub degradado y el nombre
                    // encima (patrón de FeaturedMapCard; el único contenido
                    // claro posible sobre foto oscura es blanco). El
                    // destello Ken Burns de entrada lo pone [PhotoShine]
                    // (una pasada y en reposo, sin loops).
                    PhotoShine(
                      child: ClipRRect(
                        borderRadius: radius,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RoutePhoto(
                              url: photoUrl,
                              radius: BorderRadius.zero,
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.78),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 10,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // «Cartel» frontal: el identificador de la
                                  // línea, como el letrero del parabrisas.
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.32,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      route.shortName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.titleSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    route.longName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.labelSmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // «Cartel» frontal: el identificador de la línea, como
                          // el letrero que cuelga del parabrisas.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.32),
                              ),
                            ),
                            child: Text(
                              route.shortName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            route.longName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                route.directionsCount > 1
                                    ? Icons.swap_horiz_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 13,
                                color: foreground,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  route.directionsCount > 1
                                      ? 'Ida y vuelta'
                                      : 'Solo ida',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.labelSmall?.copyWith(
                                    color: foreground.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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
