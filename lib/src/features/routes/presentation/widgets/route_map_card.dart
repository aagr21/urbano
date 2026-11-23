import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/map/map.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/urbano_map.dart';
import '../../data/route_models.dart';
import '../route_providers.dart';
import 'route_map_chrome.dart';
import 'route_places.dart';

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
                  MapMarker(
                    id: 'route-shape-start',
                    point: points.first,
                    width: 22,
                    height: 22,
                    child: const _EndDot(color: AppColors.success),
                  ),
                  // El micro sobre el trazado: la misma identidad del mapa
                  // completo, para que la vista previa no sea solo una línea.
                  if (points.length > 1)
                    MapMarker(
                      id: 'route-shape-bus',
                      point: _shapeMidpoint(points),
                      width: 36,
                      height: 36,
                      child: _RouteBusMarker(color: routeColor),
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
              // Único acceso al recorrido completo: el detalle ya no repite
              // controles de ida/vuelta más abajo.
              Positioned(
                right: 12,
                top: 12,
                child: PressScale(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      onTap: onOpenFullMap,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        // Único contenido claro posible sobre foto/mapa
                        // oscuro: blanco.
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
}

/// Punto medio aproximado del trazado (por índice): alcanza para colgar el
/// micro sobre la polilínea sin importar cuántos vértices traiga el feed.
LatLng _shapeMidpoint(List<LatLng> points) => points[points.length ~/ 2];

/// Mapa del recorrido A PANTALLA COMPLETA y **sin header**.
///
/// El trazado entra entero (padding mínimo), la identidad de la línea flota
/// arriba ([RouteMapPlate]) con su micro ilustrado y su sentido, y abajo vive
/// el overlay plegable de [RoutePlaces]. La flecha de vuelta también flota:
/// ningún `AppBar` recorta el recorrido.
///
/// El overlay es PLEGABLE: colapsado deja ver el mapa (la lista tapaba la
/// mitad baja) y un tap lo expande sobre una barra pequeña; otro tap lo
/// vuelve a guardar. El estado vive aquí, no en un provider: es efímero
/// (muere con la página).
class RouteFullMap extends StatefulWidget {
  const RouteFullMap({
    super.key,
    required this.detail,
    required this.routeColor,
    required this.routeKey,
    this.directionLabel,
  });

  final RouteDetail detail;
  final Color routeColor;
  final RouteKey routeKey;

  /// «ida»/«vuelta» cuando se abrió desde el detalle; `null` lo deriva del
  /// [routeKey].
  final String? directionLabel;

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
    final label = _label();

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerHighest,
      body: bounds == null
          ? const Stack(
              fit: StackFit.expand,
              children: [
                EmptyState(
                  icon: Icons.map_outlined,
                  title: 'Sin ruta registrada',
                  message: 'El feed no dibuja trazado para esta línea.',
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpace.md),
                      child: MapFloatingBack(),
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // El mapa manda: de borde a borde, el trazado entero en el
                // encuadre (ajuste a la caja).
                Positioned.fill(
                  child: UrbanoMap(
                    center: points.first,
                    // Hueco para el chrome flotante: la placa de identidad
                    // arriba y la píldora «Pasa por» abajo no deben tapar el
                    // trazado.
                    cameraFit: MapCameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.fromLTRB(24, 120, 24, 100),
                    ),
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
                        id: 'full-shape-bus',
                        point: _shapeMidpoint(points),
                        child: _RouteBusMarker(color: routeColor),
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
                // Chrome flotante: salida + identidad de la línea. Sin
                // `AppBar`, el recorrido usa todo el alto de la pantalla.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MapFloatingBack(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RouteMapPlate(
                            detail: detail,
                            routeColor: routeColor,
                            directionLabel: label,
                          ),
                        ),
                      ],
                    ),
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

  /// «Ida»/«Vuelta» del sentido visible. Con una sola dirección no se rotula:
  /// no hay nada que distinguir.
  String? _label() {
    if (widget.detail.directions.length < 2) return null;
    final raw =
        widget.directionLabel ??
        (widget.routeKey.directionId == 0 ? 'ida' : 'vuelta');
    if (raw.isEmpty) return null;
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
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

/// Punto de origen/destino del trazado.
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

/// Micro de la línea sobre su propio trazo: disco del color GTFS con el ícono
/// del bus en la tinta legible. Es el «acá va el micro» de los demás mapas.
class _RouteBusMarker extends StatelessWidget {
  const _RouteBusMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 8),
      ],
    ),
    alignment: Alignment.center,
    child: Icon(
      Icons.directions_bus_rounded,
      size: 19,
      color: AppColors.onColor(color),
    ),
  );
}
