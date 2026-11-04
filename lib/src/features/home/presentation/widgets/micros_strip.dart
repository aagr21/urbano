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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(routesListProvider(homeCatalogQuery));

    return AsyncValueView(
      value: routes,
      onRetry: () => ref.invalidate(routesListProvider(homeCatalogQuery)),
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
    // Tinta sobre foto: el peor caso real detrás de la letra es el scrub negro
    // del pie, no la foto.
    final onPhoto = AppColors.onColor(Colors.black);

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
                    // encima. El destello Ken Burns de entrada lo pone
                    // [PhotoShine] (una pasada y en reposo, sin loops).
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
                              left: AppSpace.md,
                              right: AppSpace.md,
                              bottom: AppSpace.sm + 2,
                              child: _RouteInfo(
                                route: route,
                                ink: onPhoto,
                                openHint: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(AppSpace.md + 2),
                      child: _RouteInfo(
                        route: route,
                        ink: foreground,
                        openHint: true,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartel frontal de la línea (su identificador), su nombre largo y si tiene
/// ida y vuelta.
///
/// La píldora del identificador es **vidrio de la tinta**, no un blanco fijo:
/// sobre un micro amarillo (`F1C40F`) el vidrio blanco de antes desaparecía y
/// dejaba el número flotando; con la tinta medida se ve en cualquier color.
class _RouteInfo extends StatelessWidget {
  const _RouteInfo({
    required this.route,
    required this.ink,
    required this.openHint,
  });

  final RouteSummary route;

  /// Tinta ya medida contra el fondo realmente pintado (color del micro o
  /// scrub de la foto).
  final Color ink;

  /// La tarjeta sin foto deja sitio para la pista de «abre el detalle»; la que
  /// lleva foto ya lo dice la propia imagen.
  final bool openHint;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final twoWays = route.directionsCount > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Con pista de apertura la tarjeta reparte su alto (el nombre se apoya al
      // pie); sobre la foto el bloque se ciñe a su contenido.
      mainAxisSize: openHint ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Row(
          children: [
            // «Cartel» frontal: el identificador de la línea, como el letrero
            // que cuelga del parabrisas.
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm + 2,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: ink.withValues(alpha: 0.3)),
                ),
                child: Text(
                  route.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    color: ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            if (openHint) ...[
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                size: 15,
                color: ink.withValues(alpha: 0.65),
              ),
            ],
          ],
        ),
        if (openHint) const Spacer() else const SizedBox(height: AppSpace.xs),
        Text(
          route.longName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.labelMedium?.copyWith(
            color: ink,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: AppSpace.xs + 2),
        Row(
          children: [
            Icon(
              twoWays ? Icons.swap_horiz_rounded : Icons.arrow_forward_rounded,
              size: 13,
              color: ink.withValues(alpha: 0.85),
            ),
            const SizedBox(width: AppSpace.xs),
            Flexible(
              child: Text(
                twoWays ? 'Ida y vuelta' : 'Solo ida',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                  color: ink.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
