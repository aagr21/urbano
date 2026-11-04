import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/map/map.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/urbano_map.dart';
import '../home_providers.dart';

/// Tarjeta destacada con mini mapa de Santa Cruz → abre la pantalla-mapa
/// única (Viaje).
///
/// Si el backend trae una ruta con `shape`, se dibuja su polilínea y la
/// cámara se encuadra sobre ella (el mapa sigue siendo decorativo:
/// `interactive: false`).
///
/// La tarjeta se enmarca en el **degradado de la marca** (3 px de orilla) para
/// que el mapa no sea un rectángulo más del lienzo: es la ventana de Urbano a
/// la ciudad. El botón de abajo es una píldora con su etiqueta, no un cuadrito
/// con un ícono que había que adivinar.
class FeaturedMapCard extends ConsumerStatefulWidget {
  const FeaturedMapCard({super.key});

  static const _santaCruz = LatLng(-17.7833, -63.1821);

  @override
  ConsumerState<FeaturedMapCard> createState() => _FeaturedMapCardState();
}

class _FeaturedMapCardState extends ConsumerState<FeaturedMapCard> {
  final _controller = UrbanoMapController(
    center: FeaturedMapCard._santaCruz,
    zoom: 11.5,
  );

  /// Última forma ya encuadrada (para no re-encuadrar en cada rebuild).
  FeaturedRouteShape? _fittedShape;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeFit(FeaturedRouteShape? shape) {
    if (shape == null || identical(shape, _fittedShape)) return;
    _fittedShape = shape;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.fitBounds(
        shape.points,
        padding: const EdgeInsets.all(24),
        maxZoom: 13,
        animated: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final stats = ref.watch(statsProvider);
    final shape = ref.watch(featuredRouteShapeProvider).valueOrNull;
    _maybeFit(shape);

    // La entrada en cascada la pone el home; el pulsado, aquí.
    return PressScale(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        child: Container(
          // Filo de marca: dos rectángulos concéntricos (el de afuera pinta el
          // degradado y el de adentro recorta el mapa 3 px más chico).
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg + 3),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.aqua,
                AppColors.primary,
                AppColors.primaryDark,
              ],
              stops: [0, 0.55, 1],
            ),
            boxShadow: AppTheme.softShadow(
              color: AppColors.primary,
              opacity: 0.24,
              blur: 26,
              dy: 12,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Material(
              color: colors.surface,
              child: InkWell(
                // `go`, no `push`: así la pestaña Viaje conmuta de verdad y la
                // barra inferior la refleja (un `push` abriría esta pantalla
                // ENCIMA del shell y la barra quedaba rezagada en Inicio).
                onTap: () => context.go('/journey'),
                child: SizedBox(
                  height: 190,
                  // El mapa de la tarjeta usa el tile elegido por el usuario; el
                  // scrub, el texto y el ícono siguen el tema de la app.
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      UrbanoMap(
                        controller: _controller,
                        center: FeaturedMapCard._santaCruz,
                        zoom: 11.5,
                        interactive: false,
                        attribution: false,
                        polylines: shape == null
                            ? const <MapPolyline>[]
                            : [
                                MapPolyline(
                                  points: shape.points,
                                  color: AppColors.fromHex(shape.colorHex),
                                  outline: true,
                                ),
                              ],
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.74),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpace.lg,
                        right: AppSpace.md,
                        bottom: AppSpace.md,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Explora Santa Cruz en el mapa',
                                    maxLines: 2,
                                    style: text.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.xs + 2),
                                  Row(
                                    children: [
                                      // Punto vivo junto al recuento: dice
                                      // «esto está leído del feed, ahora» sin
                                      // agregar texto nuevo.
                                      const _CoverageDot(),
                                      const SizedBox(width: AppSpace.md),
                                      Flexible(
                                        child: Text(
                                          stats.when(
                                            data: (s) => '${s.routes} rutas',
                                            loading: () =>
                                                'Cargando cobertura…',
                                            error: (_, _) =>
                                                'Mapa interactivo de la ciudad',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: text.labelSmall?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
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
                            const _PlanPill(),
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
      ),
    );
  }
}

/// Píldora de acción de la tarjeta: dice qué pasa si se toca.
class _PlanPill extends StatelessWidget {
  const _PlanPill();

  @override
  Widget build(BuildContext context) {
    // Sobre el scrub oscuro del mapa el fondo más seguro es el blanco medido
    // con [AppColors.onColor], no un `Colors.white` de memoria; la tinta verde
    // se ajusta contra ESE blanco.
    final bg = AppColors.onColor(Colors.black);
    final ink = AppColors.legible(AppColors.primary, bg);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm + 1,
        AppSpace.md,
        AppSpace.sm + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_rounded, size: 16, color: ink),
          const SizedBox(width: AppSpace.xs + 2),
          Text(
            'Planificar',
            style: context.text.labelMedium?.copyWith(
              color: ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Halo que late sobre el scrub oscuro de la tarjeta: el único claro posible
/// sobre ese fondo es un aqua luminoso (`accentSoft`/`aquaSoftDark`), no el
/// tinte puro del GTFS.
class _CoverageDot extends StatelessWidget {
  const _CoverageDot();

  @override
  Widget build(BuildContext context) {
    // Se mide el fondo REALMENTE pintado: el scrub negro de la tarjeta siempre
    // es oscuro, con mapa claro u oscuro y con tema claro u oscuro. Por eso el
    // tinte NO sale del brillo del tema (haría cruz cuando el mapa se pone por
    // su cuenta): se pide la versión luminosa y se pasa por `legible` contra el
    // propio degradado.
    final scrim = Color.lerp(Colors.black, AppColors.canvasLight, 0.28)!;
    final tint = AppColors.legible(AppColors.aquaSoftDark, scrim);
    return Transform.translate(
      // El `LiveDot` reserva 3x su núcleo: se compensa para que el texto quede
      // alineado con el punto.
      offset: const Offset(-4.5, 0),
      child: LiveDot(color: tint, size: 5),
    );
  }
}
