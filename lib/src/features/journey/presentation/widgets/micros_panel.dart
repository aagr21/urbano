import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/location/location_service.dart';
import '../../../routes/data/route_models.dart';
import '../../../stops/data/stop_search_models.dart';
import '../../application/journey_planner_controller.dart';
import '../../application/journey_providers.dart';
import '../../application/micros_panel_controller.dart';
import 'micros_panel_actions.dart';
import 'micros_panel_backdrop.dart';
import 'micros_panel_header.dart';
import 'micros_panel_list.dart';
import 'micros_panel_mode_switch.dart';
import 'micros_panel_search_field.dart';
import 'micros_panel_shell.dart';
import 'micros_places_list.dart';

/// Panel lateral de micros: fondo `surface`, esquinas redondeadas a la derecha
/// y el listado a toda altura.
///
/// El estado de verdad vive fuera: los recorridos activos en el **controller
/// del planeador**, el trabajo del panel (búsqueda, scroll, detalles, modo) en
/// [MicrosPanelController] + [journeyMicrosSessionProvider]. En este `State`
/// solo queda lo que no puede vivir en otro sitio: las animaciones de
/// entrada/cierre, el arrastre horizontal, el campo de texto y el scroll.
class MicrosPanel extends ConsumerStatefulWidget {
  const MicrosPanel({
    super.key,
    required this.onToggleDirection,
    required this.onClearAll,
    this.onFramePlaces,
  });

  final Future<void> Function(RouteSummary micro, int directionId)
  onToggleDirection;
  final VoidCallback onClearAll;

  /// Encuadre del mapa (debajo del cajón) sobre el lugar marcado y sus
  /// paradas, para que el pin recién clavado se vea. `null` = sin capacidad
  /// de encuadrar (p. ej. harness de tests que abre el panel suelto).
  final void Function(List<({double lat, double lon})> points)? onFramePlaces;

  @override
  ConsumerState<MicrosPanel> createState() => MicrosPanelState();
}

