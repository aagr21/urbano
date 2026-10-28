import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/map.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/location.dart';
import '../../routes/data/route_models.dart';
import '../../routes/data/route_repository.dart';
import '../data/journey_models.dart';
import '../data/journey_repository.dart';
import 'journey_providers.dart';
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
/// el estado y los gestos del planeador viven aquí, en el `State`.
class JourneyPlannerScreen extends ConsumerStatefulWidget {
  const JourneyPlannerScreen({super.key});

  @override
  ConsumerState<JourneyPlannerScreen> createState() =>
      _JourneyPlannerScreenState();
}

class _JourneyPlannerScreenState extends ConsumerState<JourneyPlannerScreen> {
  // ------------------------------------------------------------------
  // Planeador: origen/destino/hora/planificar
  // ------------------------------------------------------------------
  JourneyPlace? _origin;
  JourneyPlace? _destination;

  /// Puntos que viajan a la consulta de planificación. Los campos muestran
  /// [_origin]/[_destination] (que al MOVER un extremo arrastrado se
  /// actualizan al instante, en cada evento del arrastre); estos se comprometen
  /// con debounce para no re-planificar con micro-movimientos. Selector, swap,
  /// limpiar y planificar los mantienen al día al momento.
  JourneyPlace? _planOrigin;
  JourneyPlace? _planDestination;
  String? _time; // HH:mm
  bool _submitted = false;
  int? _expandedIndex;

  /// `true` cuando el panel de origen/destino está desplegado sobre el mapa.
  /// Arranca cerrado: el mapa es el protagonista y el panel se abre con la
  /// píldora inferior "¿A dónde vas?".
  bool _panelOpen = false;

  /// Opción mostrada en el mapa (índice 0 por defecto).
  int _selectedOptionIndex = 0;

  /// Última respuesta con datos: mantiene el viaje visible mientras se
  /// recalcula tras arrastrar el origen/destino.
  List<JourneyOption>? _lastOptions;

  /// `true` entre el drop del marcador y la aplicación del nuevo punto
  /// (debounce para no re-planificar con micro-movimientos).
  bool _replanPending = false;

  /// Un debounce POR EXTREMO: compartir uno solo hacía que soltar el
  /// destino poco después del origen CANCELARA el cambio del origen (el
  /// marcador se quedaba en el punto soltado, pero el viaje se planificaba
  /// con el punto viejo).
  final _replanOriginDebouncer = Debouncer(
    delay: const Duration(milliseconds: 600),
  );
  final _replanDestinationDebouncer = Debouncer(
    delay: const Duration(milliseconds: 600),
  );

  bool get _ready => _origin != null && _destination != null;

  /// Distancia mínima (línea recta) entre origen y destino para planificar
  /// en transporte: por debajo, caminar es más rápido. Coincide con el guard
  /// del backend (`MIN_TRANSIT_DISTANCE_M` en journey.service.ts).
  static const _minTransitDistanceM = 150.0;

  /// Distancia en línea recta entre los dos puntos elegidos, o `null` si
  /// aún falta alguno.
  double? get _endpointsDistanceM {
    final origin = _origin.pointOrNull;
    final destination = _destination.pointOrNull;
    if (origin == null || destination == null) return null;
    return const Distance().as(
      LengthUnit.Meter,
      LatLng(origin.lat, origin.lon),
      LatLng(destination.lat, destination.lon),
    );
  }

  /// Origen y destino están (casi) en el mismo sitio: no hay viaje que
  /// planificar.
  bool get _endpointsTooClose =>
      (_endpointsDistanceM ?? double.infinity) < _minTransitDistanceM;

  // ------------------------------------------------------------------
  // Mapa (capas de rutas y gemelos del panel)
  // ------------------------------------------------------------------
  final _journeyMapKey = GlobalKey<JourneyResultMapState>();
  final _sheetController = DraggableScrollableController();

  double _sheetExtent = 0.45;

  final Map<String, MapPolyline> _routeLines = {};

  /// Insignia (número/nombre del micro) colocada sobre el punto medio de cada
  /// recorrido activado, igual que en la planificación del viaje.
  final Map<String, MapMarker> _routeMarkers = {};

  /// Recorridos dibujados, por clave `routeId#directionId` (ida y vuelta son
  /// capas independientes).
  final Set<String> _visibleRouteKeys = {};
  bool _loadingRoutes = false;

  /// Momento del ÚLTIMO movimiento de cámara por GESTO del usuario.
  ///
  /// Alimenta la barrera anti-zoom de [_onEndpointMoved]: un "drop" de pin
  /// inmediatamente después de un gesto del mapa (pellizco, pan) es un
  /// fantasma del zoom, nunca un arrastre de verdad (un arrastre legítimo de
  /// pin NO mueve la cámara: la arena se la queda el pin y el mapa está
  /// quieto). Con esta ventana probamos el síntoma aunque exista una vía de
  /// eventos del dispositivo que los tests de widget no pueden simular, y
  /// definimos el recálculo por zoom de RAÍZ.
  DateTime? _lastGestureCameraAt;

