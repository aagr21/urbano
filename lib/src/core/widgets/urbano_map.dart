import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../map/fake_map_engine.dart';
import '../map/google_tiles_session.dart';
import '../map/map.dart';
import '../map/map_scene.dart';
import '../map/map_tile.dart';
import '../map/maplibre_engine.dart';
import '../theme/app_theme.dart';
import '../theme/map_theme_controller.dart';
import '../utils/extensions.dart';
import '../utils/runtime_flags.dart';

/// Capa de mapa reutilizable sin API keys.
///
/// Es una **fachada**: describe qué dibujar ([MapScene]) y delega en el motor
/// activo:
///
/// - [MapLibreEngine]: motor real basado en `maplibre_gl` (tiles OpenFreeMap
///   en tema claro y CARTO raster en tema oscuro).
/// - [FakeMapEngine]: superficie simulada con puro Flutter; la usa la fachada
///   cuando `showTiles: false` o cuando corre dentro de `flutter test`
///   (`FLUTTER_TEST`), así los tests no necesitan plugin nativo ni red.
///
/// Ambos motores comparten la misma API: cámara ([UrbanoMapController]),
/// encuadre, taps de mapa y drags de marcadores.
class UrbanoMap extends ConsumerStatefulWidget {
  const UrbanoMap({
    super.key,
    required this.center,
    this.zoom = 13,
    this.polylines = const <MapPolyline>[],
    this.markers = const <MapMarker>[],
    this.controller,
    this.interactive = true,
    this.cameraFit,
    this.onMapReady,
    this.onTap,
    this.onPositionChanged,
    this.onMarkerTap,
    this.onMarkerDragStart,
    this.onMarkerDragUpdate,
    this.onMarkerDragEnd,
    this.onTrackingDismissed,
    this.attribution = true,
    this.showTiles = true,
    this.myLocationEnabled = false,
    this.followMyLocation = false,
  });

  /// Centro inicial (si no se pasa [cameraFit]).
  final LatLng center;
  final double zoom;
  final List<MapPolyline> polylines;
  final List<MapMarker> markers;
  final UrbanoMapController? controller;
  final bool interactive;

  /// Encuadre inicial sobre un rectángulo (solo se aplica al crearse).
  final MapCameraFit? cameraFit;

  final VoidCallback? onMapReady;
  final MapTapCallback? onTap;
  final MapPositionChangedCallback? onPositionChanged;

  /// Tap genérico sobre un marcador (los marcadores con [MapMarker.onTap]
  /// propios tienen prioridad).
  final MapMarkerTapCallback? onMarkerTap;

  /// Arrastre de cualquier marcador (el id permite saber cuál).
  final MapMarkerCallback? onMarkerDragStart;
  final MapMarkerCallback? onMarkerDragUpdate;
  final MapMarkerCallback? onMarkerDragEnd;

  /// El usuario dejó de seguir su ubicación (pan sobre el puck).
  final VoidCallback? onTrackingDismissed;

  /// Muestra la píldora de atribución (el motor real usa el control nativo).
  final bool attribution;

  /// `false` sin tiles: además, en `flutter test` siempre se usa el motor
  /// simulado (evita plugin nativo y red).
  final bool showTiles;

  /// Punto de "mi ubicación" en el mapa (puck) y si la cámara lo sigue.
  final bool myLocationEnabled;
  final bool followMyLocation;

  @override
  ConsumerState<UrbanoMap> createState() => _UrbanoMapState();
}

class _UrbanoMapState extends ConsumerState<UrbanoMap> {
  bool _readyFired = false;

  void _handleMapReady() {
    // El motor real lo llama al cargar el estilo; el simulado tras el primer
    // frame. Solo debe llegar a las pantallas una vez.
    if (_readyFired || !mounted) return;
    _readyFired = true;
    widget.onMapReady?.call();
  }

  MapScene _buildScene({
    required bool dark,
    required String? styleOverride,
    required Color background,
  }) => MapScene(
    center: widget.center,
    zoom: widget.zoom,
    cameraFit: widget.cameraFit,
    polylines: widget.polylines,
    markers: widget.markers,
    interactive: widget.interactive,
    showTiles: widget.showTiles,
    dark: dark,
    styleOverride: styleOverride,
    backgroundOverride: background,
    myLocationEnabled: widget.myLocationEnabled,
    followMyLocation: widget.followMyLocation,
    onMapReady: _handleMapReady,
    onTap: widget.onTap,
    onPositionChanged: widget.onPositionChanged,
    onMarkerTap: widget.onMarkerTap,
    onMarkerDragStart: widget.onMarkerDragStart,
    onMarkerDragUpdate: widget.onMarkerDragUpdate,
    onMarkerDragEnd: widget.onMarkerDragEnd,
    onTrackingDismissed: widget.onTrackingDismissed,
  );

