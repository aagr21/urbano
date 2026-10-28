import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'map_types.dart';

/// Superficie que ejecuta las órdenes de cámara/marcadores de un
/// [UrbanoMapController]. La implementa el [State] de cada motor.
///
/// El controller nunca habla con `maplibre_gl` directamente: solo con este
/// host, así el mismo código de pantalla sirve con el motor real y con el
/// simulado (tests).
abstract class MapEngineHost {
  /// Cámara actual.
  MapCamera get camera;

  /// Tamaño del mapa, o `null` si aún no se maquetó.
  Size? get viewportSize;

  /// Mueve la cámara (animado salvo que se indique lo contrario).
  void moveCamera(LatLng center, double zoom, {bool animated = true});

  /// Zoom relativo (+/-).
  void zoomBy(double delta, {bool animated = true});

  /// Encuadra [points] dentro del viewport con [padding].
  Future<void> fitBounds(
    Iterable<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(56),
    double maxZoom = 17,
    bool animated = true,
  });

  /// Mueve un marcador existente sin re-renderizar la pantalla.
  ///
  /// Lo usa el selector de punto para "pegar" el pin al centro del mapa
  /// mientras el usuario desplaza el mapa.
  void moveMarker(String markerId, LatLng point);
}

/// Controlador del mapa creado por las pantallas (`MapController()` antes).
///
/// Se enlaza automáticamente con el motor montado dentro de [UrbanoMap];
/// si el motor cambia (real ↔ simulado) se re-enlaza solo.
class UrbanoMapController {
  UrbanoMapController({LatLng? center, double zoom = 13})
    : _fallback = MapCamera(center: center ?? const LatLng(0, 0), zoom: zoom);

  MapEngineHost? _host;
  MapCamera _fallback;

  /// `true` si ya hay un motor escuchando este controller.
  bool get isAttached => _host != null;

  /// Cámara actual (del motor si está enlazado, si no la última conocida).
  MapCamera get camera => _host?.camera ?? _fallback;

  LatLng get center => camera.center;
  double get zoom => camera.zoom;

  /// Mueve la cámara a [center] con el zoom indicado (animado).
  void move(LatLng center, double zoom) {
    _fallback = MapCamera(center: center, zoom: zoom);
    _host?.moveCamera(center, zoom);
  }

  void zoomIn() => zoomBy(1);

  void zoomOut() => zoomBy(-1);

  void zoomBy(double delta) => _host?.zoomBy(delta);

  /// Encuadra todos los [points] (viaje, ruta…) con [padding].
  Future<void> fitBounds(
    Iterable<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(56),
    double maxZoom = 17,
    bool animated = true,
  }) {
    final host = _host;
    if (host == null) return Future<void>.value();
    return host.fitBounds(
      points,
      padding: padding,
      maxZoom: maxZoom,
      animated: animated,
    );
  }

  /// Arrastra/traslada un marcador sin esperar a un rebuild.
  void moveMarker(String markerId, LatLng point) =>
      _host?.moveMarker(markerId, point);

  /// Enlaza el motor recién creado (lo llama el motor, no las pantallas).
  void attach(MapEngineHost host) {
    _host = host;
    _fallback = host.camera;
  }

  /// Desenlaza [host] si era el motor activo.
  void detach(MapEngineHost host) {
    if (identical(_host, host)) _host = null;
  }

  /// Liberado por las pantallas (idempotente).
  void dispose() => _host = null;
}