  /// Ventana de [_lastGestureCameraAt] que separa "los dedos vienen de un
  /// gesto del mapa" de "el usuario soltó un pin a propósito".
  static const _endpointsDroppingGestureWindow = Duration(milliseconds: 700);

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
    _replanOriginDebouncer.dispose();
    _replanDestinationDebouncer.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Viaje: origen/destino/hora/swap/planificar
  // ------------------------------------------------------------------

  /// El origen/destino se movió en el mapa (durante el arrastre o al
  /// soltarlo): el CAMPO refleja el punto en el ACTO (las coordenadas nuevas
  /// se ven mientras el dedo arrastra), mientras que la consulta de
  /// replanificación se compromete tras un breve debounce (para no
  /// re-planificar con micro-movimientos).
  void _onEndpointMoved({required bool isOrigin, required LatLng point}) {
    final place = JourneyPlacePoint(lat: point.latitude, lon: point.longitude);
    final debouncer = isOrigin
        ? _replanOriginDebouncer
        : _replanDestinationDebouncer;
    // Pellizco de zoom cancelado: el detector devuelve el pin EXACTAMENTE a
    // donde ya estaba (emite el punto de arranque). La consulta no cambia
    // (misma clave del proveedor ⇒ sin refetch), así que se DESARMA el
    // recalculo marcado durante el gesto en vez de programarlo.
    final committedPoint =
        (isOrigin ? _planOrigin : _planDestination).pointOrNull;
    if (committedPoint != null &&
        committedPoint.lat == point.latitude &&
        committedPoint.lon == point.longitude) {
      debouncer.cancel();
      setState(() {
        if (isOrigin) {
          _origin = place;
        } else {
          _destination = place;
        }
        _replanPending = false;
      });
      return;
    }
    // BARRERA ANTI-ZOOM: si la cámara se movió por gesto hace muy poco, este
    // drop del pin se produjo DENTRO de un gesto del mapa (pellizco/pan) y es
    // un fantasma, no un arrastre deliberado: un arrastre real de pin deja la
    // cámara quieta (la arena se la queda el pin). Se desarma el recálculo y
    // el punto se restaura al comprometido.
    final lastGesture = _lastGestureCameraAt;
    if (lastGesture != null &&
        DateTime.now().difference(lastGesture) <
            _endpointsDroppingGestureWindow) {
      debouncer.cancel();
      final restored = (isOrigin ? _planOrigin : _planDestination);
      final restoredPlace = switch (restored) {
        null => place,
        _ => restored,
      };
      setState(() {
        if (isOrigin) {
          _origin = restoredPlace;
        } else {
          _destination = restoredPlace;
        }
        _replanPending = false;
      });
      return;
    }
    debouncer.run(() {
      if (!mounted) return;
      setState(() {
        if (isOrigin) {
          _planOrigin = place;
        } else {
          _planDestination = place;
        }
        _replanPending = false;
        _expandedIndex = null;
        _selectedOptionIndex = 0;
      });
    });
    setState(() {
      if (isOrigin) {
        _origin = place;
      } else {
        _destination = place;
      }
      _replanPending = true;
    });
  }

  /// Descarta los resultados en memoria (nuevo origen/destino/hora).
  void _invalidateResults() {
    _replanOriginDebouncer.cancel();
    _replanDestinationDebouncer.cancel();
    _replanPending = false;
    _lastOptions = null;
  }

  /// Compromete un lugar en el extremo (selector de lugares, "mi ubicación"
  /// o punto del mapa): campo E plan al mismo valor, y limpiar la selección
  /// de resultados (hubo cambio de extremo, lo anterior quedó viejo).
  void _commitPlace(JourneyPlace place, {required bool isOrigin}) {
    _invalidateResults();
    setState(() {
      if (isOrigin) {
        _origin = place;
        _planOrigin = place;
      } else {
        _destination = place;
        _planDestination = place;
      }
      _submitted = false;
      _expandedIndex = null;
      _selectedOptionIndex = 0;
    });
    _framePickedEndpoints();
  }