class MicrosPanelState extends ConsumerState<MicrosPanel>
    with TickerProviderStateMixin {
  /// Reproducir UNA sola vez al abrir el panel (no en cada toggle/rebuild):
  /// controlador de entrada que escalona el fundido+deslizamiento de las
  /// secciones (encabezado, buscador y acciones).
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final Animation<double> _aHeader = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _aSearch = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.16, 0.66, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _aActions = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.32, 0.82, curve: Curves.easeOutCubic),
  );

  /// Muelle del arrastre horizontal: devuelve el panel a su sitio cuando el
  /// gesto no llegó al umbral de cierre.
  late final AnimationController _snap =
      AnimationController(vsync: this, duration: Motion.fade)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _dragDx = 0);
          }
        });
  late final Animation<double> _snapCurved = CurvedAnimation(
    parent: _snap,
    curve: Curves.easeOut,
  );

  /// Desplazamiento horizontal del arrastre (0 = pegado al borde; negativo
  /// mientras se tira hacia la izquierda para cerrar).
  double _dragDx = 0;
  Tween<double>? _snapFrom;

  /// Distancia de arrastre (px) que cierra el panel al soltar.
  static const double _dismissDrag = 88;

  late final JourneyMicrosSession _session;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final panel = _panel;
    _session = panel.session;
    _searchController = TextEditingController(
      text: panel.searchTextForMode(panel.placesMode),
    );
    _searchFocus = FocusNode()..addListener(_onFocusChanged);
    // El scroll se guarda EN CADA movimiento: al cerrar, los descendants se
    // desmontan antes de nuestro `dispose`, así que ahí el controller ya no
    // tiene clients y esperar al dispose perdería la posición.
    _scroll = ScrollController(
      initialScrollOffset: math.max(0.0, _session.scrollOffset),
    )..addListener(_saveScrollOffset);
    _entrance.forward();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {}); // glow del campo al enfocar
  }

  void _saveScrollOffset() {
    if (_scroll.hasClients) _session.scrollOffset = _scroll.offset;
  }

  @override
  void dispose() {
    _saveScrollOffset();
    _entrance.dispose();
    _snap.dispose();
    _scroll.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Lógica del panel (búsqueda, modos, catálogo y toggles).
  MicrosPanelController get _panel => ref.read(microsPanelProvider.notifier);

  /// Estado publicado por el controller: dice qué hay en vuelo. `read` (no
  /// `watch`) porque solo se consulta desde callbacks; el `build` usa
  /// `ref.watch` directo.
  MicrosPanelSnapshot get _state => ref.read(microsPanelProvider);

  /// Offset mostrado: durante el arrastre sigue al dedo; al soltar sin cerrar,
  /// lo interpola el muelle [_snap].
  double get _shownDx {
    final from = _snapFrom;
    if (_snap.isAnimating && from != null) return from.evaluate(_snapCurved);
    return _dragDx;
  }

  /// Cambia de modo (líneas ⇆ lugares): el campo se reinicia con la consulta
  /// de ese modo y el commit es el texto guardado.
  void _switchMode(bool toPlaces) {
    _panel.switchMode(toPlaces);
    _searchController.text = _panel.searchTextForMode(toPlaces);
  }

  void _clearQuery() {
    _searchController.clear();
    _panel.clearLineQuery();
  }

  /// Borra la búsqueda de lugares (borrador Y confirmada) — vuelve a la guía
  /// de «cerca de mí».
  void _clearPlacesSearch() {
    _searchController.clear();
    _panel.clearPlacesSearch();
  }

  /// «Cerca de mí»: GPS una vez → punto a la sesión → el listado de
  /// [stopNearbyProvider] se refresca solo. Sin ubicación queda la guía.
  Future<void> _applyMyLocation() async {
    if (_state.locked) return;
    final me = await ref.read(myLocationProvider.future);
    if (!mounted || me == null) return;
    _panel.applyPlacesPoint((lat: me.latitude, lon: me.longitude));
  }

  /// «Marcar en el mapa» del modo LUGARES: abre el selector de punto (el
  /// MISMO `/journey/pick` que origen/destino) y usa lo elegido como el lugar
  /// a consultar — equivale a un «cerca de mí» pero en el punto que el usuario
  /// clava.
  Future<void> _pickPlaceOnMap() async {
    if (_state.locked) return;
    final current = _panel.session.placesNearbyPoint;
    final params = <String, String>{'title': 'Lugar'};
    if (current != null) {
      params['lat'] = '${current.lat}';
      params['lon'] = '${current.lon}';
    }
    final picked = await context.push<({double lat, double lon})>(
      Uri(path: '/journey/pick', queryParameters: params).toString(),
    );
    if (picked == null || !mounted) return;
    _panel.applyPlacesPoint(picked);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_snap.isAnimating) _snap.stop();
    setState(() {
      _dragDx = (_dragDx + details.delta.dx).clamp(-140.0, 0.0);
      _snapFrom = null;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_dragDx < -_dismissDrag || velocity < -520) {
      // Se suelta dentro del gesto: el pop corre la transición de salida del
      // PageRouteBuilder, que ya desliza el panel hacia la izquierda.
      Navigator.of(context).pop();
      return;
    }
    setState(() => _snapFrom = Tween<double>(begin: _dragDx, end: 0.0));
    _snap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(microsPanelProvider);
    final panel = _panel;
    final activeKeys = ref
        .watch(journeyPlannerControllerProvider)
        .visibleRouteKeys;
    final panelWidth = math.min(340.0, MediaQuery.sizeOf(context).width * 0.85);
    // Franja extra a la derecha donde vive el tirador (ver [MicrosPanelShell]).
    const handleZone = 18.0;

    // El ámbito de brillo del mapa lo pone la ruta (`pageBuilder`), así que el
    // `context` de este `build` ya resuelve `context.colors` contra el modo del
    // mapa: reabrir el panel nunca pinta letra oscura sobre vidrio oscuro.
    return MicrosPanelShell(
      width: panelWidth,
      handleZone: handleZone,
      offsetDx: _shownDx,
      onDragUpdate: _onDragUpdate,
      onDragEnd: _onDragEnd,
      onClose: () => Navigator.of(context).pop(),
      child: Stack(
        children: [
          // Fondo vivo del cajón (manchas de marca + filo de color): se pinta
          // DEBAJO de todo y no recibe toques, así que el listado no cambia de
          // conducta.
          const Positioned.fill(child: MicrosPanelBackdrop()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MicrosPanelHeader(
                lineCount: panel.micros.length,
                activeCount: activeKeys.length,
                animation: _aHeader,
              ),
              // El interruptor va con el MISMO margen lateral que el
              // encabezado, el buscador y el listado (20): antes se estiraba
              // de borde a borde y rompía la columna del panel. Abajo deja aire
              // antes del buscador para que la fila LÍNEAS/LUGARES no se pegue
              // al campo.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: MicrosPanelModeSwitch(
                  places: panel.placesMode,
                  onChanged: _switchMode,
                ),
              ),
              MicrosPanelSearchField(
                controller: _searchController,
                focusNode: _searchFocus,
                animation: _aSearch,
                placesMode: panel.placesMode,
                placesDraft: snapshot.placesDraft,
                query: panel.query,
                locked: snapshot.locked,
                onChanged: panel.setSearchText,
                onSubmitted: panel.commitPlacesSearch,
                onClearQuery: _clearQuery,
                onClearPlacesSearch: _clearPlacesSearch,
                onPickPlace: _pickPlaceOnMap,
              ),
              if (!panel.placesMode)
                MicrosPanelActions(
                  activeCount: activeKeys.length,
                  locked: snapshot.locked,
                  animation: _aActions,
                  onActivateAll: _activateAll,
                  onClearAll: _clearAll,
                ),
              Expanded(
                child: AnimatedBuilder(
                  // [_entrance] manda: mientras dura la entrada el listado se
                  // reconstruye frame a frame (así escala sus tarjetas) y al
                  // terminar deja de escuchar.
                  animation: _entrance,
                  builder: (_, _) => panel.placesMode
                      ? MicrosPlacesList(
                          query: panel.placesQuery,
                          point: panel.session.placesNearbyPoint,
                          onUseMyLocation: _applyMyLocation,
                          onPickOnMap: _pickPlaceOnMap,
                          activeDirectionKeys: activeKeys,
                          busyKey: snapshot.busyKey,
                          locked: snapshot.locked,
                          onToggleRoute: _toggleStopRoute,
                          onFramePlaces: widget.onFramePlaces,
                        )
                      : MicrosPanelList(
                          micros: panel.micros,
                          filtered: panel.visibleMicros,
                          query: panel.query,
                          activeKeys: activeKeys,
                          busyKey: snapshot.busyKey,
                          locked: snapshot.locked,
                          scrollController: _scroll,
                          entrance: _entrance,
                          directionsOf: panel.directionsOf,
                          onRefresh: panel.refreshCatalog,
                          onClearQuery: _clearQuery,
                          onToggle: _toggleMicro,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _activateAll() =>
      _panel.activateAll(onToggle: widget.onToggleDirection);

  void _clearAll() => _panel.clearAll(widget.onClearAll);

  Future<void> _toggleMicro(RouteSummary micro, int directionId) => _panel
      .toggleDirection(micro, directionId, onToggle: widget.onToggleDirection);

  Future<void> _toggleStopRoute(StopRouteRef route) =>
      _panel.toggleStopRoute(route, onToggle: widget.onToggleDirection);
}
