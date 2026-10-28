import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/map/map.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../../core/widgets/urbano_map.dart';
import '../../data/route_models.dart';
import '../route_providers.dart';
import 'route_places.dart';

class RouteMapCard extends StatelessWidget {
  const RouteMapCard({
    super.key,
    required this.detail,
    required this.routeColor,
  });

  final RouteDetail detail;
  final Color routeColor;

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
                  MapMarker(
                    id: 'route-shape-start',
                    point: points.first,
                    width: 22,
                    height: 22,
                    child: const _EndDot(color: AppColors.success),
                  ),
                  MapMarker(
                    id: 'route-shape-end',
                    point: points.last,
                    width: 22,
                    height: 22,
                    child: const _EndDot(color: AppColors.danger),
                  ),
                ],
              ),
              // Tarjeta DE MAPA abrible: «Ver recorrido completo» lleva a la
              // página full-bleed (mapa desde borde a borde + los lugares
              // principales de [RoutePlaces] como overlay inferior).
              Positioned(
                right: 12,
                top: 12,
                child: PressScale(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      onTap: () => _openFullMap(context, detail, routeColor),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        // Único contenido claro posible sobre foto/mapa
                        // oscuro: blanco (patrón documentado en las reglas).
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.fullscreen_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Recorrido completo',
                              style: context.text.labelSmall?.copyWith(
                                color: Colors.white,
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
            ],
          ),
        ),
      ),
    );
  }

  void _openFullMap(BuildContext context, RouteDetail detail, Color color) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RouteFullMap(
          detail: detail,
          routeColor: color,
          routeKey: RouteKey(detail.id),
        ),
      ),
    );
  }
}

/// Mapa del recorrido A PANTALLA COMPLETA: la polilínea entra entera (padding
/// mínimo), la insignia de la línea arriba y abajo un overlay con
/// [RoutePlaces] — los lugares principales, la misma heurística del detalle.
///
/// El overlay es PLEGABLE: colapsado deja ver el mapa (la lista tapaba la
/// mitad baja) y un tap lo expande sobre una barra pequeña; otro tap lo
/// vuelve a guardarse. El estado vive aquí, no en un provider: es efímero
/// (muere con la página).
class RouteFullMap extends StatefulWidget {
  const RouteFullMap({
    super.key,
    required this.detail,
    required this.routeColor,
    required this.routeKey,
  });

  final RouteDetail detail;
  final Color routeColor;
  final RouteKey routeKey;

  @override
  State<RouteFullMap> createState() => RouteFullMapState();
}

class RouteFullMapState extends State<RouteFullMap> {
  bool _overlayOpen = false;

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final routeColor = widget.routeColor;
    final points = detail.shape?.points ?? const [];
    final bounds = points.length > 1 ? MapBounds.fromPoints(points) : null;
    final text = context.text;

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerHighest,
      appBar: AppBar(
        title: Row(
          children: [
            RouteBadge(
              label: detail.shortName,
              colorHex: detail.color,
              textColorHex: detail.textColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recorrido completo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium,
              ),
            ),
          ],
        ),
      ),
      body: bounds == null
          ? const EmptyState(
              icon: Icons.map_outlined,
              title: 'Sin ruta registrada',
              message: 'El feed no dibuja trazado para esta línea.',
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // El mapa manda: de borde a borde, el trazado entero en el
                // encuadre (ajuste a la caja).
                Positioned.fill(
                  child: UrbanoMap(
                    center: points.first,
                    cameraFit: MapCameraFit.bounds(bounds: bounds),
                    polylines: [
                      MapPolyline(
                        points: points,
                        width: 7,
                        color: routeColor,
                        outline: true,
                      ),
                    ],
                    markers: [
                      MapMarker(
                        id: 'full-shape-start',
                        point: points.first,
                        width: 22,
                        height: 22,
                        child: const _EndDot(color: AppColors.success),
                      ),
                      MapMarker(
                        id: 'full-shape-end',
                        point: points.last,
                        width: 22,
                        height: 22,
                        child: const _EndDot(color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
                // [RoutePlaces] plegable: pisado sobre una píldora pequeña
                // para no robarle espacio al mapa; expandido pone la tarjeta
                // con superficie, legible sobre el mapa vivo.
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _overlayOpen
                            ? Container(
                                key: const ValueKey('overlay-card'),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.surface.withValues(
                                    alpha: 0.92,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  border: Border.all(
                                    color: routeColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: _OverlayToggle(
                                        open: true,
                                        color: routeColor,
                                        onTap: () => setState(
                                          () => _overlayOpen = false,
                                        ),
                                      ),
                                    ),
                                    RoutePlaces(
                                      routeKey: widget.routeKey,
                                      routeColor: routeColor,
                                    ),
                                  ],
                                ),
                              )
                            : _OverlayToggle(
                                key: const ValueKey('overlay-pill'),
                                open: false,
                                color: routeColor,
                                onTap: () =>
                                    setState(() => _overlayOpen = true),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Barra/píldora del overlay plegable del mapa completo: cerrada ofrece
/// abrir la lista de lugares; abierta (sobre la tarjeta) la recoge.
class _OverlayToggle extends StatelessWidget {
  const _OverlayToggle({
    super.key,
    required this.open,
    required this.color,
    required this.onTap,
  });

  final bool open;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: open
            ? Colors.transparent
            : context.colors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  open ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  open ? 'Ocultar' : 'Pasa por',
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EndDot extends StatelessWidget {
  const _EndDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6),
      ],
    ),
  );
}
