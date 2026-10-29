import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/animation/motion.dart';
import '../../../core/map/map.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/location.dart';
import '../../../core/utils/time_formatters.dart';
import '../../routes/data/route_models.dart';
import '../data/journey_repository.dart';
import 'journey_planner_controller.dart';
import 'journey_providers.dart';
import 'journey_results_view.dart';
import 'widgets/journey_live_map.dart';
import 'widgets/journey_map_chips.dart';
import 'widgets/journey_micros_sheet.dart';
import 'widgets/journey_place_picker_sheet.dart';
import 'widgets/journey_planner_card.dart';
import 'widgets/journey_planner_close_button.dart';
import 'widgets/journey_planner_trigger.dart';
import 'widgets/journey_result_map.dart';
import 'widgets/journey_results_sheet.dart';
import 'widgets/journey_status_panel.dart';

/// Pantalla única **Viaje + Mapa**: un mapa didáctico a pantalla completa
/// (UN solo `JourneyResultMap` montado, nunca se crea/destruye la vista
/// nativa) con dos modos:
///
/// - **Exploración** (sin resultados): capas con polilíneas de rutas + la
///   tarjeta origen→destino para planificar.
/// - **Resultados**: el MISMO mapa dibuja la capa de viaje (legs, insignias,
///   endpoints arrastrables) y una `DraggableScrollableSheet` con las
///   opciones; tocar una tarjeta cambia la capa del mapa sin recrearlo.
///
/// El control de ubicación es real: `LocationFab` con estados del sistema
/// (GPS apagado / permiso pendiente / bloqueado / listo) y flujo de ajustes.
///
/// La presentación vive en `widgets/` (callback a callback, prop a prop);
/// el ESTADO del planeador vive en [journeyPlannerControllerProvider]
/// (debounce, barrera anti-zoom, capas de micros) y aquí queda solo el
/// cableado UI: `GlobalKey` del mapa, hoja arrastrable y panel abierto.
class JourneyPlannerScreen extends ConsumerStatefulWidget {
  const JourneyPlannerScreen({super.key});
  @override
  ConsumerState<JourneyPlannerScreen> createState() =>
      _JourneyPlannerScreenState();
}

class _JourneyPlannerScreenState extends ConsumerState<JourneyPlannerScreen> {
  // ------------------------------------------------------------------
  // UI pura del State: mapa, hoja arrastrable, panel
  // ------------------------------------------------------------------
  final _journeyMapKey = GlobalKey<JourneyResultMapState>();
  final _sheetController = DraggableScrollableController();
  double _sheetExtent = 0.45;

  /// `true` cuando el panel de origen/destino está desplegado sobre el mapa.
  /// Arranca cerrado: el mapa es el protagonista y el panel se abre con la
  /// píldora inferior "¿A dónde vas?".
  bool _panelOpen = false;

