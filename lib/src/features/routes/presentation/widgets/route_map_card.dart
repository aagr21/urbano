import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/location/compass_service.dart';
import '../../../../core/location/location_fab.dart';
import '../../../../core/map/map.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/my_location_dot.dart';
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
                  _EndDot.marker(
                    id: 'route-shape-start',
                    point: points.first,
                    color: AppColors.success,
                  ),
                  // El micro sobre el trazado: la misma identidad del mapa
                  // completo, para que la vista previa no sea solo una línea.
                  if (points.length > 1)
                    _RouteBusMarker.marker(
                      id: 'route-shape-bus',
                      point: _shapeMidpoint(points),
                      color: routeColor,
                    ),
                  _EndDot.marker(
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
class RouteFullMap extends ConsumerStatefulWidget {
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
  ConsumerState<RouteFullMap> createState() => RouteFullMapState();
}

class RouteFullMapState extends ConsumerState<RouteFullMap> {
  final _map = UrbanoMapController();
  bool _overlayOpen = false;
  bool _locating = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// Lleva la cámara a «mi ubicación» con el flujo completo del sistema
  /// (GPS apagado / permiso pendiente / bloqueado).
  ///
  /// Lectura PUNTUAL, como el selector de punto: este mapa no enciende el
  /// seguimiento continuo porque [followLocationProvider] es global y movería
  /// también la cámara del planeador de Viaje, que sigue montado debajo. Cada
  /// toque pide un fix fresco y el punto se queda donde se leyó.
  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final granted = await ref
          .read(locationControllerProvider.notifier)
          .activate(context);
      if (!granted || !mounted) return;
      ref.invalidate(myLocationProvider);
      final position = await ref.read(myLocationProvider.future);
      if (position == null || !mounted) return;
      _map.move(position, math.max(_map.zoom, 15.5));
    } on LocationFailure {
      // Sin fix: el recorrido sigue a la vista y el botón muestra el estado.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

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
                  child: _RouteLiveMap(
                    controller: _map,
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
                      _EndDot.marker(
                        id: 'full-shape-start',
                        point: points.first,
                        color: AppColors.success,
                      ),
                      _RouteBusMarker.marker(
                        id: 'full-shape-bus',
                        point: _shapeMidpoint(points),
                        color: routeColor,
                      ),
                      _EndDot.marker(
                        id: 'full-shape-end',
                        point: points.last,
                        color: AppColors.danger,
                      ),
                    ],
                  ),
                ),
                // Chrome flotante: salida + identidad de la línea. Sin
                // `AppBar`, el recorrido usa todo el alto de la pantalla.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
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
                        const SizedBox(height: 10),
                        // Botón de ubicación con estados reales (GPS apagado,
                        // permiso pendiente/bloqueado, listo). Arriba a la
                        // derecha, como en Viaje: abajo vive «Pasa por», que
                        // al abrirse crece y lo taparía.
                        LocationFab(
                          key: const ValueKey('route-map-my-location'),
                          following: false,
                          onFollowChanged: (enabled) {
                            if (enabled) _goToMyLocation();
                          },
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

  /// Diámetro visible del punto.
  static const double _diameter = 22;

  /// Marcador del extremo: la caja deja [kMarkerShadowMargin] de aire
  /// alrededor del punto para que la sombra entre entera en la imagen nativa.
  static MapMarker marker({
    required String id,
    required LatLng point,
    required Color color,
  }) => MapMarker(
    id: id,
    point: point,
    width: _diameter + kMarkerShadowMargin * 2,
    height: _diameter + kMarkerShadowMargin * 2,
    iconKey: 'route-end-${color.toARGB32().toRadixString(16)}',
    child: _EndDot(color: color),
  );

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 5),
        ],
      ),
    ),
  );
}

/// Micro de la línea sobre su propio trazo: disco del MISMO color que la
/// polilínea con el ícono del bus en la tinta legible.
class _RouteBusMarker extends StatelessWidget {
  const _RouteBusMarker({required this.color});

  final Color color;

  /// Diámetro visible del disco.
  static const double _diameter = 34;

  /// Marcador del micro.
  ///
  /// - `iconKey` lleva el COLOR: la caché de imágenes del rasterizador es
  ///   global y su clave salía del id (`route-shape-bus`, igual en todas las
  ///   líneas), así que el primer recorrido abierto fijaba el color del disco
  ///   para todos los demás.
  /// - La caja deja [kMarkerShadowMargin] de aire: con el disco ocupando toda
  ///   la imagen, la sombra se recortaba contra el cuadrado y solo quedaban
  ///   sus cuatro esquinas, unas «puntas» oscuras alrededor del círculo.
  static MapMarker marker({
    required String id,
    required LatLng point,
    required Color color,
  }) => MapMarker(
    id: id,
    point: point,
    width: _diameter + kMarkerShadowMargin * 2,
    height: _diameter + kMarkerShadowMargin * 2,
    iconKey: 'route-bus-${color.toARGB32().toRadixString(16)}',
    child: _RouteBusMarker(color: color),
  );

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 5),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.directions_bus_rounded,
        size: 19,
        color: AppColors.onColor(color),
      ),
    ),
  );
}

/// El mapa a sangre con el punto «mi ubicación».
///
/// Es un `Consumer` aparte por la misma regla que el planeador: la ubicación
/// solo puede reconstruir el mapa, nunca la placa, el overlay ni los botones.
/// El punto sale de la última posición conocida (o de la lectura puntual) y se
/// dibuja solo con permiso y GPS listos; la cámara no lo persigue — la mueve
/// el botón de ubicación.
class _RouteLiveMap extends ConsumerWidget {
  const _RouteLiveMap({
    required this.controller,
    required this.center,
    required this.cameraFit,
    required this.polylines,
    required this.markers,
  });

  final UrbanoMapController controller;
  final LatLng center;
  final MapCameraFit cameraFit;
  final List<MapPolyline> polylines;
  final List<MapMarker> markers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me =
        ref.watch(lastKnownLocationProvider) ??
        ref.watch(myLocationProvider).valueOrNull;
    final ready =
        ref.watch(locationControllerProvider).status == LocationStatus.ready;
    final shown = ready ? me : null;
    final heading = shown != null
        ? ref.watch(deviceHeadingProvider).valueOrNull ?? 0.0
        : 0.0;

    return UrbanoMap(
      controller: controller,
      center: center,
      cameraFit: cameraFit,
      polylines: polylines,
      pulses: [
        if (shown != null)
          MapPulse(point: shown, color: context.colors.primary),
      ],
      markers: [
        ...markers,
        if (shown != null)
          MyLocationDot.marker(
            id: 'route-map-my-location',
            point: shown,
            heading: heading,
          ),
      ],
    );
  }
}
