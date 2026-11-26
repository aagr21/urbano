import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/map/map.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/urbano_map.dart';
import '../../application/journey_map_geometry.dart';
import '../../application/leg_stroke_colors.dart';
import '../../data/journey_models.dart';
import '../../data/journey_repository.dart';
import 'journey_map_layers.dart';

// La flecha de sentido vive en el módulo compartido de marcadores; se
// reexporta para que quien la importaba desde aquí no cambie.
export '../journey_markers.dart' show RouteArrowMarker;

part 'journey_result_map_legend.dart';

/// Mapa de una opción de viaje: polilíneas de micro (con `geometry`, o línea
/// recta de degradado), tramos de caminata punteados y marcadores de origen
/// y destino.
///
/// - El **origen y el destino son fijos (no arrastrables)**: tocar y
///   arrastrar la ruta o el mapa desplaza la cámara libremente sin mover los
///   marcadores ni la ruta calculada. Para cambiar un punto se pulsa sobre él
///   (o se edita desde el panel).
/// - Al cambiar [option] la cámara se encuadra sobre los nuevos bounds
///   (animado por el motor).
/// - [showJourneyLayers] en `false` lo convierte en un **mapa de exploración**:
///   no dibuja legs/insignias/endpoints/leyenda ni encuadra el viaje; solo
///   muestra [extraPolylines] y [extraMarkers] (capas activadas por el
///   usuario).
///   La pantalla fusionada Viaje+Mapa monta UNA sola instancia y alterna así
///   entre explorar y ver resultados sin recrear la vista nativa.
class JourneyResultMap extends StatefulWidget {
  const JourneyResultMap({
    super.key,
    required this.option,
    required this.origin,
    required this.destination,
    this.showTiles = true,
    this.fitPadding = const EdgeInsets.all(28),
    this.onOriginMoved,
    this.onDestinationMoved,
    this.onOriginTap,
    this.onDestinationTap,
    this.showControls = true,
    this.showLegend = true,
    this.showJourneyLayers = true,
    this.showOrigin = true,
    this.showDestination = true,
    this.extraPolylines = const [],
    this.extraMarkers = const [],
    this.extraPulses = const <MapPulse>[],
    this.onMapReady,
    this.onPositionChanged,
    this.myLocationEnabled = false,
    this.followMyLocation = false,
    this.onTrackingDismissed,
  });

  final JourneyOption option;
  final JourneyPoint origin;
  final JourneyPoint destination;

  /// `false` solo para tests (evita fetch de tiles).
  final bool showTiles;

  final EdgeInsets fitPadding;

  /// El usuario arrastró el marcador de origen/destino a un punto nuevo.
  final ValueChanged<LatLng>? onOriginMoved;
  final ValueChanged<LatLng>? onDestinationMoved;

  /// El usuario tocó el marcador de origen/destino (para editarlo: abre el
  /// selector de punto en el mapa).
  final VoidCallback? onOriginTap;
  final VoidCallback? onDestinationTap;

  /// Botones de zoom y "encuadrar viaje".
  final bool showControls;

  /// Leyenda de colores (micro / caminata / transbordo).
  final bool showLegend;

  /// `false` = modo exploración: sin capas de viaje (legs, insignias,
  /// endpoints arrastrables, leyenda ni encuadre).
  final bool showJourneyLayers;

  /// ¿Se dibuja el pin de origen/destino? Independiente de
  /// [showJourneyLayers]: en modo exploración la pantalla decide si ya hay
  /// un extremo fijado para que se vea reflejado en el mapa (con un solo
  /// punto marcado solo se pinta ese).
  final bool showOrigin;
  final bool showDestination;

  /// Capas de exploración dibujadas junto (o en lugar de) las del viaje:
  /// polilíneas de rutas activadas por el usuario.
  final List<MapPolyline> extraPolylines;
  final List<MapMarker> extraMarkers;

  /// Auras pulsantes de ubicación exteriores ([MapPulse]).
  final List<MapPulse> extraPulses;

  /// El mapa terminó de cargar (una sola vez, igual que el motor).
  final VoidCallback? onMapReady;