  /// Abre/cierra el panel de origen/destino (con animación de despliegue).
  void _togglePanel() => setState(() => _panelOpen = !_panelOpen);
  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetExtentChanged);
    // «Ver todas» desde el home (ver [pendingMicrosPanelProvider]): la bandera
    // llega puesta al llegar a la pestaña Viaje y aquí se convierte en la
    // apertura del panel de micros.
    //
    // `listenManual` + `fireImmediately` en vez de `ref.listen` en el `build`:
    // si esta rama NUNCA se había visitado, su primer `build` corre en el
    // mismo frame del `go()`, de modo que el listener nacería con la bandera ya
    // en `true` y sin ningún cambio posterior que lo disparara (el panel no se
    // abriría hasta el segundo intento). `fireImmediately` evalúa el valor
    // actual al suscribirse.
    //
    // Limpiar y abrir se difieren al frame siguiente: el `push` no debe
    // cabalgar la transición de pestaña, y escribir el provider durante la
    // construcción del árbol avisaría a los listeners a media build.
    ref.listenManual(pendingMicrosPanelProvider, (_, next) {
      if (!next) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(pendingMicrosPanelProvider.notifier).state = false;
        _openMicrosSheet();
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetExtentChanged);
    _sheetController.dispose();
    super.dispose();
  }

  /// Notifier del planeador (lectura fuera de `build`).
  JourneyPlannerController get _planner =>
      ref.read(journeyPlannerControllerProvider.notifier);
  // ------------------------------------------------------------------
  // Viaje: origen/destino/hora/swap/planificar
  // ------------------------------------------------------------------
  /// Selector completo de origen/destino: "Mi ubicación" (GPS), punto del
  /// mapa o un lugar popular de Santa Cruz.
  Future<void> _pickPlace({required bool isOrigin}) async {
    final picked = await showJourneyPlacePickerSheet(
      context,
      ref: ref,
      title: isOrigin ? '¿De dónde sales?' : '¿A dónde vas?',
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case JourneyPlacePickSource.myLocation:
        await _useMyLocationAs(isOrigin: isOrigin);
      case JourneyPlacePickSource():
        await _pickFromMap(isOrigin: isOrigin);
      case JourneyPlacePickPoi(:final poi):
        _commitPlace(
          JourneyPlacePoi(
            name: poi.name,
            lat: poi.lat,
            lon: poi.lon,
            subtitle: poi.ringOrZone,
          ),
          isOrigin: isOrigin,
        );
    }
  }

  /// Coloca "mi ubicación" en el extremo, resolviendo el flujo de permisos.
  Future<void> _useMyLocationAs({required bool isOrigin}) async {
    final granted = await ref
        .read(locationControllerProvider.notifier)
        .activate(context);
    if (!mounted) return;
    if (!granted) {
      context.showSnack(
        'Necesitamos tu ubicación para completar el viaje.',
        isError: true,
      );
      return;
    }
    final position = await ref.read(myLocationProvider.future);
    if (!mounted) return;
    if (position == null) {
      context.showSnack('No pudimos leer tu ubicación.', isError: true);
      return;
    }
    _commitPlace(
      JourneyPlaceLocation(lat: position.latitude, lon: position.longitude),
      isOrigin: isOrigin,
    );
  }

  /// Abre el selector de punto en el mapa y rellena el campo con EL PUNTO
  /// elegido (el origen/destino nunca es una parada GTFS).
  ///
  /// El punto actual (lugar ya marcado) se pasa como coordenadas iniciales
  /// para que el selector ABRA ENCIMA de él: si no, ajustar un extremo ya
  /// elegido te mandaba al GPS/ciudad y el punto quedaba en otra ubicación.
  /// El título viaja también: el `Uri` se construye con `path` +
  /// `queryParameters` (un solo `?`); concatenar otro `?` a mano rompía la
  /// primera clave del query y el selector perdía el título.
  Future<void> _pickFromMap({required bool isOrigin}) async {
    final current =
        (isOrigin
                ? ref.read(journeyPlannerControllerProvider).origin
                : ref.read(journeyPlannerControllerProvider).destination)
            .pointOrNull;
    final params = <String, String>{'title': isOrigin ? 'Origen' : 'Destino'};
    if (current != null) {
      params['lat'] = '${current.lat}';
      params['lon'] = '${current.lon}';
    }
    final point = await context.push<JourneyPoint>(
      Uri(path: '/journey/pick', queryParameters: params).toString(),
    );
    if (point == null || !mounted) return;
    _commitPlace(
      JourneyPlacePoint(lat: point.lat, lon: point.lon),
      isOrigin: isOrigin,
    );
  }

  /// Compromete un lugar en el extremo (selector de lugares, "mi ubicación"
  /// o punto del mapa): la lógica vive en el controller; la pantalla aporta
  /// el encuadre de cámara del mapa tras la selección.
  void _commitPlace(JourneyPlace place, {required bool isOrigin}) {
    _planner.setPlace(place, isOrigin: isOrigin);
    _framePickedEndpoints();
  }

  /// Lleva la cámara hasta los extremos elegidos para que sus pines se vean.
  ///
  /// Se ejecuta tras comprometer la selección: el mapa ya tiene el marcador,
  /// pero su cámara no se mueve sola (el `center` solo aplica al crearse),
  /// así que un punto elegido lejos del encuadre quedaba invisible.
  void _framePickedEndpoints() {
    final planner = ref.read(journeyPlannerControllerProvider);
    final points = <LatLng>[
      for (final place in [
        planner.origin.pointOrNull,
        planner.destination.pointOrNull,
      ])
        if (place case final p?) LatLng(p.lat, p.lon),
    ];
    _journeyMapKey.currentState?.fitToPoints(points);
  }

  Future<void> _pickTime() async {
    final current = ref.read(journeyPlannerControllerProvider).time;
    final parts = GtfsTime.parseHm(current);
    final now = TimeOfDay.now();
    final initial = parts == null
        ? now
        : TimeOfDay(hour: parts.$1, minute: parts.$2);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    _planner.setTime(GtfsTime.formatHm(picked.hour, picked.minute));
  }

  /// Envía la consulta, salvo que origen y destino estén en el mismo sitio
  /// (o casi): en ese caso avisa en vez de pedir un viaje imposible.
  void _submit() {
    final planner = ref.read(journeyPlannerControllerProvider);
    final distance = planner.endpointsDistanceM;
    if (distance != null &&
        distance < JourneyPlannerState.minTransitDistanceM) {
      context.showSnack(
        distance < 1
            ? 'El origen y el destino son el mismo punto: mueve uno de ellos.'
            : 'El origen y el destino están a ${distance.round()} m: '
                  'mueve uno de los puntos.',
        isError: true,
      );
      return;
    }
    _planner.submit();
    setState(() {
      // Al planificar, el panel se guarda solo para dejar ver el viaje.
      _panelOpen = false;
    });
  }

  void _swap() {
    _planner.swap();
  }

  /// Vuelve al modo exploración: limpia origen/destino y resultados.
  void _clear() {
    _planner.clear();
  }

  /// El usuario marcó una opción en la hoja de resultados (o la expandió).
  void _selectOption(int itemIndex) => _planner.selectOption(itemIndex);

  /// Resultado del toggle de una dirección del panel de micros: solo los dos
  /// casos con problema llegan al usuario como snacks.
  Future<void> _toggleRouteDirection(
    RouteSummary route,
    int directionId,
  ) async {
    final outcome = await _planner.toggleRouteDirection(route, directionId);
    if (!mounted) return;
    switch (outcome) {
      case MicroRouteToggleOutcome.missingShape:
        context.showSnack('Esta ruta no tiene forma cargada.');
      case MicroRouteToggleOutcome.failed:
        context.showSnack(
          'No pudimos cargar el recorrido de esa línea.',
          isError: true,
        );
      case MicroRouteToggleOutcome.toggledOn:
      case MicroRouteToggleOutcome.toggledOff:
        break;
    }
  }

  // ------------------------------------------------------------------
  // Mapa: movimiento de cámara y panel de micros
  // ------------------------------------------------------------------
  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    // Sella el momento del gesto: la ventana de la barrera anti-zoom nace
    // con el gesto, no con el drop del pin (la ventana vive en el controller).
    _planner.noteGestureCameraMoved();
  }

  /// Panel de micros: dibujar/borrar los recorridos (ida/vuelta) de las líneas.
  ///
  /// Antes de entrar, cualquier panel viejo que siga en el stack de Viaje
  /// sale: «Ver todas» presionado de nuevo (o con el cajón a medio cerrar)
  /// debe **reemplazar** el panel, no apilar otro encima — el cajón se
  /// identifica por su nombre de ruta, así que si no hay resto, `popUntil`
  /// no saca nada.
  Future<void> _openMicrosSheet() {
    final navigator = Navigator.of(context);
    navigator.popUntil(
      (route) => route.settings.name != 'journey-micros-panel',
    );
    return showJourneyMicrosPanel(
      context,
      ref: ref,
      onToggleDirection: _toggleRouteDirection,
      onClearAll: () => _planner.clearMicros(),
      // Encuadra el mapa sobre el lugar marcado y sus paradas para que el pin
      // recién clavado se vea (el mapa vive debajo del cajón).
      onFramePlaces: (points) {
        if (points.isEmpty) return;
        _journeyMapKey.currentState?.fitToPoints([
          for (final p in points) LatLng(p.lat, p.lon),
        ]);
      },
    );
  }

  void _onSheetExtentChanged() {
    if (!mounted || !_sheetController.isAttached) return;
    final size = _sheetController.size;
    if ((size - _sheetExtent).abs() < 0.002) return;
    setState(() => _sheetExtent = size);
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // La ubicación EN VIVO no se ve aquí: `locationControllerProvider` emite
    // una posición por cada tick de GPS, y mirarlo en este `build`
    // reconstruía EL ÁRBOL ENTERO (LayoutBuilder, panel, chips, hoja de
    // resultados) solo para mover la cámara. Lo que de verdad depende del GPS
    // vive en los dos `Consumer` acotados de abajo: [LiveMapLayer] y
    // [LiveMapControls].
    // Pantalla completa del mapa: oculta los paneles flotantes y deja solo
    // el mapa con sus controles (la barra del shell la esconde UrbanoShell).
    final fullscreen = ref.watch(mapFullscreenProvider);
    final planner = ref.watch(journeyPlannerControllerProvider);
    // Vista de resultados: todo lo derivado del viaje (consulta efectiva,
    // caché con su regla de frescura, selección acotada, opción del mapa,
    // extremos para el mapa) llega contado desde [journeyResultsProvider].
    // La pantalla ya no reconstruye `JourneyQuery` a mano ni muta caché
    // dentro de `build` (impl. y spec: `journey_results_view.dart`).
    final results = ref.watch(journeyResultsProvider);
    final query = results.query;
    final result = results.result;
    final cached = results.options;
    final hasResults = results.hasResults;
    final bare = results.bare;
    final replanning = results.replanning;
    final refreshFailed = results.refreshFailed;
    final selectedIndex = results.selectedIndex;
    final mapOption = results.mapOption;
    final mapOrigin = results.mapOrigin;
    final mapDestination = results.mapDestination;
    return Scaffold(
      // El mapa decide su tile (estilo y fondo) mirando el provider propio;
      // todo lo que flota sobre él (tarjeta de extremos, chips, controles,
      // hoja de resultados, panel de estado) usa siempre el tema de la app.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sheetTop = hasResults
              ? _sheetExtent * constraints.maxHeight
              : 0.0;
          // Reserva de mapa arriba: solo hace falta cuando el panel está
          // desplegado; al cerrarlo, el mapa gana casi toda la pantalla.
          final mapTopPad = _panelOpen ? 240.0 : 104.0;
          // Reserva de mapa abajo: la hoja de resultados tapa SU ALTURA REAL
          // (extent arrastrable × altura del mapa), no un valor fijo. Con la
          // reserva fija anterior (260 px) el destino de un viaje largo
          // quedaba DETRÁS de la hoja (que ocupa ~352 px al abrirse): se veían
          // otras paradas en vez del punto marcado. Se acota al 60% del mapa
          // para que subir la hoja hasta el tope no degenere el encuadre.
          final mapBottomPad = hasResults
              ? math.min(sheetTop + 12.0, constraints.maxHeight * 0.6)
              : 140.0;
          // Los controles del mapa quedan anclados ABAJO siempre: abrir el
          // panel de origen/destino NO los mueve (el panel cabe encima del
          // mapa); con resultados, la hoja de resultados los sube.
          final controlsBottom = hasResults ? sheetTop + 12.0 : 24.0;
          final showStatusPanel =
              !hasResults && planner.submitted && planner.ready;
          return Stack(
            children: [
              // 1. Mapa a pantalla completa (SIEMPRE montado).
              Positioned.fill(
                child: LiveMapLayer(
                  mapKey: _journeyMapKey,
                  option: mapOption,
                  origin: mapOrigin,
                  destination: mapDestination,
                  hasResults: hasResults,
                  fitPadding: EdgeInsets.fromLTRB(
                    20,
                    mapTopPad,
                    20,
                    mapBottomPad,
                  ),
                  extraPolylines: planner.routeLines.values.toList(
                    growable: false,
                  ),
                  extraMarkers: [
                    ...planner.routeMarkers.values,
                    ...planner.placeMarkers,
                  ],
                  onEndpointMoved: (isOrigin, point) => _planner
                      .endpointDragged(isOrigin: isOrigin, point: point),
                  // Tocar el pin de origen/destino lo edita: abre el selector
                  // encima del punto actual.
                  onEndpointTapped: (isOrigin) =>
                      _pickFromMap(isOrigin: isOrigin),
                  onPositionChanged: _onMapMoved,
                ),
              ),
              // 2. Tarjeta origen→destino + chips de estado del mapa.
              if (!fullscreen)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Panel desplegable de origen/destino: aparece y se
                      // oculta con una animación de despliegue vertical
                      // (tamaño + flojedad + desvanecido).
                      AnimatedSwitcher(
                        duration: Motion.settle,
                        reverseDuration: Motion.release,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => SizeTransition(
                          sizeFactor: animation,
                          alignment: Alignment.topCenter,
                          child: FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, -0.06),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                        ),
                        child: _panelOpen
                            ? Padding(
                                key: const ValueKey('planner-panel-open'),
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    JourneyPlannerCard(
                                      origin: planner.origin,
                                      destination: planner.destination,
                                      time: planner.time,
                                      ready: planner.ready,
                                      hasResults: hasResults,
                                      onSwap: _swap,
                                      onPickOrigin: () =>
                                          _pickPlace(isOrigin: true),
                                      onPickDestination: () =>
                                          _pickPlace(isOrigin: false),
                                      onPickOriginOnMap: () =>
                                          _pickFromMap(isOrigin: true),
                                      onPickDestinationOnMap: () =>
                                          _pickFromMap(isOrigin: false),
                                      onPickTime: _pickTime,
                                      onSubmit: _submit,
                                      onClear: _clear,
                                    ),
                                    const SizedBox(height: 8),
                                    JourneyPlannerCloseButton(
                                      key: const ValueKey('planner-close'),
                                      onTap: _togglePanel,
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('planner-panel-closed'),
                              ),
                      ),
                      JourneyMapChips(
                        hasResults: hasResults,
                        bare: bare,
                        selectedIndex: selectedIndex,
                        replanning: replanning,
                        refreshFailed: refreshFailed,
                        loadingRoutes: planner.loadingRoutes,
                        onRetryRefresh: () => ref
                            .read(journeyResultsProvider.notifier)
                            .retryRefresh(),
                      ),
                    ],
                  ),
                ),
              // 3. Controles a la derecha (zoom, ubicación, micros, full).
              AnimatedPositioned(
                duration: Motion.fade,
                curve: Curves.easeOutCubic,
                right: 16,
                bottom: fullscreen ? 24.0 : controlsBottom,
                child: LiveMapControls(
                  onZoomIn: () => _journeyMapKey.currentState?.zoomIn(),
                  onZoomOut: () => _journeyMapKey.currentState?.zoomOut(),
                  onOpenMicros: _openMicrosSheet,
                  microsActive: planner.visibleRouteKeys.isNotEmpty,
                  fullscreen: fullscreen,
                  onToggleFullscreen: () =>
                      ref.read(mapFullscreenProvider.notifier).state =
                          !fullscreen,
                ),
              ),
              // 4. Hoja de resultados (cuando hay un viaje planificado).
              if (hasResults && !fullscreen)
                Positioned.fill(
                  child: JourneyResultsSheet(
                    controller: _sheetController,
                    options: cached!,
                    bare: bare,
                    selectedIndex: selectedIndex,
                    expandedIndex: planner.expandedIndex,
                    selectedOption: mapOption,
                    endpointsTooClose: planner.endpointsTooClose,
                    endpointsDistanceM: planner.endpointsDistanceM,
                    onOptionSelected: _selectOption,
                  ),
                ),
              // 5. Zona inferior izquierda: estado de la consulta (si procede)
              //    y la píldora que abre/cierra el panel de origen y destino.
              if (!fullscreen)
                AnimatedPositioned(
                  duration: Motion.fade,
                  curve: Curves.easeOutCubic,
                  left: 16,
                  right: 76,
                  bottom: hasResults ? sheetTop + 12 : 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showStatusPanel && query != null) ...[
                        JourneyStatusPanel(
                          query: query,
                          result: result!,
                          endpointsTooClose: planner.endpointsTooClose,
                          endpointsDistanceM: planner.endpointsDistanceM,
                        ),
                        const SizedBox(height: 12),
                      ],
                      JourneyPlannerTrigger(
                        originLabel: planner.origin?.label,
                        destinationLabel: planner.destination?.label,
                        panelOpen: _panelOpen,
                        onTap: _togglePanel,
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
