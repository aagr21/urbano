import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/map/map.dart';
import '../../../core/utils/extensions.dart';
import '../application/journey_leg_routes.dart';
import '../application/trip_history_controller.dart';
import 'journey_planner_controller.dart';
import 'journey_providers.dart';
import 'journey_results_view.dart';
import 'widgets/journey_live_map.dart';
import 'widgets/journey_loading_overlay.dart';
import 'widgets/journey_map_chips.dart';
import 'widgets/journey_result_map.dart';
import 'widgets/journey_results_sheet.dart';
import 'widgets/pick_endpoint_from_map.dart';

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
  double _mapBearing = 0;

  /// Firma del último viaje que ya se anotó en el historial del home.
  ///
  /// Evita reescribir la fila en cada rebuild de `journeyResultsProvider`
  /// (selección de opción, recálculo, cambio de capa…): solo un viaje con otra
  /// consulta se vuelve a anotar.
  String? _historySignature;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetExtentChanged);
    // Primera búsqueda fallida: la carga se retira (ver `firstSearchFailed`
    // en `build`) y aquí se dice por qué, una sola vez por fallo.
    ref.listenManual(journeyResultsProvider, (previous, next) {
      bool failed(JourneyResultsView? view) =>
          view != null && !view.hasResults && (view.result?.hasError ?? false);
      if (failed(next) && !failed(previous) && mounted) {
        context.showSnack(
          'No pudimos calcular el viaje. Revisa tu conexión e inténtalo de '
          'nuevo.',
          isError: true,
        );
      }
    });
    // «Tus viajes recientes» del home: en cuanto hay una respuesta fresca con
    // opciones, el destino queda anotado. La firma de la consulta evita
    // reescribir la fila en cada rebuild (elegir otra opción, replanificar por
    // arrastre, cambiar de capa…).
    ref.listenManual(journeyResultsProvider, (_, next) {
      final query = next.query;
      final options = next.options;
      if (query == null || options == null || options.isEmpty) return;
      final signature =
          '${query.originPoint}|${query.destinationPoint}|${query.time}';
      if (signature == _historySignature) return;
      _historySignature = signature;
      final index = next.selectedIndex.clamp(0, options.length - 1);
      ref
          .read(tripHistoryControllerProvider.notifier)
          .record(
            destination: query.destination,
            durationMinutes: options[index].durationMinutes,
          );
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
  // Viaje: editar un extremo tocando su pin
  // ------------------------------------------------------------------
  /// Tocar un pin abre el selector encima de ese punto (ver
  /// [mapPickerLocation]) y el extremo pasa a ser EL PUNTO elegido (nunca una
  /// parada GTFS).
  Future<void> _pickFromMap({required bool isOrigin}) async {
    final planner = ref.read(journeyPlannerControllerProvider);
    final place = await pickEndpointFromMap(
      context: context,
      ref: ref,
      title: isOrigin ? 'Origen' : 'Destino',
      currentPoint:
          (isOrigin ? planner.origin : planner.destination).pointOrNull,
    );
    if (place == null || !mounted) return;
    _commitPlace(place, isOrigin: isOrigin);
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

  /// «Quitar resultados»: limpia origen/destino y resultados y vuelve a
  /// Inicio. Viaje ya no tiene panel ni globo para armar otro viaje (eso vive
  /// en «¿A dónde vas?» de la portada), así que quedarse en un mapa vacío era
  /// un callejón sin salida.
  void _clear() {
    _planner.clear();
    context.go('/');
  }

  /// El usuario marcó una opción en la hoja de resultados (o la expandió).
  void _selectOption(int itemIndex) => _planner.selectOption(itemIndex);

  // ------------------------------------------------------------------
  // Mapa: movimiento de cámara
  // ------------------------------------------------------------------
  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if ((_mapBearing - camera.bearing).abs() > 0.1) {
      setState(() => _mapBearing = camera.bearing);
    }
    if (!hasGesture) return;
    // Sella el momento del gesto: la ventana de la barrera anti-zoom nace
    // con el gesto, no con el drop del pin (la ventana vive en el controller).
    _planner.noteGestureCameraMoved();
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
    // La barra del sistema no la decide esta pantalla: el mapa ocupa el
    // cuerpo entero y los paneles flotan encima.
    final mediaQuery = MediaQuery.of(context);
    final planner = ref.watch(journeyPlannerControllerProvider);
    // Vista de resultados: todo lo derivado del viaje (consulta efectiva,
    // caché con su regla de frescura, selección acotada, opción del mapa,
    // extremos para el mapa) llega contado desde [journeyResultsProvider].
    // La pantalla ya no reconstruye `JourneyQuery` a mano ni muta caché
    // dentro de `build` (impl. y spec: `journey_results_view.dart`).
    final results = ref.watch(journeyResultsProvider);
    final query = results.query;
    final cached = results.options;
    final hasResults = results.hasResults;
    final bare = results.bare;
    final replanning = results.replanning;
    final refreshFailed = results.refreshFailed;
    final selectedIndex = results.selectedIndex;
    final mapOption = results.mapOption;
    final mapOrigin = results.mapOrigin;
    final mapDestination = results.mapDestination;
    // Primera búsqueda fallida (sin viaje anterior que conservar): la carga
    // se retira (un snack dice por qué) y los pines siguen tocables para
    // corregir origen/destino. Antes el overlay se quedaba encima para siempre.
    final firstSearchFailed =
        !hasResults && (results.result?.hasError ?? false);
    final showStatusPanel =
        planner.submitted &&
        planner.ready &&
        ((!hasResults && !firstSearchFailed) || replanning);
    final loading = showStatusPanel && query != null;
    // El sheet de resultados desaparece mientras el backend calcula (primera
    // búsqueda o recálculo) para que el overlay de carga sea el protagonista.
    final sheetVisible = hasResults && !loading;
    return Scaffold(
      // El mapa decide su tile (estilo y fondo) mirando el provider propio;
      // todo lo que flota sobre él (tarjeta de extremos, chips, controles,
      // hoja de resultados, panel de estado) usa siempre el tema de la app.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sheetTop = sheetVisible
              ? _sheetExtent * constraints.maxHeight
              : 0.0;
          // Reserva de mapa arriba: solo los chips de estado.
          const mapTopPad = 104.0;
          // Reserva de mapa abajo: la hoja de resultados tapa SU ALTURA REAL
          // (extent arrastrable × altura del mapa), no un valor fijo. Con la
          // reserva fija anterior (260 px) el destino de un viaje largo
          // quedaba DETRÁS de la hoja (que ocupa ~352 px al abrirse): se veían
          // otras paradas en vez del punto marcado. Se acota al 60% del mapa
          // para que subir la hoja hasta el tope no degenere el encuadre.
          final mapBottomPad = sheetVisible
              ? math.min(sheetTop + 12.0, constraints.maxHeight * 0.6)
              : 140.0;
          // Borde inferior seguro: la pantalla se dibuja edge-to-edge y el
          // gesto/barra del sistema ocupa sus últimos píxeles. `viewPadding`
          // conserva esa zona (y vale 0 en los tests, así que no mueve nada).
          final bottomBase = math.max(
            24.0,
            mediaQuery.viewPadding.bottom + 16.0,
          );
          // Los controles del mapa quedan anclados ABAJO; con resultados, la
          // hoja de resultados los sube.
          final controlsBottom = sheetVisible ? sheetTop + 12.0 : bottomBase;
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
                  onEndpointMoved: (isOrigin, point) => _planner
                      .endpointDragged(isOrigin: isOrigin, point: point),
                  // Tocar el pin de origen/destino lo edita: abre el selector
                  // encima del punto actual.
                  onEndpointTapped: (isOrigin) =>
                      _pickFromMap(isOrigin: isOrigin),
                  onPositionChanged: _onMapMoved,
                ),
              ),
              // 2. Chips de estado del mapa (opción en el mapa, recálculo).
              //    Viaje NO tiene panel de origen/destino ni globo «¿A dónde
              //    vas?»: el viaje se arma en la portada y aquí se edita
              //    tocando o arrastrando los pines.
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    JourneyMapChips(
                      hasResults: hasResults,
                      bare: bare,
                      selectedIndex: selectedIndex,
                      replanning: replanning,
                      refreshFailed: refreshFailed,
                      onRetryRefresh: () => ref
                          .read(journeyResultsProvider.notifier)
                          .retryRefresh(),
                    ),
                  ],
                ),
              ),
              // 3. Controles a la derecha (volver, zoom, ubicación, capa).
              AnimatedPositioned(
                duration: Motion.fade,
                curve: Curves.easeOutCubic,
                right: 16,
                bottom: controlsBottom,
                child: LiveMapControls(
                  onZoomIn: () => _journeyMapKey.currentState?.zoomIn(),
                  onZoomOut: () => _journeyMapKey.currentState?.zoomOut(),
                  bearing: _mapBearing,
                  onResetNorth: () {
                    _journeyMapKey.currentState?.resetNorth();
                    if (mounted) setState(() => _mapBearing = 0);
                  },
                  onBack: () => context.go('/'),
                ),
              ),
              // 4. Hoja de resultados (cuando hay un viaje planificado y no
              //    se está recalculando: durante la carga el sheet anterior
              //    desaparece para que el overlay sea el protagonista).
              if (sheetVisible)
                Positioned.fill(
                  // Las fotos de los micros llegan DESPUÉS que `/journey`
                  // (`/routes/:id` por línea): solo la hoja escucha ese
                  // provider, así su llegada no reconstruye mapa ni panel.
                  child: Consumer(
                    builder: (context, ref, _) => JourneyResultsSheet(
                      controller: _sheetController,
                      options: cached!,
                      bare: bare,
                      selectedIndex: selectedIndex,
                      expandedIndex: planner.expandedIndex,
                      selectedOption: mapOption,
                      endpointsTooClose: planner.endpointsTooClose,
                      endpointsDistanceM: planner.endpointsDistanceM,
                      onOptionSelected: _selectOption,
                      onClear: _clear,
                      routes:
                          ref
                              .watch(
                                journeyLegRoutesProvider(
                                  journeyLegRoutesKey(cached),
                                ),
                              )
                              .value ??
                          const {},
                    ),
                  ),
                ),
              // 5. Overlay de carga a pantalla completa (cuando el backend
              //    está calculando el viaje: primera búsqueda o recálculo).
              if (loading)
                const Positioned.fill(child: JourneyLoadingOverlay()),
            ],
          );
        },
      ),
    );
  }
}