  /// Cambio de cámara (`hasGesture` = lo movió el usuario).
  final MapPositionChangedCallback? onPositionChanged;

  /// Puck de "mi ubicación" y si la cámara lo sigue.
  final bool myLocationEnabled;
  final bool followMyLocation;

  /// El usuario hizo pan sobre el puck (dejó de seguir su ubicación).
  final VoidCallback? onTrackingDismissed;

  @override
  JourneyResultMapState createState() => JourneyResultMapState();
}

class JourneyResultMapState extends State<JourneyResultMap> {
  final _controller = UrbanoMapController();
  bool _ready = false;

  /// Ancho del pin de extremo (origen/destino).

  /// Puntos soltados a mano (anulados cuando la pantalla cambia el punto).
  LatLng? _originOverride;
  LatLng? _destinationOverride;

  /// `true` cuando el usuario movió/acercó la cámara por gesto. Marca la
  /// cámara como "suya": los cambios de opción (o de datos del viaje) ya NO
  /// re-encuadran automáticamente, para que alejar el mapa y explorar no
  /// salte de vuelta al encuadre del viaje. Se reactiva el encuadre cuando
  /// la pantalla fija un extremo nuevo (acción explícita del usuario).
  bool _userMovedCamera = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant JourneyResultMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.origin != oldWidget.origin ||
        widget.destination != oldWidget.destination) {
      // La pantalla fijó extremos nuevos (acción explícita del usuario): los
      // overrides de pin caducan y el auto-encuadre vuelve a estar activo.
      if (widget.origin != oldWidget.origin) _originOverride = null;
      if (widget.destination != oldWidget.destination) {
        _destinationOverride = null;
      }
      _userMovedCamera = false;
    }
    if (!identical(widget.option, oldWidget.option) &&
        widget.showJourneyLayers) {
      if (_userMovedCamera) {
        // El usuario ya movió la cámara por su cuenta: no hay que devolverla
        // al encuadre del viaje. Volverá a encuadrar cuando fije un extremo
        // nuevo.
        if (kDebugMode) {
          debugPrint(
            '[fit] opción cambió tras un gesto del usuario: '
            'no se re-encuadra',
          );
        }
      } else {
        _fitToOption();
      }
    }
  }

  /// Zoom + (lo usan los controles de la pantalla fusionada).
  void zoomIn() => _controller.zoomIn();

  /// Zoom − (lo usan los controles de la pantalla fusionada).
  void zoomOut() => _controller.zoomOut();

  void resetNorth() => _controller.resetNorth();

  /// Zoom actual (para decidir si el follow propio sube de nivel o conserva).
  double get currentZoom => _controller.camera.zoom;

  /// Recentra la cámara en [point] conservando el zoom (o el dado).
  ///
  /// Es el motor del seguimiento PROPIO: cada tick del stream de
  /// `LocationService` llega aquí; MapLibre nativo ya no manda nada.
  void moveTo(LatLng point, {double? zoom}) =>
      _controller.move(point, zoom ?? _controller.camera.zoom);

  /// Encuadra [points] (los extremos marcados) para que el pin recién fijado
  /// se VEA en el mapa.
  ///
  /// El `center` del mapa solo aplica al crearse, así que sin este encuadre
  /// un punto lejos del encuadre actual quedaba invisible ("no se
  /// reflejaba en el mapa"). Los puntos los decide la pantalla porque este
  /// estado lee sus flags en el ÚLTIMO build (todavía no actualizados si se
  /// llama justo después de un `setState`).
  Future<void> fitToPoints(List<LatLng> points) {
    if (points.isEmpty) return Future<void>.value();
    return _controller.fitBounds(
      points,
      padding: widget.fitPadding,
      maxZoom: 16,
    );
  }

  LatLng get _originPoint =>
      _originOverride ?? LatLng(widget.origin.lat, widget.origin.lon);

  LatLng get _destinationPoint =>
      _destinationOverride ??
      LatLng(widget.destination.lat, widget.destination.lon);

  void _handleMapReady() {
    if (_ready || !mounted) return;
    setState(() => _ready = true);
    widget.onMapReady?.call();
  }

  void _onMarkerMoved(String markerId, LatLng point) {
    // Diagnóstico temporal de arrastre (ver [drag] en la consola de `flutter run`).
    if (kDebugMode) {
      debugPrint(
        '[drag] resultMap $markerId → '
        '${point.latitude.toStringAsFixed(5)},'
        '${point.longitude.toStringAsFixed(5)}',
      );
    }
    switch (markerId) {
      case 'journey-map-origin':
        setState(() => _originOverride = point);
        widget.onOriginMoved?.call(point);
      case 'journey-map-destination':
        setState(() => _destinationOverride = point);
        widget.onDestinationMoved?.call(point);
      default:
        break;
    }
  }

  /// Cambio de cámara desde el motor: marca la cámara como "suya" ([_userMovedCamera])
  /// en cuanto el usuario la mueve por gesto, y reenvía a la pantalla.
  void _onMapCameraChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture && !_userMovedCamera) {
      _userMovedCamera = true;
      if (kDebugMode) {
        debugPrint(
          '[fit] el usuario movió la cámara: auto-encuadre desactivado',
        );
      }
    }
    widget.onPositionChanged?.call(camera, hasGesture);
  }

  /// Solo para tests: el motor falso no simula gestos de cámara (los eventos
  /// que emite son programáticos, `hasGesture: false`), así que la marca se
  /// fija directamente con la misma señal que usa [_onMapCameraChanged].
  @visibleForTesting
  void debugUserMovedCamera() => _userMovedCamera = true;

  /// Encuadra el viaje completo (botón "fit" y cambio de opción).
  void _fitToOption() {
    if (!widget.showJourneyLayers) return;
    final points = JourneyMapGeometry.fitPoints(
      widget.option,
      _originPoint,
      _destinationPoint,
    );
    if (points.length < 2) return;
    _controller.fitBounds(points, padding: widget.fitPadding, maxZoom: 16);
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final origin = _originPoint;
    final destination = _destinationPoint;
    final showJourney = widget.showJourneyLayers;
    final points = showJourney
        ? JourneyMapGeometry.fitPoints(option, origin, destination)
        : const <LatLng>[];

    return Stack(
      fit: StackFit.expand,
      children: [
        UrbanoMap(
          controller: _controller,
          center: origin,
          showTiles: widget.showTiles,
          cameraFit: showJourney && points.length >= 2
              ? MapCameraFit.bounds(
                  bounds: MapBounds.fromPoints(points),
                  padding: widget.fitPadding,
                  maxZoom: 16,
                )
              : null,
          onMapReady: _handleMapReady,
          onPositionChanged: _onMapCameraChanged,
          // Tanto durante el arrastre (`update`) como al soltarlo (`end`):
          // las coordenadas del campo deben ser DINÁMICAS, acordes al dedo.
          onMarkerDragUpdate: _onMarkerMoved,
          onMarkerDragEnd: _onMarkerMoved,
          myLocationEnabled: widget.myLocationEnabled,
          followMyLocation: widget.followMyLocation,
          onTrackingDismissed: widget.onTrackingDismissed,
          polylines: [
            if (showJourney)
              ...JourneyMapLayers.polylines(option, origin, destination),
            ...widget.extraPolylines,
          ],
          pulses: widget.extraPulses,
          markers: [
            ...JourneyMapLayers.endpoints(
              origin: origin,
              destination: destination,
              showOrigin: widget.showOrigin,
              showDestination: widget.showDestination,
              onOriginTap: widget.onOriginTap,
              onDestinationTap: widget.onDestinationTap,
            ),
            if (showJourney) ...JourneyMapLayers.routeBadges(option),
            if (showJourney) ...JourneyMapLayers.routeArrows(option),
            ...widget.extraMarkers,
          ],
        ),
        if (widget.showControls)
          Positioned(
            right: 8,
            bottom: showJourney && widget.showLegend ? 46 : 8,
            child: _MapControls(
              onZoomIn: _controller.zoomIn,
              onZoomOut: _controller.zoomOut,
              onFit: _ready && widget.showJourneyLayers ? _fitToOption : null,
            ),
          ),
        if (widget.showLegend && showJourney)
          Positioned(left: 8, bottom: 8, child: MapLegend(option)),
      ],
    );
  }
}
