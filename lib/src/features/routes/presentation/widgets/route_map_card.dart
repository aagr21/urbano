import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/map/map.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/urbano_map.dart';
import '../../data/route_models.dart';
import 'route_map_markers.dart';

/// Tarjeta de previsualización del recorrido del sentido activo.
///
/// El mapa es solo la vista previa; «Recorrido completo» abre el mapa a
/// sangre ([RouteFullMap]) con el mismo sentido que el detalle está
/// mostrando. La navegación la decide el detalle ([onOpenFullMap]) para que
/// use el router de la app y no un `Navigator` suelto.
class RouteMapCard extends StatelessWidget {
  const RouteMapCard({
    super.key,
    required this.detail,
    required this.routeColor,
    required this.onOpenFullMap,
  });

  final RouteDetail detail;
  final Color routeColor;

  /// Abre el mapa del sentido activo a pantalla completa.
  final VoidCallback onOpenFullMap;

  @override
  Widget build(BuildContext context) {
    final points = detail.shape!.points;
    final bounds = MapBounds.fromPoints(points);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SizedBox(
          height: 230,
          // Previsualización del recorrido: solo el mapa base sigue el tile
          // elegido; la píldora y su texto usan el tema de la app.
          child: Stack(
            fit: StackFit.expand,
            children: [
              UrbanoMap(
                center: points.first,
                cameraFit: MapCameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(32),
                  maxZoom: 16,
                ),
                polylines: [
                  MapPolyline(
                    points: points,
                    width: 6,
                    color: routeColor,
                    outline: true,
                  ),
                ],
                markers: [
                  RouteEndDot.marker(
                    id: 'route-shape-start',
                    point: points.first,
                    color: AppColors.success,
                  ),
                  // El micro sobre el trazado: la misma identidad del mapa
                  // completo, para que la vista previa no sea solo una línea.
                  if (points.length > 1)
                    RouteBusMarker.marker(
                      id: 'route-shape-bus',
                      point: routeShapeMidpoint(points),
                      color: routeColor,
                    ),
                  RouteEndDot.marker(
                    id: 'route-shape-end',
                    point: points.last,
                    color: AppColors.danger,
                  ),
                ],
              ),
              // Único acceso al recorrido completo: el detalle ya no repite
              // controles de ida/vuelta más abajo.
              // Arriba a la derecha: abajo tapaba el pin de llegada y el
              // crédito del mapa. Sombra suave en vez de `elevation`, que
              // dibujaba un contorno duro alrededor de la píldora.
              Positioned(
                right: 10,
                top: 10,
                child: PressScale(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x29000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: InkWell(
                        onTap: onOpenFullMap,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_full_rounded,
                                size: 15,
                                color: AppColors.legible(
                                  routeColor,
                                  context.colors.surface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Recorrido completo',
                                style: context.text.labelMedium?.copyWith(
                                  color: context.colors.onSurface,
                                  fontWeight: FontWeight.w700,
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
            ],
          ),
        ),
      ),
    );
  }
}
