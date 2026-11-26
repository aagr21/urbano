import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/location/location_fab.dart';
import '../../../core/map/map.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/location.dart';
import '../../../core/widgets/map_tile_button.dart';
import '../../../core/widgets/urbano_back_button.dart';
import '../../../core/widgets/urbano_map.dart';
import '../data/journey_repository.dart';
import 'widgets/map_picker_widgets.dart';

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
        !shouldAutoCenterPicker(
          hasInitialPoint: widget.initial != null,
          userInteracted: _userInteracted,
          alreadyApplied: _initialLocApplied,
          mapReady: _mapReady,
        )) {
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

    // Ya no hay puck nativo de MapLibre (GPS de un solo dueño): el selector
    // se centra con la LECTURA PUNTUAL de «mi ubicación» (myLocationProvider,
    // refrescada al conceder el permiso) y el pin fijo del centro marca el
    // punto devuelto. [locationControllerProvider] solo queda para el FAB.

    final initialCenter = widget.initial == null
        ? (ref.watch(myLocationProvider).valueOrNull ?? _santaCruz)
        : LatLng(widget.initial!.lat, widget.initial!.lon);

    final colors = context.colors;

    return Scaffold(
      // Selector de punto: solo el mapa base sigue al tile elegido; título,
      // chip de coordenada, controles y FAB usan siempre el tema de la app.
      body: Stack(
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
              // GPS DE UN SOLO DUEÑO (default `myLocationEnabled=false`):
              // este selector se centra desde las lecturas PUNTUALES de
              // [LocationService] (geolocator); la capa nativa de MapLibre
              // enciende su propio GPS continuo sin control nuestro, así
              // que aquí no se usa nunca más.
              onMapReady: _onMapReady,
              onPositionChanged: _onPositionChanged,
            ),
          ),
          // Pin fijo en el centro del mapa (la sombra marca el punto exacto).
          const Center(child: MapPickerCenterPin()),
          // Controles de zoom (derecha).
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 72,
            child: Column(
              children: [
                MapPickerCircleButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Acercar',
                  onTap: _mapController.zoomIn,
                ),
                const SizedBox(height: 10),
                MapPickerCircleButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Alejar',
                  onTap: _mapController.zoomOut,
                ),
                const SizedBox(height: 10),
                // Tile del mapa (independiente del tema de la app).
                const MapTileButton(),
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
                UrbanoBackButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  floating: true,
                ),
                const SizedBox(width: 10),
                MapPickerTitlePill(title: widget.title),
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
                  builder: (_, point, _) => MapPickerPointChip(point: point),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // FAB de ubicación con estados reales (GPS apagado /
                    // permiso pendiente / bloqueado / listo).
                    LocationFab(
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
                        icon: const Icon(Icons.check_circle_rounded, size: 22),
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
      ),
    );
  }
}