  @override
  Widget build(BuildContext context) {
    // Capa efectiva del mapa: la elección del usuario, o el defecto del brillo
    // de la app. MIRA el provider directamente: la capa solo cambia el mapa
    // base, nunca el tema de los overlays (eso es el tema de la app).
    final tile = MapTile.resolve(
      appDark: Theme.of(context).brightness == Brightness.dark,
      choice: ref.watch(mapThemeControllerProvider),
    );
    final isDark = tile.brightness == Brightness.dark;
    // Capas MapTiler (OSM/Oscuro): estilo síncrono → `styleOverride: null` deja
    // que `MapScene` derive la URL de `dark`. Capas Google: el estilo ráster
    // llega al resolverse la sesión; mientras (`value == null`) se muestra el
    // estilo MapTiler del MISMO brillo como placeholder, nunca un estilo vacío
    // (un `setStyle` con estilo inválido recargaría el motor en balde).
    final styleOverride = tile.isGoogle
        ? ref.watch(googleStyleProvider(tile)).value
        : null;
    final scene = _buildScene(
      dark: isDark,
      styleOverride: styleOverride,
      background: tile.backgroundColor,
    );
    // En tests siempre el motor simulado (sin plugin ni red), aunque la
    // pantalla pida tiles.
    final useRealEngine = widget.showTiles && !isRunningUnderTest;

    final engine = useRealEngine
        ? MapLibreEngine(scene: scene, controller: widget.controller)
        : FakeMapEngine(scene: scene, controller: widget.controller);

    if (useRealEngine || !widget.attribution) return engine;

    // El motor real muestra el control de atribución nativo (la API no deja
    // desactivarlo); la píldora es solo para la superficie simulada.
    return Stack(
      fit: StackFit.expand,
      children: [
        engine,
        Positioned(
          right: 8,
          bottom: 8,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(tile.attribution, style: context.text.labelSmall),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pinta la gota del pin: sombra, degradado del color de la ruta, contorno y
/// (con [googleStyle]) el círculo blanco central. La geometría se adapta al
/// [Size] recibido.
class _PinPainter extends CustomPainter {
  const _PinPainter({
    required this.color,
    this.selected = false,
    this.googleStyle = false,
  });

  final Color color;
  final bool selected;

  /// `true` = aspecto del marcador de Google Maps: círculo blanco sólido en
  /// el centro de la cabeza y contorno oscuro (en vez del contorno blanco,
  /// que va pensado para llevar un icono encima).
  final bool googleStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _pinPath(size);
    final r = size.width / 2;

    // Sombra (glow del color de la ruta cuando está seleccionado).
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? color.withValues(alpha: 0.55)
            : Colors.black.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, selected ? 11 : 6)
        ..style = PaintingStyle.fill,
    );

    // Relleno con degradado vertical: luz arriba, base más profunda abajo.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.28)!,
            color,
            Color.lerp(color, Colors.black, 0.22)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );

    // Contorno: oscuro en estilo Google Maps, blanco para los pins con icono.
    canvas.drawPath(
      path,
      Paint()
        ..color = googleStyle
            ? Color.lerp(color, Colors.black, 0.30)!
            : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3.5 : (googleStyle ? 2 : 2.5),
    );

    // Círculo blanco central (la señal del marcador de Google Maps).
    if (googleStyle) {
      canvas.drawCircle(Offset(r, r), r * 0.46, Paint()..color = Colors.white);
    }
  }

  /// Gota: arco mayor del círculo (por encima) + dos tangentes hasta la punta.
  ui.Path _pinPath(Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final tip = Offset(r, size.height);
    final d = (tip - center).distance;
    // Ángulo del punto de tangencia medido desde la vertical.
    final phi = math.acos((r / d).clamp(-1.0, 1.0));
    final right = center + Offset(math.sin(phi) * r, math.cos(phi) * r);

    return ui.Path()
      ..moveTo(right.dx, right.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: r),
        math.pi / 2 - phi,
        -(2 * math.pi - 2 * phi),
        false,
      )
      ..lineTo(tip.dx, tip.dy)
      ..close();
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.selected != selected;
}

/// Puck de ubicación del usuario en el mapa: punto azul de alta visibilidad
/// con halo difuso de precisión y contorno blanco, visible sobre mapas
/// claros y oscuros.
class UserLocationPuck extends StatelessWidget {
  const UserLocationPuck({super.key, this.size = 20});

