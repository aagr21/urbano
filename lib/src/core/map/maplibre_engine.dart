import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'endpoint_drag_detector.dart';
import 'map_controller.dart';
import 'map_engine.dart';
import 'map_projection.dart';
import 'map_scene.dart';
import 'map_types.dart';
import 'marker_rasterizer.dart';

part 'maplibre_engine_helpers.dart';
part 'maplibre_engine_dash.dart';
part 'maplibre_engine_sync.dart';

/// Motor de mapa **real**: renderiza el [MapScene] con `maplibre_gl`.
///
/// Convierte cada elemento de la escena a los tipos nativos del plugin:
///
/// - polilíneas → `Line` (los tramos discontinuos se segmentan en
///   sub-líneas geográficas, porque `LineManager` no expone `line-dasharray`);
/// - marcadores → `Symbol` con icono PNG (el `child` del marcador se
///   rasteriza fuera de pantalla con [MarkerRasterizer] y se sube con
///   `addImage`, cacheado por `imageCacheKey`);
/// - cámara → `CameraUpdate` (el encuadre se calcula en Dart con
///   `MapProjection`, igual que el motor simulado).
///
/// Los listeners de arrastre/tap llegan por `onFeatureDrag`/`onSymbolTapped`
/// y se reenvían a la escena con la misma forma de callback que el motor
/// simulado, de modo que las pantallas no saben con qué motor corren.
class MapLibreEngine extends MapEngine {
  const MapLibreEngine({super.key, required super.scene, super.controller});

  @override
  State<MapLibreEngine> createState() => MapLibreEngineState();
}

