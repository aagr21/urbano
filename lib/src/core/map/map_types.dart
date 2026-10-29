import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Tipos compartidos del mapa de Urbano.
///
/// Son **independientes del motor**: `flutter_map` desapareció y estos tipos
/// describen qué dibujar (líneas, marcadores, cámara) para que la fachada
/// pueda renderizarlos con `maplibre_gl` (motor real) o con el motor simulado
/// (tests / sin plataforma ni red). `latlong2.LatLng` sigue siendo el tipo de
/// coordenadas en toda la app (modelos y tests no cambian).

/// Anclaje del marcador respecto a su punto geográfico.
enum MapMarkerAnchor {
  /// El centro del icono queda sobre el punto (default).
  center,

  /// La punta superior del icono toca el punto (chinchetas hacia abajo no).
  top,

  /// La base inferior del icono toca el punto (pinos con punta abajo).
  bottom,
}

/// Fase de un arrastre de marcador.
enum MapMarkerDragPhase { start, move, end }

/// Cámara (posición de la vista) del mapa.
@immutable
class MapCamera {
  const MapCamera({required this.center, this.zoom = 13});

  final LatLng center;
  final double zoom;

  MapCamera copyWith({LatLng? center, double? zoom}) =>
      MapCamera(center: center ?? this.center, zoom: zoom ?? this.zoom);

  @override
  bool operator ==(Object other) =>
      other is MapCamera && other.center == center && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(center, zoom);

  @override
  String toString() => 'MapCamera(center: $center, zoom: $zoom)';
}

/// Rectángulo geográfico (esquinas opuestas).
@immutable
class MapBounds {
  const MapBounds({required this.southwest, required this.northeast});

  /// Envuelve todos los [points]. Falla si la lista está vacía.
  factory MapBounds.fromPoints(Iterable<LatLng> points) {
    final iterator = points.iterator;
    if (!iterator.moveNext()) {
      throw ArgumentError.value(points, 'points', 'no puede estar vacío');
    }
    var south = iterator.current.latitude;
    var north = south;
    var west = iterator.current.longitude;
    var east = west;
    while (iterator.moveNext()) {
      final point = iterator.current;
      south = south < point.latitude ? south : point.latitude;
      north = north > point.latitude ? north : point.latitude;
      west = west < point.longitude ? west : point.longitude;
      east = east > point.longitude ? east : point.longitude;
    }
    return MapBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  final LatLng southwest;
  final LatLng northeast;

  /// Centro geográfico del rectángulo.
  LatLng get center => LatLng(
    (southwest.latitude + northeast.latitude) / 2,
    (southwest.longitude + northeast.longitude) / 2,
  );

  /// Todos los puntos extremos (para encuadre).
  List<LatLng> get corners => [southwest, northeast];

  @override
  bool operator ==(Object other) =>
      other is MapBounds &&
      other.southwest == southwest &&
      other.northeast == northeast;

  @override
  int get hashCode => Object.hash(southwest, northeast);
}

/// Encuadre inicial/programático de la cámara sobre un rectángulo.
@immutable
class MapCameraFit {
  const MapCameraFit.bounds({
    required this.bounds,
    this.padding = EdgeInsets.zero,
    this.maxZoom = 17,
  }) : assert(maxZoom > 0);

  final MapBounds bounds;

  /// Hueco respecto a los bordes del mapa (p. ej. para barras flotantes).
  final EdgeInsets padding;

  /// Zoom máximo al encuadrar (evita acercarse de más en tramos cortos).
  final double maxZoom;
}

/// Línea (polilínea) a dibujar en el mapa.
@immutable
class MapPolyline {
  const MapPolyline({
    required this.points,
    required this.color,
    this.width = 5,
    this.opacity = 1,
    this.outline = false,
    this.outlineColor = Colors.white,
    this.dashed = false,
  });

  /// Geometría (sigue siendo `latlong2.LatLng`, igual que los modelos).
  final List<LatLng> points;

  /// Color del trazo (hex GTFS ya convertido a [Color]).
  final Color color;

  /// Grosor en logical pixels.
  final double width;