  /// Diámetro del círculo central.
  final double size;

  @override
  Widget build(BuildContext context) {
    const totalSize = 36.0;
    return const SizedBox(
      key: ValueKey('user-location-puck'),
      width: totalSize,
      height: totalSize,
      child: Center(child: _PuckDot()),
    );
  }
}

class _PuckDot extends StatelessWidget {
  const _PuckDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0x662563EB), blurRadius: 10, spreadRadius: 3),
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 5,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
    );
  }
}

/// Pin de extremo del viaje (origen verde / destino rojo) con el aspecto del
/// marcador de Google Maps: gota con círculo blanco sólido al centro.
///
/// Debe montarse dentro de un [MapMarker] con `anchor: MapMarkerAnchor.bottom`
/// y el cuadro que devuelve [widthFor] / [heightFor] (la gota + el margen de
/// sombra), NO el `size` pelado: así el PNG rasterizado no recorta la sombra.
class EndpointMarker extends StatelessWidget {
  const EndpointMarker({
    super.key,
    required this.color,
    this.size = 40,
    this.onTap,
  });

  /// Color del extremo (verde origen / rojo destino).
  final Color color;

  /// Ancho del pin (diámetro del círculo).
  final double size;

  final VoidCallback? onTap;

  /// Relación alto/ancho del pin (círculo + punta).
  static const double heightFactor = MapsPin.heightFactor;

  /// Ancho que debe tener el [MapMarker] que envuelva un pin de este `size`.
  static double widthFor(double size) => MapsPin.boxedWidth(size);

  /// Alto que debe tener el [MapMarker] que envuelva un pin de este `size`.
  static double heightFor(double size) => MapsPin.boxedHeight(size);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: MapsPin(color: color, size: size),
  );
}

/// Marcador de punto en forma de gota con el aspecto del de Google Maps
/// (círculo blanco sólido al centro y contorno oscuro). La punta señala el
/// punto exacto: el [MapMarker] que la envuelva debe anclar por `bottom`.
///
/// El widget reserva a su alrededor un margen transparente ([shadowPad]) para
/// la sombra y el contorno: al rasterizarse a PNG (MapLibre recorta la captura
/// al tamaño exacto del marcador) ese margen evita que la gota se vea "corta"
/// o planchada por los bordes. La punta sigue cayendo en el centro-inferior
/// del cuadro, así el anclaje `bottom` apunta a la coordenada correcta.
class MapsPin extends StatelessWidget {
  const MapsPin({
    super.key,
    required this.color,
    this.size = 44,
    this.selected = false,
  });

  /// Color del pin.
  final Color color;

  /// Ancho del pin (diámetro del círculo).
  final double size;

  /// `true` para resaltar (glow del color).
  final bool selected;

  /// Relación alto/ancho del pin (círculo + punta).
  static const double heightFactor = 1.4;

  /// Margen transparente que rodea la gota para la sombra + el contorno.
  static const double shadowPad = 8;

  /// Ancho real del cuadro que ocupa el pin (gota + margen lateral).
  static double boxedWidth(double size) => size + shadowPad * 2;

  /// Alto real del cuadro que ocupa el pin (gota + margen superior; la punta
  /// queda al ras del borde inferior para que el anclaje `bottom` sea exacto).
  static double boxedHeight(double size) => size * heightFactor + shadowPad;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: boxedWidth(size),
    height: boxedHeight(size),
    // Sin margen abajo: la punta toca el borde inferior del cuadro.
    child: Padding(
      padding: const EdgeInsets.only(
        top: shadowPad,
        left: shadowPad,
        right: shadowPad,
      ),
      child: CustomPaint(
        painter: _PinPainter(
          color: color,
          selected: selected,
          googleStyle: true,
        ),
      ),
    ),
  );
}