class MapLibreEngineState extends State<MapLibreEngine>
    implements MapEngineHost {
  ml.MapLibreMapController? _map;

  MapCamera _camera = const MapCamera(center: LatLng(0, 0));
  Size _viewport = Size.zero;
  bool _cameraResolved = false;
  bool _readyFired = false;

  /// `true` mientras la cámara la mueve la app (no el usuario): así
  /// `onPositionChanged` puede reportar `hasGesture` igual que el simulado.
  bool _programmaticCamera = true;

  bool _styleLoaded = false;

  /// Se incrementa en cada carga de estilo: las sincronizaciones en vuelo de
  /// una generación anterior se descartan (los managers se recrean).
  int _styleGeneration = 0;

  /// Marcadores ya presentes en la escena (id → símbolo en el mapa).
  final Map<String, ml.Symbol> _symbols = <String, ml.Symbol>{};

  /// `imageCacheKey` con el que se creó cada símbolo (para reconstruirlo si
  /// cambia el aspecto del icono).
  final Map<String, String> _symbolImageKeys = <String, String>{};

  /// Último `point` de escena visto por marcador: si cambia, los overrides
  /// locales (drag/`moveMarker`) quedan obsoletos.
  final Map<String, LatLng> _sceneMarkerPoints = <String, LatLng>{};

  /// Posiciones forzadas (pin del selector pegado al centro, drags en curso).
  final Map<String, LatLng> _markerOverrides = <String, LatLng>{};

  /// Nombre de imagen en el estilo para cada `imageCacheKey`.
  final Map<String, String> _imageNames = <String, String>{};

  /// Imágenes ya añadidas al *estilo actual* (se limpian al recargar estilo).
  final Set<String> _imagesLoaded = <String>{};

  String? _lineSignature;

  bool _syncScheduled = false;
  bool _syncing = false;
  bool _syncQueued = false;

  // ------------------------------------------------------------------
  // Ciclo de vida
  // ------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _camera = MapCamera(center: widget.scene.center, zoom: widget.scene.zoom);
    widget.controller?.attach(this);
  }

  @override
  void didUpdateWidget(covariant MapLibreEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
    // CAMBIÓ el estilo (p. ej. claro↔oscuro al restaurar el modo de tema
    // guardado unos instantes después del arranque): el plugin va a llamar
    // `setStyleString` y el estilo NATIVO queda nulo/medio cargado hasta el
    // próximo `onStyleLoaded`. Hay que dejar de sincronizar hasta entonces,
    // o los `symbol#add`/`style#addImage`/`line#add` de `_syncAll` reventarían
    // con `PlatformException(STYLE_NOT_READY)` contra un estilo sin cargar.
    // `_onStyleLoaded` pondrá la bandera otra vez en `true` y re-encolará el
    // dibujo cuando el nuevo estilo esté listo.
    if (oldWidget.scene.styleString != widget.scene.styleString) {
      _styleLoaded = false;
    }
    _scheduleSync();
  }

  @override
  void dispose() {
    final map = _map;
    if (map != null) {
      map.onSymbolTapped.remove(_onSymbolTapped);
      map.onFeatureDrag.remove(_onFeatureDrag);
    }
    widget.controller?.detach(this);
    super.dispose();
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _map = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
    controller.onFeatureDrag.add(_onFeatureDrag);
    widget.controller?.attach(this);
    _scheduleSync();
  }

  void _onStyleLoaded() {
    _styleGeneration++;
    _styleLoaded = true;
    _imagesLoaded.clear();
    _symbols.clear();
    _symbolImageKeys.clear();
    _lineSignature = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Al arrancar la app no hay ningún movimiento programático en vuelo:
      // sin esto, el primer gesto del usuario se reportaría como no-gesto
      // (la bandera arranca en `true` para ignorar los eventos iniciales).
      if (mounted) _programmaticCamera = false;
      _fireReady();
    });
    _scheduleSync();
  }

  void _fireReady() {
    if (!mounted || _readyFired) return;
    _readyFired = true;
    widget.scene.onMapReady?.call();
  }

  // ------------------------------------------------------------------
  // Eventos nativos → escena
  // ------------------------------------------------------------------

  void _onMapClick(math.Point<double> _, ml.LatLng coords) =>
      widget.scene.onTap?.call(_toLatLng(coords));

  void _onCameraMove(ml.CameraPosition position) {
    final camera = MapCamera(
      center: _toLatLng(position.target),
      zoom: position.zoom,
    );
    _camera = camera;
    widget.scene.onPositionChanged?.call(camera, !_programmaticCamera);
  }

  void _onCameraIdle() => _programmaticCamera = false;

  void _onSymbolTapped(ml.Symbol symbol) {
    final marker = _markerById(symbol.id);
    if (marker == null) return;
    final onTap = marker.onTap;
    if (onTap != null) {
      onTap();
    } else {
      widget.scene.onMarkerTap?.call(symbol.id);
    }
  }

  void _onFeatureDrag(
    math.Point<double> point,
    ml.LatLng origin,
    ml.LatLng current,
    ml.LatLng delta,
    String id,
    ml.Annotation? annotation,
    ml.DragEventType type,
  ) {
    final scene = widget.scene;
    final position = _toLatLng(current);
    // Diagnóstico temporal de arrastre: si al arrastrar en el dispositivo NO
    // aparece ninguna línea `[drag] nativo`, el evento no sale del plugin.
    if (kDebugMode) {
      debugPrint(
        '[drag] nativo ${type.name} id=$id '
        'pos=${position.latitude.toStringAsFixed(5)},'
        '${position.longitude.toStringAsFixed(5)}',
      );
    }
    // Evita que un rebuild de la pantalla "regrese" el marcador a su punto
    // de escena mientras se arrastra (el replan tarda ~600 ms).
    _markerOverrides[id] = position;
    switch (type) {
      case ml.DragEventType.start:
        scene.onMarkerDragStart?.call(id, position);
      case ml.DragEventType.drag:
        scene.onMarkerDragUpdate?.call(id, position);
      case ml.DragEventType.end:
        scene.onMarkerDragEnd?.call(id, position);
    }
  }

  // ---------------------------------------------------------------------------
  // Arrastre/tap de pines en Dart (EndpointDragDetector)
  //
  // Camino alternativo al arrastre nativo de arriba: gana la arena de Flutter
  // cuando el toque empieza sobre un pin, así que en algunos dispositivos el
  // pin responde aunque `feature#onDrag` jamás se dispare. Ambos caminos
  // alimentan los MISMOS callbacks de escena, así que aguas abajo (escena →
  // pantalla → planner) no hay ninguna diferencia.
  // ---------------------------------------------------------------------------

  void _onDartDragStart(String id, LatLng position) {
    if (kDebugMode) {
      debugPrint(
        '[drag] dart start id=$id '
        'pos=${position.latitude.toStringAsFixed(5)},'
        '${position.longitude.toStringAsFixed(5)}',
      );
    }
    _markerOverrides[id] = position;
    widget.scene.onMarkerDragStart?.call(id, position);
  }

  void _onDartDragMove(String id, LatLng position) {
    if (kDebugMode) {
      debugPrint(
        '[drag] dart move id=$id '
        'pos=${position.latitude.toStringAsFixed(5)},'
        '${position.longitude.toStringAsFixed(5)}',
      );
    }
    _markerOverrides[id] = position;
    widget.scene.onMarkerDragUpdate?.call(id, position);
  }

  void _onDartDragEnd(String id, LatLng position) {
    if (kDebugMode) {
      debugPrint(
        '[drag] dart end id=$id '
        'pos=${position.latitude.toStringAsFixed(5)},'
        '${position.longitude.toStringAsFixed(5)}',
      );
    }
    _markerOverrides[id] = position;
    widget.scene.onMarkerDragEnd?.call(id, position);
  }

  void _onDartEndpointTap(String id) {
    if (kDebugMode) {
      debugPrint('[drag] dart tap id=$id');
    }
    // Misma semántica que el tap nativo del símbolo (_onSymbolTapped).
    final marker = _markerById(id);
    final onTap = marker?.onTap;
    if (onTap != null) {
      onTap();
    } else {
      widget.scene.onMarkerTap?.call(id);
    }
  }

  MapMarker? _markerById(String id) {
    for (final marker in widget.scene.markers) {
      if (marker.id == id) return marker;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // MapEngineHost
  // ------------------------------------------------------------------

  @override
  MapCamera get camera => _camera;

  @override
  Size? get viewportSize => _viewport == Size.zero ? null : _viewport;

  @override
  void moveCamera(LatLng center, double zoom, {bool animated = true}) {
    final scene = widget.scene;
    final clamped = zoom.clamp(scene.minZoom, scene.maxZoom).toDouble();
    if (_camera.center == center && (_camera.zoom - clamped).abs() < 1e-6) {
      return;
    }
    // Actualiza el espejo aunque la plataforma aún no exista: el controller
    // verá una cámara coherente desde el primer `move`.
    _camera = MapCamera(center: center, zoom: clamped);
    final map = _map;
    if (map == null) return;
    _programmaticCamera = true;
    final update = ml.CameraUpdate.newLatLngZoom(_toMl(center), clamped);
    if (animated) {
      unawaited(map.animateCamera(update));
    } else {
      unawaited(map.moveCamera(update));
    }
  }

  @override
  void zoomBy(double delta, {bool animated = true}) {
    final scene = widget.scene;
    final target = (_camera.zoom + delta)
        .clamp(scene.minZoom, scene.maxZoom)
        .toDouble();
    _camera = _camera.copyWith(zoom: target);
    final map = _map;
    if (map == null) return;
    _programmaticCamera = true;
    final update = ml.CameraUpdate.zoomBy(delta);
    if (animated) {
      unawaited(map.animateCamera(update));
    } else {
      unawaited(map.moveCamera(update));
    }
  }

  @override
  Future<void> fitBounds(
    Iterable<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(56),
    double maxZoom = 17,
    bool animated = true,
  }) async {
    final list = points.toList(growable: false);
    if (list.isEmpty) return;
    if (_viewport == Size.zero) {
      // Aún no se ha maquetado: espera un frame (máximo) a los constraints.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _viewport == Size.zero) return;
    }
    final scene = widget.scene;
    final camera = MapProjection.fitBounds(
      MapBounds.fromPoints(list),
      viewport: _viewport,
      padding: padding,
      minZoom: scene.minZoom,
      maxZoom: maxZoom,
    );
    moveCamera(camera.center, camera.zoom, animated: animated);
  }

  @override
  void moveMarker(String markerId, LatLng point) {
    // El override se registra aunque la plataforma aún no exista: la primera
    // sincronización coloca el marcador en ese punto.
    _markerOverrides[markerId] = point;
    // Sin estilo cargado (ventana de recarga) NO se toca el manager: el
    // `symbol#set` reventaría con `STYLE_NOT_READY`. El override ya quedó
    // guardado, así que `_syncMarkers` lo aplicará cuando el estilo vuelva.
    if (!_styleLoaded) return;
    final map = _map;
    final manager = map?.symbolManager;
    if (manager == null) return;
    final existing = manager.byId(markerId) ?? _symbols[markerId];
    if (existing == null) return;
    final updated = ml.Symbol(
      existing.id,
      existing.options.copyWith(ml.SymbolOptions(geometry: _toMl(point))),
    );
    _symbols[markerId] = updated;
    unawaited(manager.set(updated));
  }

  // ------------------------------------------------------------------
  // Construcción
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.width > 0 && size.height > 0) {
          _viewport = size;
          if (!_cameraResolved) {
            _cameraResolved = true;
            if (scene.cameraFit != null) {
              _camera = scene.cameraFor(size);
              _programmaticCamera = true;
            }
          }
        }

        final initial = _camera;
        // Pines arrastrables → capa de arrastre/tap en Dart. Si el toque
        // empieza sobre un pin, gana la arena de Flutter (la vista nativa no
        // recibe el toque: el mapa no se desplaza) y el pin sigue al dedo sin
        // depender de `feature#onDrag`, que en algunos dispositivos no llega.
        // El motor DELEGA el arrastre en la capa Dart: con `dragEnabled:
        // false` el plugin no instala su gesto de arrastre de anotaciones
        // (estándar pan/zoom del mapa no se toca). Con drag nativo activo,
        // cualquier toque que aterrizará sobre la cabeza del pin —aunque el
        // usuario solo quisiera desplazar/alejar el mapa— movía el pin SIN
        // compensar agarre y lo comprometía al soltar ("los marcadores se
        // van a otro lado sin tocarlos").
        const gripPadPx = 12.0;
        final endpoints = <DraggableEndpoint>[
          for (final marker in scene.markers)
            if (marker.draggable)
              (
                id: marker.id,
                point: _markerOverrides[marker.id] ?? marker.point,
                // Radio de respaldo: la cabeza del pin.
                hitRadiusPx: marker.height - marker.width / 2,
                // Forma del pin (ancla en la punta): cabeza circular
                // `w/2+xpx` de radio, centrada `h − w/2` arriba de la punta,
                // y cuello del ancho del pin hasta la punta.
                headRadiusPx: marker.width / 2 + gripPadPx,
                headCenterDy: marker.height - marker.width / 2,
                bodyWidthPx: marker.width,
              ),
        ];
        return EndpointDragDetector(
          // Getter VIVO: la cámara muta en cada frame del desplazamiento sin
          // pasar por build; leerla por evento es lo que hace que el arrastre
          // acierte al pin donde esté.
          camera: () => _camera,
          viewport: size,
          targets: endpoints,
          onDragStart: _onDartDragStart,
          onDragUpdate: _onDartDragMove,
          onDragEnd: _onDartDragEnd,
          onTap: _onDartEndpointTap,
          child: ml.MapLibreMap(
            styleString: scene.styleString,
            initialCameraPosition: ml.CameraPosition(
              target: _toMl(initial.center),
              zoom: initial.zoom,
            ),
            // CRÍTICO: sin esto el plugin NO reenvía `camera#onMove` a Dart
            // (el nativo hace `if (!trackCameraPosition) return`) y el motor
            // nunca se entera de los desplazamientos del usuario: se congelan
            // la lectura de coordenadas del selector y el punto que devuelve
            // `Usar este punto`. Con `true`, `onPositionChanged` llega en
            // caliente y `_camera` refleja la cámara real en todo momento.
            trackCameraPosition: true,
            // El arrastre de pines es 100% la capa Dart (arena de Flutter,
            // pellizco cancelado, agarre compensado): el nativo se apagó
            // porque movía los marcadores sin pasar por esa lógica.
            dragEnabled: false,
            minMaxZoomPreference: ml.MinMaxZoomPreference(
              scene.minZoom,
              scene.maxZoom,
            ),
            scrollGesturesEnabled: scene.interactive,
            zoomGesturesEnabled: scene.interactive,
            doubleClickZoomEnabled: scene.interactive,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            myLocationEnabled: scene.myLocationEnabled,
            myLocationTrackingMode: scene.followMyLocation
                ? ml.MyLocationTrackingMode.tracking
                : ml.MyLocationTrackingMode.none,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapClick: scene.onTap == null ? null : _onMapClick,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            onCameraTrackingDismissed: scene.onTrackingDismissed == null
                ? null
                : () => widget.scene.onTrackingDismissed?.call(),
          ),
        );
      },
    );
  }
}
