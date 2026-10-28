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
  // Sincronización escena → anotaciones nativas
  // ------------------------------------------------------------------

  void _scheduleSync() {
    if (_syncScheduled || !mounted) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      unawaited(_syncAll());
    });
  }

  Future<void> _syncAll() async {
    if (_syncing) {
      _syncQueued = true;
      return;
    }
    _syncing = true;
    try {
      while (true) {
        _syncQueued = false;
        final generation = _styleGeneration;
        if (_styleLoaded && _map != null) {
          await _syncLines(generation);
          await _syncMarkers(generation);
        }
        if (!_syncQueued || !mounted) break;
      }
    } on PlatformException catch (e) {
      // Defensa en profundidad contra la ventana de recarga de estilo: si un
      // `symbol#add`/`style#addImage`/`line#add` llega justo cuando el plugin
      // está swapping el estilo (p. ej. al aplicar el tema guardado tras el
      // primer frame), el nativo responde `STYLE_NOT_READY`. En vez de dejar
      // el error sin capturar (ruido en consola y dibujo perdido), marcamos
      // el estilo como no-cargado y dejamos que el próximo `onStyleLoaded`
      // re-sincronice todo. Cualquier otra `PlatformException` se propaga.
      if (e.code != 'STYLE_NOT_READY') rethrow;
      _styleLoaded = false;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncLines(int generation) async {
    final map = _map;
    final manager = map?.lineManager;
    if (manager == null) return;
    final signature = _linesSignature(widget.scene.polylines);
    if (signature == _lineSignature) return;

    await manager.clear();
    if (!mounted || generation != _styleGeneration) return;

    final lines = <ml.Line>[];
    var index = 0;
    ml.Line makeLine(
      List<LatLng> points,
      Color color,
      double width,
      double opacity,
    ) {
      final id = 'urbano-line-${index++}';
      return ml.Line(
        id,
        ml.LineOptions(
          geometry: [
            _toMl(points.first),
            for (final p in points.skip(1)) _toMl(p),
          ],
          lineColor: _hex(color),
          lineWidth: width,
          lineOpacity: opacity,
          lineJoin: 'round',
        ),
      );
    }

    for (final polyline in widget.scene.polylines) {
      if (polyline.points.length < 2) continue;
      if (polyline.dashed) {
        final segments = _dashSegments(polyline.points);
        if (polyline.outline) {
          for (final segment in segments) {
            lines.add(
              makeLine(
                segment,
                polyline.outlineColor,
                polyline.width + 4,
                polyline.opacity,
              ),
            );
          }
        }
        for (final segment in segments) {
          lines.add(
            makeLine(segment, polyline.color, polyline.width, polyline.opacity),
          );
        }
      } else {
        if (polyline.outline) {
          lines.add(
            makeLine(
              polyline.points,
              polyline.outlineColor,
              polyline.width + 4,
              polyline.opacity,
            ),
          );
        }
        lines.add(
          makeLine(
            polyline.points,
            polyline.color,
            polyline.width,
            polyline.opacity,
          ),
        );
      }
    }

    await manager.addAll(lines);
    if (!mounted || generation != _styleGeneration) return;
    _lineSignature = signature;
  }

  Future<void> _syncMarkers(int generation) async {
    final map = _map;
    final manager = map?.symbolManager;
    if (manager == null) return;
    final scene = widget.scene;

    // Los overrides locales solo valen mientras la pantalla no cambie el
    // `point` del marcador: si lo cambia, el punto de escena manda.
    for (final marker in scene.markers) {
      final seen = _sceneMarkerPoints[marker.id];
      if (seen == null || seen != marker.point) {
        _markerOverrides.remove(marker.id);
      }
      _sceneMarkerPoints[marker.id] = marker.point;
    }

    // Quita los símbolos de marcadores que ya no están en la escena.
    final liveIds = scene.markers.map((m) => m.id).toSet();
    final staleIds = _symbols.keys
        .where((id) => !liveIds.contains(id))
        .toList();
    for (final id in staleIds) {
      final symbol = _symbols.remove(id);
      _symbolImageKeys.remove(id);
      _sceneMarkerPoints.remove(id);
      _markerOverrides.remove(id);
      if (symbol != null) {
        await manager.remove(symbol);
        if (!mounted || generation != _styleGeneration) return;
      }
    }

    for (final marker in scene.markers) {
      final point = _markerOverrides[marker.id] ?? marker.point;
      final imageName = await _ensureImage(marker, generation);
      if (!mounted || generation != _styleGeneration) return;
      if (imageName == null) continue;

      final existing = _symbols[marker.id];
      final anchor = _anchorOf(marker);
      final needsRebuild =
          existing == null ||
          _symbolImageKeys[marker.id] != marker.imageCacheKey ||
          existing.options.iconAnchor != anchor ||
          existing.options.draggable != marker.draggable;

      if (needsRebuild) {
        if (existing != null) {
          await manager.remove(existing);
          if (!mounted || generation != _styleGeneration) return;
        }
        final symbol = ml.Symbol(
          marker.id,
          ml.SymbolOptions(
            geometry: _toMl(point),
            iconImage: imageName,
            iconAnchor: anchor,
            draggable: marker.draggable,
          ),
        );
        await manager.add(symbol);
        if (!mounted || generation != _styleGeneration) return;
        _symbols[marker.id] = symbol;
        _symbolImageKeys[marker.id] = marker.imageCacheKey;
        if (kDebugMode && marker.draggable) {
          debugPrint('[drag] símbolo arrastrable creado: ${marker.id}');
        }
      } else if (existing.options.geometry?.toLatLong() != point) {
        final updated = ml.Symbol(
          existing.id,
          existing.options.copyWith(ml.SymbolOptions(geometry: _toMl(point))),
        );
        await manager.set(updated);
        if (!mounted || generation != _styleGeneration) return;
        _symbols[marker.id] = updated;
      }
    }
  }

  /// Asegura que el icono PNG del marcador exista en el estilo actual.
  Future<String?> _ensureImage(MapMarker marker, int generation) async {
    final key = marker.imageCacheKey;
    final name = _imageNames[key] ??= 'urbano-marker-${_imageNames.length}';
    if (_imagesLoaded.contains(name)) return name;

    var bytes = await MarkerRasterizer.rasterize(
      context,
      marker,
      pixelRatio: _markerPixelRatio(),
    );
    bytes ??= await MarkerRasterizer.fallbackMarker(
      width: marker.width,
      height: marker.height,
    );
    if (!mounted || generation != _styleGeneration) return null;
    final map = _map;
    if (map == null) return null;
    await map.addImage(name, bytes);
    if (!mounted || generation != _styleGeneration) return null;
    _imagesLoaded.add(name);
    return name;
  }

  /// Densidad con la que rasterizar los iconos.
  ///
  /// - **Web**: el plugin registra las imágenes con `pixelRatio: 1`, así que
  ///   el PNG debe medir exactamente el tamaño lógico del marcador.
  /// - **iOS/Android**: el PNG se sube como píxeles crudos y MapLibre los
  ///   dibuja a tamaño de pantalla, así que hay que rasterizar a la densidad
  ///   del dispositivo.
  double _markerPixelRatio() {
    if (kIsWeb) return 1;
    final ratio = MediaQuery.maybeOf(context)?.devicePixelRatio;
    if (ratio == null || !ratio.isFinite || ratio <= 0) return 3;
    return ratio.clamp(1.0, 4.0).toDouble();
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

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

/// `latlong2.LatLng` → `maplibre_gl.LatLng`.
ml.LatLng _toMl(LatLng point) => ml.LatLng(point.latitude, point.longitude);

/// `maplibre_gl.LatLng` → `latlong2.LatLng`.
LatLng _toLatLng(ml.LatLng point) => LatLng(point.latitude, point.longitude);

extension on ml.LatLng {
  LatLng toLatLong() => LatLng(latitude, longitude);
}

/// Firma estable de la lista de polilíneas (para detectar cambios).
String _linesSignature(List<MapPolyline> polylines) {
  final buffer = StringBuffer();
  for (final line in polylines) {
    buffer
      ..write(_hex(line.color))
      ..write('|')
      ..write(line.width)
      ..write('|')
      ..write(line.opacity)
      ..write('|')
      ..write(line.outline)
      ..write(_hex(line.outlineColor))
      ..write('|')
      ..write(line.dashed)
      ..write('|');
    for (final point in line.points) {
      buffer
        ..write(point.latitude.toStringAsFixed(6))
        ..write(',')
        ..write(point.longitude.toStringAsFixed(6))
        ..write(';');
    }
    buffer.writeln();
  }
  return buffer.toString();
}

/// `Color` → `#RRGGBB` (formato que espera `LineOptions.lineColor`).
String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _anchorOf(MapMarker marker) => switch (marker.anchor) {
  MapMarkerAnchor.center => 'center',
  MapMarkerAnchor.top => 'top',
  MapMarkerAnchor.bottom => 'bottom',
};

// ---------------------------------------------------------------------------
// Trazos discontinuos (segmentación geográfica)
// ---------------------------------------------------------------------------

const double _dashOnMeters = 14;
const double _dashOffMeters = 11;
const double _dashStepMeters = 3;

/// Divide [points] en tramos "pintado" (~14 m) y "hueco" (~11 m) siguiendo la
/// geometría real, para pintarlos como varias `Line` (MapLibre no expone
/// `line-dasharray` por anotación).
List<List<LatLng>> _dashSegments(List<LatLng> points) {
  final path = _resample(points, _dashStepMeters);
  if (path.length < 2) return [points];

  final segments = <List<LatLng>>[];
  var current = <LatLng>[path.first];
  var remaining = _dashOnMeters;
  var drawing = true;

  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1];
    final b = path[i];
    final total = _haversineMeters(a, b);
    if (total <= 0) continue;
    var position = 0.0;
    while (position < total) {
      final take = math.min(total - position, remaining);
      final start = _lerp(a, b, position / total);
      final end = _lerp(a, b, (position + take) / total);
      if (drawing) {
        if (current.isEmpty || _haversineMeters(current.last, start) > 0.5) {
          current.add(start);
        }
        current.add(end);
      }
      position += take;
      remaining -= take;
      if (remaining <= 1e-9) {
        if (drawing && current.length >= 2) segments.add(current);
        current = <LatLng>[end];
        drawing = !drawing;
        remaining = drawing ? _dashOnMeters : _dashOffMeters;
      }
    }
  }
  if (drawing && current.length >= 2) segments.add(current);
  return segments;
}

/// Remuestrea la polilínea cada [stepMeters] metros manteniendo la forma.
List<LatLng> _resample(List<LatLng> points, double stepMeters) {
  if (points.length < 2) return List.of(points);
  final out = <LatLng>[points.first];
  var carry = 0.0;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final segment = _haversineMeters(a, b);
    if (segment <= 0) continue;
    var fromA = carry;
    while (fromA + stepMeters <= segment) {
      fromA += stepMeters;
      out.add(_lerp(a, b, fromA / segment));
    }
    carry = segment - fromA;
  }
  out.add(points.last);
  return out;
}

double _haversineMeters(LatLng a, LatLng b) {
  const radius = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * radius * math.asin(math.min(1, math.sqrt(h)));
}

LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
  a.latitude + (b.latitude - a.latitude) * t,
  a.longitude + (b.longitude - a.longitude) * t,
);
