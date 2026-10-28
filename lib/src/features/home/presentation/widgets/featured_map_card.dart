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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
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
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Explora Santa Cruz en el mapa',
                                  style: text.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    // Punto vivo junto al recuento: dice «esto
                                    // está leído del feed, ahora» sin agregar
                                    // texto nuevo.
                                    const _CoverageDot(),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        stats.when(
                                          data: (s) => '${s.routes} rutas',
                                          loading: () => 'Cargando cobertura…',
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
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                AppRadius.input,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.map_rounded,
                              color: colors.primary,
                              size: 22,
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
