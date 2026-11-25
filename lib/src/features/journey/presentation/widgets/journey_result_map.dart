import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/map/map.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/urbano_map.dart';
import '../../data/journey_models.dart';
import '../../data/journey_repository.dart';
import '../journey_markers.dart';
import './journey_option_card.dart';

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
  static const _endpointPinSize = 40.0;

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
    final points = _allPoints(widget.option, _originPoint, _destinationPoint);
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
        ? _allPoints(option, origin, destination)
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
            if (showJourney) ..._buildPolylines(option, origin, destination),
            ...widget.extraPolylines,
          ],
          pulses: widget.extraPulses,
          markers: [
            ..._endpointMarkers(origin, destination),
            if (showJourney) ..._journeyMarkers(option),
            if (showJourney)
              ..._buildRouteArrows(
                option,
                JourneyOptionCard.alternativeRouteColorsForLegs(option.legs),
              ),
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

  static List<LatLng> _allPoints(
    JourneyOption option,
    LatLng origin,
    LatLng destination,
  ) {
    final points = <LatLng>[origin, destination];
    void add(LatLng? point) {
      if (point != null) points.add(point);
    }

    add(option.walkToStop?.position);
    add(option.walkFromStop?.position);
    for (final stop in option.stopRefs) {
      add(stop.position);
    }
    for (final leg in option.legs) {
      final path = leg.mapPoints;
      if (path != null) points.addAll(path);
    }
    return points;
  }

  static List<MapPolyline> _buildPolylines(
    JourneyOption option,
    LatLng origin,
    LatLng destination,
  ) {
    final polylines = <MapPolyline>[];

    // Cada tramo de micro con un color distinto de los demás y del gris de la
    // caminata (`alternativeRouteColorsForLegs`): dos líneas del mismo color
    // —o de colores muy parecidos— ya no se confunden en un transbordo.
    final legAltColors = JourneyOptionCard.alternativeRouteColorsForLegs(
      option.legs,
    );

    // Tramos de caminata: geometría trazada por la red viaria (motor OTP)
    // cuando existe; si no, línea recta entre extremos conocidos (fallback,
    // y único modo cuando el backend usa el planner interno sin OTP). En
    // ambos casos el extremo que toca el micro se pega a su trazado
    // (`_joinWalkToBus`).
    const walkColor = JourneyOptionCard.walkStrokeColor;
    final walkLegs = option.walkLegs;
    if (walkLegs.isEmpty) {
      // Compatibilidad: opciones sin tramos de caminata explícitos.
      final walkTo = option.walkToStop?.position;
      if (walkTo != null) {
        polylines.add(
          MapPolyline(
            points: _joinWalkToBus([origin, walkTo], option.legs, -1),
            width: 4,
            color: walkColor,
            dashed: true,
          ),
        );
      }
      final walkFrom = option.walkFromStop?.position;
      if (walkFrom != null) {
        polylines.add(
          MapPolyline(
            points: _joinWalkToBus(
              [walkFrom, destination],
              option.legs,
              option.legs.length,
            ),
            width: 4,
            color: walkColor,
            dashed: true,
          ),
        );
      }
    } else {
      final legs = option.legs;
      for (var i = 0; i < legs.length; i++) {
        final leg = legs[i];
        if (!leg.isWalk) continue;
        final geometry = leg.geometry;
        final base = (geometry != null && geometry.length >= 2)
            ? geometry
            : _straightWalkSegment(option, legs, i, origin, destination);
        if (base == null || base.length < 2) continue;
        polylines.add(
          MapPolyline(
            points: _joinWalkToBus(base, legs, i),
            width: 4,
            color: walkColor,
            dashed: true,
          ),
        );
      }
    }

    // Transbordo sin tramo a pie entre dos micros: el trazado del primero
    // acaba en SU calzada y el del segundo empieza en la suya (cada `shape` se
    // recorta proyectando la parada sobre su propia línea), así que entre
    // ambos quedaba un hueco sin dibujar. Se pinta como caminata: es lo que
    // hace el pasajero para cambiar de micro.
    for (final connector in transferConnectors(option.legs)) {
      polylines.add(
        MapPolyline(
          points: connector,
          width: 4,
          color: walkColor,
          dashed: true,
        ),
      );
    }

    // Tramos de micro: `mapPoints` ya los entrega en el sentido del propio
    // tramo (fromStop → toStop). No se comparan con el origen/destino del
    // usuario: el segundo micro de un transbordo está más cerca del destino y
    // aun así debe dibujarse hacia delante.
    for (final leg in option.busLegs) {
      final path = leg.mapPoints;
      if (path == null || path.isEmpty) continue;
      final legIndex = option.legs.indexOf(leg);
      polylines.add(
        MapPolyline(
          points: path,
          width: 6,
          color: busLegStrokeColor(legAltColors[legIndex] ?? leg.routeColor),
          outline: true,
        ),
      );
    }
    return polylines;
  }

  /// Distancia (m) por debajo de la cual el fin de un micro y el inicio del
  /// siguiente se consideran el mismo punto (no hay hueco que dibujar).
  static const double _transferGapMinMeters = 1;

  /// Caminatas implícitas de los transbordos: para cada par de micros
  /// CONSECUTIVOS sin un tramo a pie explícito entre ellos, la línea
  /// fin-del-primero → parada de transbordo → inicio-del-segundo. Si ya hay
  /// una caminata entre ambos, la dibuja ella y aquí no se añade nada.
  @visibleForTesting
  static List<List<LatLng>> transferConnectors(List<JourneyLeg> legs) {
    const distance = Distance();
    final connectors = <List<LatLng>>[];
    JourneyLeg? prevBus;
    for (final leg in legs) {
      if (leg.isWalk) {
        prevBus = null;
        continue;
      }
      if (!leg.isBus) continue;
      final previous = prevBus;
      prevBus = leg;
      if (previous == null) continue;

      final end = previous.mapPoints?.last ?? previous.toStop?.position;
      final start = leg.mapPoints?.first ?? leg.fromStop?.position;
      if (end == null || start == null) continue;
      final stop = previous.toStop?.position ?? leg.fromStop?.position;
      final points = <LatLng>[end];
      if (stop != null &&
          distance(stop, end) >= _transferGapMinMeters &&
          distance(stop, start) >= _transferGapMinMeters) {
        points.add(stop);
      }
      points.add(start);
      if (points.length == 2 && distance(end, start) < _transferGapMinMeters) {
        continue;
      }
      connectors.add(points);
    }
    return connectors;
  }

  /// Separación máxima (m) entre el extremo de una caminata y el trazado del
  /// micro para coserlos. Más allá, el hueco es real y no se inventa un salto.
  static const double _walkJoinMaxMeters = 60;

  /// Estira la caminata hasta el trazado del micro vecino.
  ///
  /// El `shape` de GTFS circula por el eje de la calzada y la parada está en
  /// la acera: en una avenida de doble calzada quedan 10-20 m entre el final
  /// de la caminata y el dibujo del micro, y se lee como "me hace cruzar la
  /// avenida" o "la caminata no llega hasta donde pasa el micro". El trazado
  /// del micro **no se mueve** (es la verdad de por dónde pasa); lo que se
  /// estira es la caminata: su último punto pasa a ser el primero del micro
  /// siguiente y el primero, el último del micro anterior.
  ///
  /// [index] es la posición de la caminata en [legs]; `-1` y `legs.length`
  /// sirven para las caminatas de compatibilidad (sin tramo explícito).
  static List<LatLng> _joinWalkToBus(
    List<LatLng> points,
    List<JourneyLeg> legs,
    int index,
  ) {
    if (points.length < 2) return points;
    final joined = List<LatLng>.of(points);
    const distance = Distance();

    for (var j = index + 1; j < legs.length; j++) {
      if (!legs[j].isBus) continue;
      final start = legs[j].mapPoints?.first;
      if (start != null && distance(joined.last, start) <= _walkJoinMaxMeters) {
        joined[joined.length - 1] = start;
      }
      break;
    }
    for (var j = index - 1; j >= 0; j--) {
      if (!legs[j].isBus) continue;
      final end = legs[j].mapPoints?.last;
      if (end != null && distance(joined.first, end) <= _walkJoinMaxMeters) {
        joined[0] = end;
      }
      break;
    }
    return joined;
  }

  /// Extremos de una caminata sin geometría:
  /// - acceso (antes del primer micro): pin origen → parada de subida.
  /// - egreso (después del último micro): parada de bajada → pin destino.
  /// - transferencia a pie: parada de bajada del micro anterior → subida del
  ///   siguiente (si ambos la reportan).
  static List<LatLng>? _straightWalkSegment(
    JourneyOption option,
    List<JourneyLeg> legs,
    int index,
    LatLng origin,
    LatLng destination,
  ) {
    final leg = legs[index];
    JourneyLeg? prevBus;
    for (var j = index - 1; j >= 0; j--) {
      if (legs[j].isBus) {
        prevBus = legs[j];
        break;
      }
    }
    JourneyLeg? nextBus;
    for (var j = index + 1; j < legs.length; j++) {
      if (legs[j].isBus) {
        nextBus = legs[j];
        break;
      }
    }

    final LatLng? start;
    final LatLng? end;
    if (prevBus == null) {
      // Access: pin de origen → parada de embarque.
      start = origin;
      end =
          nextBus?.fromStop?.position ??
          option.walkToStop?.position ??
          leg.toStop?.position;
    } else if (nextBus == null) {
      // Egreso: parada de bajada → pin de destino.
      start =
          prevBus.toStop?.position ??
          option.walkFromStop?.position ??
          leg.fromStop?.position;
      end = destination;
    } else {
      // Transferencia a pie entre paradas de micro. Sin coordenadas de las
      // paradas se usan los extremos de los trazados: el transbordo nunca se
      // queda como un hueco vacío entre los dos micros.
      start =
          prevBus.toStop?.position ??
          leg.fromStop?.position ??
          prevBus.mapPoints?.last;
      end =
          nextBus.fromStop?.position ??
          leg.toStop?.position ??
          nextBus.mapPoints?.first;
    }
    if (start == null || end == null) return null;
    return [start, end];
  }

  /// Pines de origen/destino (fijos y tocables). Se pintan aunque no
  /// haya resultados de viaje: si el usuario ya fijó un extremo, debe verse
  /// reflejado en el mapa.
  List<MapMarker> _endpointMarkers(LatLng origin, LatLng destination) => [
    if (widget.showOrigin)
      MapMarker(
        id: 'journey-map-origin',
        point: origin,
        width: EndpointMarker.widthFor(_endpointPinSize),
        height: EndpointMarker.heightFor(_endpointPinSize),
        anchor: MapMarkerAnchor.bottom,
        onTap: widget.onOriginTap,
        child: EndpointMarker(
          key: const ValueKey('journey-map-origin'),
          color: AppColors.success,
          onTap: widget.onOriginTap,
        ),
      ),
    if (widget.showDestination)
      MapMarker(
        id: 'journey-map-destination',
        point: destination,
        width: EndpointMarker.widthFor(_endpointPinSize),
        height: EndpointMarker.heightFor(_endpointPinSize),
        anchor: MapMarkerAnchor.bottom,
        onTap: widget.onDestinationTap,
        child: EndpointMarker(
          key: const ValueKey('journey-map-destination'),
          color: AppColors.danger,
          onTap: widget.onDestinationTap,
        ),
      ),
  ];

  /// Insignias de ruta del viaje (una por micro sobre el punto medio de su
  /// tramo): solo cuando hay resultados que mostrar.
  List<MapMarker> _journeyMarkers(JourneyOption option) {
    final busLegs = option.busLegs;
    final markers = <MapMarker>[];

    // Colores alternativos para distinguir líneas con el mismo color GTFS
    // cuando hay transbordo entre ellas (insignias en el mapa).
    final legAltColors = JourneyOptionCard.alternativeRouteColorsForLegs(
      option.legs,
    );

    // Insignia de cada micro sobre el punto medio de su tramo: dice qué
    // ruta es con el color de su propia línea (identidad = shortName).
    for (var i = 0; i < busLegs.length; i++) {
      final leg = busLegs[i];
      final path = leg.mapPoints;
      final name = leg.routeShortName;
      if (path == null || path.isEmpty || name == null || name.isEmpty) {
        continue;
      }
      final legIndex = option.legs.indexOf(leg);
      final colorHex = legAltColors[legIndex] ?? leg.routeColor;
      final color = AppColors.fromHex(colorHex);
      final label = name.trim();
      markers.add(
        MapMarker(
          id: 'journey-map-route-$i',
          point: routePathMidpoint(path),
          // La insignia debe medir distinto por ruta para no compartir
          // caché con un badge de otro color/texto.
          width: routeBadgeWidth(label),
          height: routeBadgeHeight,
          iconKey: 'route-badge-${leg.routeId ?? label}-$label-$colorHex',
          child: MapRouteBadge(
            key: ValueKey('journey-map-route-$i'),
            label: label,
            color: color,
          ),
        ),
      );
    }
    return markers;
  }

  /// Flechas de sentido a lo largo de cada tramo de micro (una cada 200 m,
  /// el espaciado por defecto de [routeArrowMarkers]). La geometría (reparto y rumbo) es pura y vive en
  /// `domain/route_arrows.dart`; aquí solo se pinta, en el color de la línea
  /// (o el alternativo del transbordo) para que se lea sobre ella.
  static List<MapMarker> _buildRouteArrows(
    JourneyOption option,
    Map<int, String> legAltColors,
  ) {
    final markers = <MapMarker>[];
    for (final leg in option.busLegs) {
      final path = leg.mapPoints;
      if (path == null || path.length < 2) continue;
      final legIndex = option.legs.indexOf(leg);
      // MISMO color que el trazo del tramo: la flecha es parte de la línea.
      final color = busLegStrokeColor(legAltColors[legIndex] ?? leg.routeColor);
      markers.addAll(
        routeArrowMarkers(
          idPrefix: 'journey-map-arrow-$legIndex',
          path: path,
          color: color,
        ),
      );
    }
    return markers;
  }

  /// Color del trazo de un tramo de micro (GTFS o alternativo). Lo usan la
  /// polilínea y sus flechas de sentido: una sola fuente para que nunca
  /// diverjan.
  ///
  /// OPACO a propósito: el motor nativo descarta el alfa del color de una
  /// línea (`_hex`), así que un trazo «al 92 %» se pintaba opaco mientras la
  /// flecha rasterizada sí quedaba translúcida, y su punta se veía de otro
  /// tono donde sobresale del trazo.
  @visibleForTesting
  static Color busLegStrokeColor(String? hex) => AppColors.fromHex(hex);

  /// Clave de la imagen de una flecha: depende SOLO de su color (todas las
  /// flechas del mismo trazo comparten una imagen nativa).
  @visibleForTesting
  static String arrowIconKey(Color color) => routeArrowIconKey(color);
}
