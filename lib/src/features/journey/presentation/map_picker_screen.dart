import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_fab.dart';
import '../../../core/map/map.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/map_theme_scope.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/location.dart';
import '../../../core/widgets/map_theme_toggle_button.dart';
import '../../../core/widgets/urbano_map.dart';
import '../data/journey_repository.dart';

/// Selector de punto en el mapa (origen/destino) con pin fijo al centro y
/// devolución de `JourneyPoint`.
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({
    super.key,
    this.title = 'Punto en el mapa',
    this.initial,
    this.showTiles = true,
  });

  /// Título del selector (`Origen`, `Destino`…).
  final String title;

  /// Punto inicial (si no se pasa, se usa la ubicación del usuario o
  /// el centro de Santa Cruz).
  final JourneyPoint? initial;

  /// `false` solo para tests (evita fetch de tiles).
  final bool showTiles;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  static const _santaCruz = LatLng(-17.78, -63.15);

  final _mapController = UrbanoMapController();

  late JourneyPoint _point;

  /// Coordenada visible en el chip "Punto: …", actualizada EN VIVO mientras
  /// el mapa se desplaza (rebuild solo del chip, barato).
  late final ValueNotifier<JourneyPoint> _visiblePoint;

  bool _mapReady = false;
  bool _userInteracted = false;
  bool _initialLocApplied = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final cachedLocation = ref.read(myLocationProvider).valueOrNull;
    final start = initial == null
        ? (cachedLocation ?? _santaCruz)
        : LatLng(initial.lat, initial.lon);
    _point = (lat: start.latitude, lon: start.longitude);
    _visiblePoint = ValueNotifier<JourneyPoint>(_point);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _visiblePoint.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    _applyInitialLocation(ref.read(myLocationProvider).valueOrNull);
  }

  /// Centra el mapa en la ubicación del usuario al estar disponible (solo si
  /// el usuario aún no movió el mapa ni eligió un punto inicial).
  void _applyInitialLocation(LatLng? position) {
    if (position == null ||
        widget.initial != null ||
        _userInteracted ||
        _initialLocApplied ||
        !_mapReady) {
      return;
    }
    _initialLocApplied = true;
    _point = (lat: position.latitude, lon: position.longitude);
    _visiblePoint.value = _point;
    _mapController.move(position, _mapController.camera.zoom);
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    // El pin es FIJO y vive en el centro de la pantalla: el mapa se mueve
    // por debajo. La coordenada visible se refresca EN CALIENTE con cada
    // movimiento (chip pequeño, rebuild barato).
    final point = (lat: camera.center.latitude, lon: camera.center.longitude);
    _point = point;
    _visiblePoint.value = point;
    if (hasGesture) _userInteracted = true;
  }

  /// Marcador de punto FIJO (no arrastrable) con el aspecto del de Google
  /// Maps: gota con círculo blanco al centro. Su PUNTA queda clavada en el
  /// centro exacto del mapa, que es la coordenada que se devuelve. Para
  /// cambiarla se mueve el mapa por debajo, nunca el pin.
  Widget _buildCenterPin(BuildContext context) {
    const size = 46.0;
    // Altura REAL del pin (gota + margen de sombra): subir media esta altura
    // clavaba antes la punta en el centro; con el margen nuevo hay que usar la
    // altura encajada para que la punta siga cayendo justo en el punto central.
    final height = MapsPin.boxedHeight(size);
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Sombra elíptica justo en el punto del centro.
          Container(
            width: 30,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          // Subimos media altura del pin: la punta toca el punto central.
          Transform.translate(
            offset: Offset(0, -height / 2),
            child: const MapsPin(color: Color(0xFFDB4437), size: size),
          ),
        ],
      ),
    );
  }

  /// Centra el mapa en la ubicación del usuario con el flujo completo de
  /// ubicación (servicio apagado / permisos / ajustes).
  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      final granted = await ref
          .read(locationControllerProvider.notifier)
          .activate(context);
      // Sin ubicación: el usuario sigue pudiendo mover el pin a mano.
      if (!granted || !mounted) return;
      final position = await ref.read(myLocationProvider.future);
      if (position == null || !mounted) return;
      _userInteracted = true;
      if (_mapReady) _mapController.move(position, 15);
      setState(() {
        _point = (lat: position.latitude, lon: position.longitude);
      });
      _visiblePoint.value = _point;
    } on LocationFailure {
      // El pin sigue siendo arrastrable a mano.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Devuelve SIEMPRE el punto que el usuario está viendo: el centro actual
  /// de la cámara, que es exactamente donde está la punta del pin.
  ///
  /// Se lee la cámara viva en el momento de confirmar (y no solo el último
  /// `_point` cacheado) para que no exista ninguna ventana en la que lo
  /// devuelto difiera de lo que se ve en pantalla.
  void _confirm() {
    final center = _mapReady ? _mapController.camera.center : null;
    final point = center == null
        ? _point
        : (lat: center.latitude, lon: center.longitude);
    Navigator.of(context).maybePop<JourneyPoint>(point);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      myLocationProvider,
      (_, next) => _applyInitialLocation(next.valueOrNull),
    );

    // Con permiso y GPS activos se muestra el puck de "mi ubicación" sobre el
    // mapa: así, al marcar origen/destino, el usuario ve dónde está. NO se
    // sigue con la cámara (el pin de punto es fijo al centro y manda sobre la
    // coordenada devuelta); solo se pinta el punto azul de referencia.
    final locationReady =
        ref.watch(locationControllerProvider).status == LocationStatus.ready;

    final initialCenter = widget.initial == null
        ? (ref.watch(myLocationProvider).valueOrNull ?? _santaCruz)
        : LatLng(widget.initial!.lat, widget.initial!.lon);

    return Scaffold(
      // Selector de punto: el mapa y sus flotantes (título, chip de coordenada,
      // controles, FAB) comparten el brillo propio del mapa.
      body: MapThemeScope.builder(
        builder: (context) {
          // Este `context` YA está dentro del ámbito: la píldora de título y el
          // FAB se pintan con el brillo del mapa, no con el de la app.
          final colors = context.colors;
          final text = context.text;
          return Stack(
            fit: StackFit.expand,
            children: [
              // `Listener` no consume los gestos: solo observa. Marca cualquier
              // toque del usuario para que el auto-centrado por GPS (ubicación
              // inicial) NUNCA le gane a un gesto ya hecho: si el usuario ya
              // movió el mapa, el punto elegido es el suyo.
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _userInteracted = true,
                child: UrbanoMap(
                  controller: _mapController,
                  center: initialCenter,
                  zoom: 15,
                  showTiles: widget.showTiles,
                  myLocationEnabled: locationReady,
                  onMapReady: _onMapReady,
                  onPositionChanged: _onPositionChanged,
                ),
              ),
              // Pin fijo en el centro del mapa (la sombra marca el punto exacto).
              Center(child: _buildCenterPin(context)),
              // Controles de zoom (derecha).
              Positioned(
                right: 16,
                top: MediaQuery.of(context).padding.top + 72,
                child: Column(
                  children: [
                    _CircleButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Acercar',
                      onTap: _mapController.zoomIn,
                    ),
                    const SizedBox(height: 10),
                    _CircleButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Alejar',
                      onTap: _mapController.zoomOut,
                    ),
                    const SizedBox(height: 10),
                    // Brillo del mapa (independiente del tema de la app).
                    const MapThemeToggleButton(compact: true),
                  ],
                ),
              ),
              // Barra superior: volver + título.
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    _CircleButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Volver',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: colors.outlineVariant),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_with_rounded,
                            size: 15,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            widget.title,
                            style: text.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Controles inferiores: parada cercana + acciones.
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coordenada EXACTA que se va a devolver (5 decimales ≈ 1 m):
                    // se actualiza EN VIVO mientras el mapa se desplaza
                    // (ValueNotifier: reformar solo este chip, sin tocar la parada
                    // cercana ni el Scaffold) y refleja lo que devolverá `_confirm()`.
                    ValueListenableBuilder<JourneyPoint>(
                      valueListenable: _visiblePoint,
                      builder: (_, point, _) => _ChosenPointChip(point: point),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // FAB de ubicación con estados reales (GPS apagado /
                        // permiso pendiente / bloqueado / listo).
                        LocationFab(
                          heroTag: 'picker-location',
                          following: false,
                          onFollowChanged: (enabled) {
                            if (enabled && !_locating) _goToMyLocation();
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FloatingActionButton.extended(
                            heroTag: 'map-picker-use-point',
                            onPressed: _confirm,
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            elevation: 3,
                            icon: const Icon(
                              Icons.check_circle_rounded,
                              size: 22,
                            ),
                            label: const Text(
                              'Usar este punto',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Chip con la coordenada exacta que se devolverá al planificador.
///
/// Con el pin fijo al centro no hay forma de "leer" el número de otra
/// forma; se actualiza en vivo mientras el mapa se desplaza (a través de
/// `ValueListenableBuilder`) y refleja exactamente el valor de `_confirm()`.
class _ChosenPointChip extends StatelessWidget {
  const _ChosenPointChip({required this.point});

  final JourneyPoint point;

  static String _fmt(double value) {
    // Evita "+"-0 y mantiene siempre 5 decimales.
    final normalized = value == 0 ? 0.0 : value;
    return normalized.toStringAsFixed(5);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_location_alt_rounded, size: 17, color: colors.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Punto: ${_fmt(point.lat)}, ${_fmt(point.lon)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón circular flotante (volver / zoom).
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 21, color: colors.primary),
      ),
    );
  }
}
