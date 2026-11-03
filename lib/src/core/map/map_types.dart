import 'dart:math' as math;

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

/// Aura pulsante de «mi ubicación»: ondas concéntricas que **respiran** desde
/// el punto (el latido del puck de ubicación).
///
/// Tres cosas, en este orden:
///
/// 1. Un **halo difuso** permanente bajo las ondas que se abre y se cierra
///    suavemente ([pulseBreath]): es lo que hace que el punto se sienta
///    «encendido» incluso cuando ninguna onda está en su pico.
/// 2. Tres **ondas** desfasadas un tercio de vuelta ([MapPulse.waves]), cada
///    una con su brillo propio ([pulseWaveGlow]): entra sin golpe, sostiene un
///    instante y se disuelve. Nunca hay un salto de opacidad entre vueltas
///    (el latido anterior reaparecía de golpe a plena opacidad).
/// 3. El anillo **flota hacia fuera** mientras se apaga ([pulseWaveGrowth]):
///    unos píxeles, lo justo para leerse como algo que se expande. No es un
///    anillo de diana que cruza el mapa: el aura entera cabe entre
///    [MapPulse.baseRadius] y `maxRadius + growth`.
///
/// Va APARTE de [MapMarker] a propósito: en el motor real los marcadores
/// Dart se rasterizan a PNG estático con [MarkerRasterizer] (el aura, por
/// ser animada, se congelaría), así que cada motor la implementa en su capa
/// de bajo costo: `CircleManager` nativo en MapLibre y `CustomPainter` en el
/// simulado. El punto central SIEMPRE va por marcador, el aura por pulsos.
///
/// El aro manda sobre el relleno: un disco difuso se perdía sobre la
/// cartografía (sobre todo en modo oscuro), así que cada onda es un trazo
/// nítido con un relleno tenue que solo le da cuerpo.
///
/// Una vuelta dura [MapPulse.period] (2,8 s: más lenta que antes, el aura es
/// vida de fondo y no una alerta) y las curvas viven aquí, así que el halo se
/// mueve EXACTAMENTE igual con el mapa simulado y con MapLibre.
@immutable
class MapPulse {
  const MapPulse({
    required this.point,
    required this.color,
    this.baseRadius = 14,
    this.maxRadius = 21,
  });

  /// Duración de UNA vuelta completa del latido.
  ///
  /// Más lenta que `Motion.ambient` a propósito: con 2,4 s el aura «corría» y
  /// competía con el mapa; así respira.
  static const Duration period = Duration(milliseconds: 2800);

  /// Ondas simultáneas. Con tres siempre hay una naciendo, una en su punto
  /// más vivo y una apagándose.
  static const int waves = 3;

  /// Cuánto flota hacia fuera cada anillo (px lógicos) mientras se apaga.
  static const double growth = 8;

  /// Ancho del aro al nacer y al morir: se afina mientras se aleja, como una
  /// onda que pierde energía.
  static const double strokeWidth = 1.4;
  static const double minStrokeWidth = 0.9;

  /// Opacidad máxima del aro y del relleno tenue que lo acompaña (el relleno
  /// además se apaga conforme la onda se aleja).
  static const double peakStrokeOpacity = 0.65;
  static const double peakFillOpacity = 0.12;

  /// Halo difuso: radio (múltiplo de [baseRadius]) y opacidad media. Respira
  /// entre un 60 % y un 100 % de ese valor ([pulseBreath]).
  ///
  /// Va pegado al punto (apenas un poco más grande): la corona de ondas es la
  /// que viaja hacia fuera. Un halo del tamaño del anillo exterior convertía
  /// el aura en un disco relleno y plano.
  static const double glowRadiusScale = 1.35;
  static const double glowOpacity = 0.13;

  final LatLng point;
  final Color color;

  /// Radio (px de pantalla) del anillo MÁS INTERNO: justo en el borde del
  /// punto (22 px de diámetro + 3 de aro blanco = 14). Nacer más adentro lo
  /// deja escondido detrás del propio punto.
  final double baseRadius;

  /// Radio (px) del anillo MÁS EXTERNO. Entre [baseRadius] y este valor se
  /// reparten las ondas concéntricas; el crecimiento de [pulseWaveGrowth] va
  /// POR FUERA de este número (lo tiene en cuenta el motor al reservar el box).
  final double maxRadius;
}

/// Brillo de una onda dentro de su vuelta (`t` 0..1 → 0..1).
///
/// Entra con `smoothstep` en el primer 22 % de la vuelta —sin el golpe de
/// opacidad del latido anterior, que aparecía de golpe al reiniciar— y se
/// disuelve con una curva potencial, así que el final del recorrido ya no se
/// ve. El resultado es un latido que nunca «parpadea»: en `t = 0` y en
/// `t = 1` vale 0.
double pulseWaveGlow(double t) {
  final x = t.clamp(0.0, 1.0);
  final rise = (x / 0.22).clamp(0.0, 1.0);
  final easeIn = rise * rise * (3 - 2 * rise);
  return easeIn * math.pow(1 - x, 1.7).toDouble();
}

/// Desplazamiento (px lógicos) del anillo hacia fuera dentro de su vuelta.
///
/// `easeOutCubic`: arranca decidido y frena al final, que es como se mueve una
/// onda de verdad. En `t = 0` vale 0 y en `t = 1` vale [MapPulse.growth].
double pulseWaveGrowth(double t) {
  final x = 1 - t.clamp(0.0, 1.0);
  return MapPulse.growth * (1 - x * x * x);
}

/// Respiración del halo difuso (`0..1`): lento, en fase con las ondas.
double pulseBreath(double phase) => 0.5 + 0.5 * math.sin(2 * math.pi * phase);

/// Presencia del aura de «mi ubicación» según el zoom del mapa (0,18 … 1).
///
/// A zoom de calle (≥15) el latido se ve entero. Al alejar el mapa el punto
/// sigue midiendo lo mismo en pantalla, pero la ciudad encoge: el mismo halo
/// se veía gigante sobre la cartografía. De 15 a 12,5 se desvanece hasta
/// quedar casi imperceptible —nunca desaparece del todo, porque sigue
/// indicando dónde estás—. Los dos motores leen esta misma curva.
double pulsePresence(double zoom) {
  const fullZoom = 15.0;
  const faintZoom = 12.5;
  final t = ((zoom - faintZoom) / (fullZoom - faintZoom)).clamp(0.0, 1.0);
  return 0.18 + 0.82 * t;
}

/// Escala del radio de los anillos según el zoom (0,69 … 1).
///
/// Acompaña a [pulsePresence]: lejos el anillo no solo se apaga, también se
/// achica hasta casi esconderse detrás del punto.
double pulseRadiusScale(double zoom) => 0.62 + 0.38 * pulsePresence(zoom);

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