  /// Selector completo de origen/destino: "Mi ubicación" (GPS), punto del
  /// mapa o un lugar popular de Santa Cruz.
  Future<void> _pickPlace({required bool isOrigin}) async {
    final picked = await showJourneyPlacePickerSheet(
      context,
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
    final params = <String, String>{'title': isOrigin ? 'Origen' : 'Destino'};
    final current = (isOrigin ? _origin : _destination).pointOrNull;
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

  /// Lleva la cámara hasta los extremos elegidos para que sus pines se vean.
  ///
  /// Se ejecuta tras el `setState` de la selección: el mapa ya tiene el
  /// marcador, pero su cámara no se mueve sola (el `center` solo aplica al
  /// crearse), así que un punto elegido lejos del encuadre quedaba invisible.
  void _framePickedEndpoints() {
    final points = <LatLng>[
      for (final place in [_origin.pointOrNull, _destination.pointOrNull])
        if (place case final p?) LatLng(p.lat, p.lon),
    ];
    _journeyMapKey.currentState?.fitToPoints(points);
  }

  Future<void> _pickTime() async {
    final initial = _time == null
        ? TimeOfDay.now()
        : TimeOfDay(
            hour: int.tryParse(_time!.split(':')[0]) ?? TimeOfDay.now().hour,
            minute: int.tryParse(_time!.split(':')[1]) ?? 0,
          );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    _invalidateResults();
    setState(() {
      _time =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _submitted = false;
    });
  }

  /// Envía la consulta, salvo que origen y destino estén en el mismo sitio
  /// (o casi): en ese caso avisa en vez de pedir un viaje imposible.
  void _submit() {
    final distance = _endpointsDistanceM;
    if (distance != null && distance < _minTransitDistanceM) {
      context.showSnack(
        distance < 1
            ? 'El origen y el destino son el mismo punto: mueve uno de ellos.'
            : 'El origen y el destino están a ${distance.round()} m: '
                  'mueve uno de los puntos.',
        isError: true,
      );
      return;
    }
    setState(() {
      // Planifica con lo que los campos muestran AHORA (por si quedó un
      // drop pendiente de aplicar al cambiar la hora u otro campo).
      _planOrigin = _origin;
      _planDestination = _destination;
      _submitted = true;
      _expandedIndex = null;
      // Al planificar, el panel se guarda solo para dejar ver el viaje.
      _panelOpen = false;
    });
  }

  void _swap() {
    _invalidateResults();
    setState(() {
      final origin = _origin;
      _origin = _destination;
      _destination = origin;
      final planOrigin = _planOrigin;
      _planOrigin = _planDestination;
      _planDestination = planOrigin;
      _submitted = false;
      _selectedOptionIndex = 0;
    });
  }

  /// Vuelve al modo exploración: limpia origen/destino y resultados.
  void _clear() {
    _invalidateResults();
    setState(() {
      _origin = null;
      _destination = null;
      _planOrigin = null;
      _planDestination = null;
      _submitted = false;
      _expandedIndex = null;
      _selectedOptionIndex = 0;
    });
  }

  // ------------------------------------------------------------------
  // Mapa: capas de micros (exploración)
  // ------------------------------------------------------------------

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    // Sella el momento del gesto: la ventana de la barrera anti-zoom nace
    // con el gesto, no con el drop del pin.
    _lastGestureCameraAt = DateTime.now();
  }

  /// Dibuja/borra la polilínea de UNA dirección (0 = ida, 1 = vuelta) de un
  /// micro; la forma la sirve `/routes/:id?directionId=`.
  Future<void> _toggleRouteDirection(
    RouteSummary route,
    int directionId,
  ) async {
    final key = microDirectionKey(route.id, directionId);
    if (_visibleRouteKeys.contains(key)) {
      setState(() {
        _visibleRouteKeys.remove(key);
        _routeLines.remove(key);
        _routeMarkers.remove(key);
      });
      return;
    }

    setState(() => _loadingRoutes = true);
    try {
      final detail = await ref
          .read(routeRepositoryProvider)
          .detail(route.id, directionId: directionId);
      final shape = detail.shape;
      if (shape == null || shape.points.length < 2) {
        if (mounted) context.showSnack('Esta ruta no tiene forma cargada.');
        return;
      }
      final points = shape.points;
      final label = route.shortName.trim();
      final color = AppColors.fromHex(detail.color);
      if (!mounted) return;
      setState(() {
        _visibleRouteKeys.add(key);
        _routeLines[key] = MapPolyline(
          points: points,
          color: color,
          outline: true,
        );
        // Insignia del micro ENCIMA de su línea (número o nombre), con el
        // mismo estilo que la planificación del viaje.
        if (label.isNotEmpty) {
          _routeMarkers[key] = MapMarker(
            id: 'micro-route-$key',
            point: routePathMidpoint(points),
            width: routeBadgeWidth(label),
            height: 24,
            iconKey: 'route-badge-${route.id}-$label-${detail.color}',
            child: MapRouteBadge(
              key: ValueKey('micro-route-$key'),
              label: label,
              color: color,
            ),
          );
        }
      });
    } catch (_) {
      if (mounted) {
        context.showSnack(
          'No pudimos cargar el recorrido de esa línea.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRoutes = false);
    }
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
      activeDirectionKeys: _visibleRouteKeys,
      onToggleDirection: _toggleRouteDirection,
      onClearAll: () => setState(() {
        _visibleRouteKeys.clear();
        _routeLines.clear();
        _routeMarkers.clear();
      }),
    ).then((_) {
      // Los micros cambian estado fuera del sheet (recorridos añadidos).
      if (mounted) setState(() {});
    });
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

    JourneyQuery? query;
    AsyncValue<List<JourneyOption>>? result;
    if (_submitted && _ready) {
      query = JourneyQuery(
        origin: _planOrigin ?? _origin!,
        destination: _planDestination ?? _destination!,
        time: _time,
      );
      result = ref.watch(journeyProvider(query));
    }

    // Última respuesta con datos: sirve para no perder el mapa mientras se
    // recalcula el viaje (tras arrastrar origen/destino o cambiar la hora).
    final fresh = result?.valueOrNull;
    if (fresh != null) _lastOptions = fresh;
    final lastOptions = _lastOptions;

    final hasResults = lastOptions != null;
    final bare = hasResults && lastOptions.isEmpty;
    final replanning =
        hasResults && (_replanPending || (result?.isLoading ?? false));
    final refreshFailed =
        hasResults && (result?.hasError ?? false) && fresh == null;
    final selectedIndex = bare || lastOptions == null
        ? 0
        : _selectedOptionIndex.clamp(0, lastOptions.length - 1);
    final mapOption = !hasResults || bare
        ? _bareOption()
        : lastOptions[selectedIndex];

    // El mapa prefiere lo que muestran los CAMPOS (que durante un arrastre de
    // pin van por delante del plan comprometido): así el pin sigue el dedo.
    final pickedOrigin = _origin.pointOrNull;
    final pickedDestination = _destination.pointOrNull;
    final mapOrigin = pickedOrigin ?? query?.originPoint;
    final mapDestination = pickedDestination ?? query?.destinationPoint;

    return Scaffold(
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
              !hasResults && _submitted && _ready && lastOptions == null;

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
                  extraPolylines: _routeLines.values.toList(growable: false),
                  extraMarkers: _routeMarkers.values.toList(growable: false),
                  onEndpointMoved: (isOrigin, point) =>
                      _onEndpointMoved(isOrigin: isOrigin, point: point),
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
                        duration: const Duration(milliseconds: 300),
                        reverseDuration: const Duration(milliseconds: 240),
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
                                      origin: _origin,
                                      destination: _destination,
                                      time: _time,
                                      ready: _ready,
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
                        loadingRoutes: _loadingRoutes,
                        onRetryRefresh: () {
                          final activeQuery = query;
                          if (activeQuery != null) {
                            ref.invalidate(journeyProvider(activeQuery));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              // 3. Controles a la derecha (zoom, ubicación, micros, full).
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                right: 16,
                bottom: fullscreen ? 24.0 : controlsBottom,
                child: LiveMapControls(
                  onZoomIn: () => _journeyMapKey.currentState?.zoomIn(),
                  onZoomOut: () => _journeyMapKey.currentState?.zoomOut(),
                  onOpenMicros: _openMicrosSheet,
                  microsActive: _visibleRouteKeys.isNotEmpty,
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
                    options: lastOptions,
                    bare: bare,
                    selectedIndex: selectedIndex,
                    expandedIndex: _expandedIndex,
                    selectedOption: bare || lastOptions.isEmpty
                        ? _bareOption()
                        : lastOptions[selectedIndex],
                    endpointsTooClose: _endpointsTooClose,
                    endpointsDistanceM: _endpointsDistanceM,
                    onOptionSelected: _selectOption,
                  ),
                ),
              // 5. Zona inferior izquierda: estado de la consulta (si procede)
              //    y la píldora que abre/cierra el panel de origen y destino.
              if (!fullscreen)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
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
                          endpointsTooClose: _endpointsTooClose,
                          endpointsDistanceM: _endpointsDistanceM,
                        ),
                        const SizedBox(height: 12),
                      ],
                      JourneyPlannerTrigger(
                        originLabel: _origin?.label,
                        destinationLabel: _destination?.label,
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

  /// El usuario marcó una opción en la hoja de resultados (o la expandió).
  void _selectOption(int itemIndex) {
    setState(() {
      final collapsing = _expandedIndex == itemIndex;
      _selectedOptionIndex = itemIndex;
      _expandedIndex = collapsing ? null : itemIndex;
    });
  }

  /// Opción "vacía" para mostrar el mapa (con origen/destino) cuando la
  /// respuesta no trae ninguna ruta.
  static JourneyOption _bareOption() => const JourneyOption(
    type: JourneyType.direct,
    departAt: '',
    arriveAt: '',
    durationMinutes: 0,
    legs: [],
  );
}