  /// Opacidad del trazo (0–1).
  final double opacity;

  /// Dibuja un borde detrás del trazo (efecto "contorno" de flutter_map).
  final bool outline;
  final Color outlineColor;

  /// Trazo punteado (tramos de caminata). El motor lo segmenta en el real
  /// y lo pinta discontinuo en el simulado.
  final bool dashed;

  MapPolyline copyWith({
    List<LatLng>? points,
    Color? color,
    double? width,
    double? opacity,
    bool? outline,
    Color? outlineColor,
    bool? dashed,
  }) => MapPolyline(
    points: points ?? this.points,
    color: color ?? this.color,
    width: width ?? this.width,
    opacity: opacity ?? this.opacity,
    outline: outline ?? this.outline,
    outlineColor: outlineColor ?? this.outlineColor,
    dashed: dashed ?? this.dashed,
  );
}

/// Marcador (icono) anclado a un punto geográfico.
///
/// [child] se pinta tal cual en el motor simulado; el motor MapLibre lo
/// rasteriza a PNG (RepaintBoundary → `addImage`) para mostrarlo como símbolo
/// nativo. Si el icono cambia de aspecto sin cambiar de [id], actualiza
/// [iconKey] para que la caché de imágenes se invalide.
@immutable
class MapMarker {
  const MapMarker({
    required this.id,
    required this.point,
    required this.child,
    this.width = 40,
    this.height = 40,
    this.anchor = MapMarkerAnchor.center,
    this.draggable = false,
    this.iconKey,
    this.onTap,
  });

  /// Identificador estable: es el que viajan en los callbacks de drag/tap.
  final String id;

  final LatLng point;
  final Widget child;
  final double width;
  final double height;
  final MapMarkerAnchor anchor;

  /// `true` para poder arrastrarlo: la capa `EndpointDragDetector` (Dart) y,
  /// en paralelo, el gesto nativo de MapLibre si el dispositivo lo dispara.
  final bool draggable;

  /// Clave de caché del icono rasterizado (por defecto, [id]).
  final String? iconKey;

  /// Tocado (solo el motor MapLibre lo emite; el simulado usa el
  /// GestureDetector interno de [child]).
  final VoidCallback? onTap;

  /// Clave usada para cachear el PNG del icono.
  String get imageCacheKey =>
      '${child.runtimeType}|${iconKey ?? id}|${width}x$height';
}

/// Aura pulsante de «mi ubicación» (el halo azul de Google Maps).
///
/// Va APARTE de [MapMarker] a propósito: en el motor real los marcadores
/// Dart se rasterizan a PNG estático con [MarkerRasterizer] (el aura, por
/// ser animada, se congelaría), así que cada motor la implementa en su capa
/// de bajo costo: `CircleManager` nativo en MapLibre y `CustomPainter` en el
/// simulado. El punto central SIEMPRE va por marcador, el aura por pulsos.
///
/// Una vuelta del aura dura `Motion.ambient` (2,4 s), el mismo latido que
/// usan los demás aires de la app: los dos motores leen ese valor, así que el
/// halo respira igual con mapa simulado y con MapLibre.
@immutable
class MapPulse {
  const MapPulse({
    required this.point,
    required this.color,
    this.baseRadius = 14,
    this.maxRadius = 54,
  });

  final LatLng point;
  final Color color;

  /// Radio (px de pantalla) donde nace cada onda: arranca ya fuera del punto
  /// central para que el halo se vea desde el primer frame.
  final double baseRadius;

  /// Radio (px) donde la onda muere (opacidad 0).
  final double maxRadius;
}

/// Punto tocado en el mapa.
typedef MapTapCallback = void Function(LatLng point);

/// Cambio de cámara. `hasGesture` es `true` cuando lo movió el usuario.
typedef MapPositionChangedCallback = void Function(
  MapCamera camera,
  bool hasGesture,
);

/// Evento de marcador (drag) con su id y nueva posición.
typedef MapMarkerCallback = void Function(String markerId, LatLng point);

/// Marcador tocado.
typedef MapMarkerTapCallback = void Function(String markerId);
