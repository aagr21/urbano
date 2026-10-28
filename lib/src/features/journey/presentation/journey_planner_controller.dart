import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/map.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/debouncer.dart';
import '../../routes/data/route_models.dart';
import '../../routes/data/route_repository.dart';
import 'journey_providers.dart';
import 'widgets/journey_micros_sheet.dart';
import 'widgets/journey_result_map.dart';

/// Estado completo del **planeador de viaje**: los lugares marcados, la
/// consulta comprometida (con el par planificado separado del mostrado), la
/// selección de opción del panel de resultados y las capas de micros del modo
/// exploración.
///
/// Vive en un [Notifier] (no en el `State` de la pantalla) para que la lógica
/// del viaje sea UI-agnostic, testeable sin widgets y la pantalla sea solo el
/// cableado de callbacks. Los campos `origin`/`destination` son lo que
/// muestran los campos; los `plan*` son los puntos que viajan a la consulta:
/// al arrastrar un extremo los campos se actualizan al instante (en cada
/// evento del arrastre) y los `plan*` se comprometen con debounce.
class JourneyPlannerState {
  const JourneyPlannerState({
    this.origin,
    this.destination,
    this.planOrigin,
    this.planDestination,
    this.time,
    this.submitted = false,
    this.replanPending = false,
    this.selectedOptionIndex = 0,
    this.expandedIndex,
    this.routeLines = const {},
    this.routeMarkers = const {},
    this.visibleRouteKeys = const {},
    this.loadingRoutes = false,
  });

  /// Lugares que muestran los campos.
  final JourneyPlace? origin;
  final JourneyPlace? destination;

  /// Puntos que viajan a la consulta de planificación. Selector, swap,
  /// limpiar y planificar los mantienen al día al momento.
  final JourneyPlace? planOrigin;
  final JourneyPlace? planDestination;

  /// Hora de salida personalizada (`HH:mm`), o `null` = ahora.
  final String? time;

  /// `true` después de planificar: al estado se añade la hoja de resultados.
  final bool submitted;

  /// `true` entre el drop del marcador y la aplicación del nuevo punto
  /// (debounce para no re-planificar con micro-movimientos).
  final bool replanPending;

  /// Opción mostrada en el mapa (índice 0 por defecto).
  final int selectedOptionIndex;

  /// Índice de opción expandida en la hoja de resultados, `null` = ninguna.
  final int? expandedIndex;

  /// Polilíneas de exploración (micros del panel), por clave
  /// `routeId#directionId`.
  final Map<String, MapPolyline> routeLines;

  /// Insignia (número/nombre del micro) colocada sobre el punto medio de cada
  /// recorrido activado, igual que en la planificación del viaje.
  final Map<String, MapMarker> routeMarkers;

  /// Recorridos dibujados, por clave igual que arriba (ida y vuelta son capas
  /// independientes).
  final Set<String> visibleRouteKeys;

  /// `true` mientras una polilínea de micro se descarga.
  final bool loadingRoutes;

  /// `true` cuando el panel de origen/destino tiene los dos extremos listos.
  bool get ready => origin != null && destination != null;

  /// Distancia en línea recta entre los dos puntos elegidos, o `null` si
  /// aún falta alguno.
  double? get endpointsDistanceM {
    final src = origin.pointOrNull;
    final dst = destination.pointOrNull;
    if (src == null || dst == null) return null;
    return const Distance().as(
      LengthUnit.Meter,
      LatLng(src.lat, src.lon),
      LatLng(dst.lat, dst.lon),
    );
  }

  /// Origen y destino están (casi) en el mismo sitio: no hay viaje que
  /// planificar.
  bool get endpointsTooClose =>
      (endpointsDistanceM ?? double.infinity) < minTransitDistanceM;

  /// Distancia mínima (línea recta) entre origen y destino para planificar
  /// en transporte: por debajo, caminar es más rápido. Coincide con el guard
  /// del backend (`MIN_TRANSIT_DISTANCE_M` en journey.service.ts).
  static const double minTransitDistanceM = 150.0;

  /// Copia con cambios: cada mutación produce un objeto nuevo (el [Notifier]
  /// avisa por identidad, no por igualdad profunda).
  JourneyPlannerState copyWith({
    JourneyPlace? origin,
    bool clearOrigin = false,
    JourneyPlace? destination,
    bool clearDestination = false,
    JourneyPlace? planOrigin,
    bool clearPlanOrigin = false,
    JourneyPlace? planDestination,
    bool clearPlanDestination = false,
    String? time,
    bool clearTime = false,
    bool? submitted,
    bool? replanPending,
    int? selectedOptionIndex,
    int? expandedIndex,
    bool clearExpandedIndex = false,
    Map<String, MapPolyline>? routeLines,
    Map<String, MapMarker>? routeMarkers,
    Set<String>? visibleRouteKeys,
    bool? loadingRoutes,
  }) {
    return JourneyPlannerState(
      origin: clearOrigin ? null : (origin ?? this.origin),
      destination: clearDestination ? null : (destination ?? this.destination),
      planOrigin: clearPlanOrigin ? null : (planOrigin ?? this.planOrigin),
      planDestination: clearPlanDestination
          ? null
          : (planDestination ?? this.planDestination),
      time: clearTime ? null : (time ?? this.time),
      submitted: submitted ?? this.submitted,
      replanPending: replanPending ?? this.replanPending,
      selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
      expandedIndex: clearExpandedIndex
          ? null
          : (expandedIndex ?? this.expandedIndex),
      routeLines: routeLines ?? this.routeLines,
      routeMarkers: routeMarkers ?? this.routeMarkers,
      visibleRouteKeys: visibleRouteKeys ?? this.visibleRouteKeys,
      loadingRoutes: loadingRoutes ?? this.loadingRoutes,
    );
  }
}

/// Proveedor del estado del planeador: **vivo con la app** (no `autoDispose`)
/// igual que antes lo era el `State` de la pantalla, que sobrevivía a los
/// cambios de pestaña del shell con ambas ramas montadas. El `State` de la
/// pantalla AHORA solo lleva la UI propia (mapa `GlobalKey`, hoja arrastrable,
/// panel abierto); todo lo demás vive aquí y sobreviviría incluso a un
/// remontaje de la pantalla.
final journeyPlannerControllerProvider =
    NotifierProvider<JourneyPlannerController, JourneyPlannerState>(
      JourneyPlannerController.new,
    );

/// Resultado de [JourneyPlannerController.toggleRouteDirection]: la pantalla
/// mapea los dos casos con problema a snacks de UI.
enum MicroRouteToggleOutcome {
  /// El recorrido se dibujó (encender).
  toggledOn,

  /// El recorrido se borró (apagar).
  toggledOff,

  /// La ruta no tiene `shape` en el feed: nada que dibujar.
  missingShape,

  /// Falló la descarga del detalle (red/backend).
  failed,
}

/// Controlador del **planeador de viajes**: toda la lógica de la pestaña
/// Viaje que no es dibujar widgets — marcar extremos (con el debounce y la
/// barrera anti-zoom de los arrastres de pines), elegir lugares, hora, swap,
/// planificar y las capas de micros del panel.
///
/// Desacoplado del `State` de la pantalla: aquí el estado es dato puro
/// (testeable sin `flutter_test`) y en la pantalla queda solo el cableado
/// (GlobalKey del mapa, hoja arrastrable, panel abierto).
class JourneyPlannerController extends Notifier<JourneyPlannerState> {
  /// Un debounce POR EXTREMO: compartir uno solo hacía que soltar el
  /// destino poco después del origen CANCELARA el cambio del origen (el
  /// marcador se quedaba en el punto soltado, pero el viaje se planificaba
  /// con el punto viejo).
  late final Debouncer _replanOriginDebouncer = Debouncer(
    delay: const Duration(milliseconds: 600),
  );
  late final Debouncer _replanDestinationDebouncer = Debouncer(
    delay: const Duration(milliseconds: 600),
  );

  /// Momento del ÚLTIMO movimiento de cámara por GESTO del usuario.
  ///
  /// Alimenta la barrera anti-zoom de [endpointDragged]: un "drop" de pin
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

  /// `true` cuando el proveedor ya no existe: los callbacks difiere (debounce)
  /// no deben escribir estado de un notifier muerto.
  bool _disposed = false;

  @override
  JourneyPlannerState build() {
    // Proveedor «viviendo siempre» (igual que el State de la pantalla, que
    // sobrevive a los cambios de pestaña del shell): el dispose de los
    // debouncers se registra para el cierre del ProviderContainer.
    ref.onDispose(() {
      _disposed = true;
      _replanOriginDebouncer.dispose();
      _replanDestinationDebouncer.dispose();
    });
    return const JourneyPlannerState();
  }

  // ------------------------------------------------------------------
  // Mapa: movimiento de cámara (barrera anti-zoom)
  // ------------------------------------------------------------------

  /// La cámara se movió POR GESTO del usuario: sella el momento para la
  /// barrera anti-zoom de [endpointDragged] (un drop de pin inmediatamente
  /// después es fantasma del zoom, no arrastre deliberado). Es mutación
  /// interna: el reloj no es dato de UI y no debe reconstruir la pantalla.
  void noteGestureCameraMoved() => _lastGestureCameraAt = DateTime.now();

  // ------------------------------------------------------------------
  // Extremos marcados en el mapa (arrastrar pines)
  // ------------------------------------------------------------------

  /// El origen/destino se movió en el mapa (durante el arrastre o al
  /// soltarlo): el CAMPO refleja el punto en el ACTO (las coordenadas nuevas
  /// se ven mientras el dedo arrastra), mientras que la consulta de
  /// replanificación se compromete tras un breve debounce (para no
  /// re-planificar con micro-movimientos).
  void endpointDragged({required bool isOrigin, required LatLng point}) {
    final place = JourneyPlacePoint(lat: point.latitude, lon: point.longitude);
    final debouncer = isOrigin
        ? _replanOriginDebouncer
        : _replanDestinationDebouncer;
    // Pellizco de zoom cancelado: el detector devuelve el pin EXACTAMENTE a
    // donde ya estaba (emite el punto de arranque). La consulta no cambia
    // (misma clave del proveedor ⇒ sin refetch), así que se DESARMA el
    // recalculo marcado durante el gesto en vez de programarlo.
    final committed =
        (isOrigin ? state.planOrigin : state.planDestination).pointOrNull;
    if (committed != null &&
        committed.lat == point.latitude &&
        committed.lon == point.longitude) {
      debouncer.cancel();
      _setEndpointFields(
        isOrigin: isOrigin,
        value: place,
        replanPending: false,
      );
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
      final restored = isOrigin ? state.planOrigin : state.planDestination;
      _setEndpointFields(
        isOrigin: isOrigin,
        value: restored,
        replanPending: false,
      );
      return;
    }
    debouncer.run(() {
      if (_disposed) return;
      state = state.copyWith(
        planOrigin: isOrigin ? place : null,
        planDestination: isOrigin ? null : place,
        replanPending: false,
        clearExpandedIndex: true,
        selectedOptionIndex: 0,
      );
    });
    _setEndpointFields(isOrigin: isOrigin, value: place, replanPending: true);
  }

  /// Al solo cambia el campo del extremo (y el tinte de "recalculando"):
  /// cero lógica de selección dentro.
  void _setEndpointFields({
    required bool isOrigin,
    required JourneyPlace? value,
    required bool replanPending,
  }) {
    state = state.copyWith(
      origin: isOrigin ? value : null,
      clearOrigin: isOrigin && value == null,
      destination: isOrigin ? null : value,
      clearDestination: !isOrigin && value == null,
      replanPending: replanPending,
    );
  }

  // ------------------------------------------------------------------
  // Lugares del selector, hora, swap, planificar, limpiar
  // ------------------------------------------------------------------

  /// Compromete un lugar en el extremo (selector de lugares, "mi ubicación"
  /// o punto del mapa): campo Y plan al mismo valor, y limpiar la selección
  /// de resultados (hubo cambio de extremo, lo anterior quedó viejo). El
  /// extremo NO tocado se conserva: elegir destino no borra el origen.
  /// Sin flags `clear*`: `copyWith(null)` conserva, que es justo lo que
  /// queremos aquí.
  void setPlace(JourneyPlace place, {required bool isOrigin}) {
    _cancelDebouncers();
    state = state.copyWith(
      origin: isOrigin ? place : null,
      destination: isOrigin ? null : place,
      planOrigin: isOrigin ? place : null,
      planDestination: isOrigin ? null : place,
      submitted: false,
      replanPending: false,
      clearExpandedIndex: true,
      selectedOptionIndex: 0,
    );
  }

  /// Cambia la hora de salida: la planificación vigente queda vieja.
  void setTime(String time) {
    _cancelDebouncers();
    state = state.copyWith(time: time, submitted: false, replanPending: false);
  }

  /// Intercambia origen y destino (el plan con ellos). Los `clear*` cubren
  /// el lado que puede estar sin marcar (`copyWith(null)` NO limpia).
  void swap() {
    _cancelDebouncers();
    final origin = state.origin;
    final destination = state.destination;
    final planOrigin = state.planOrigin;
    final planDestination = state.planDestination;
    state = state.copyWith(
      origin: destination,
      clearOrigin: destination == null,
      destination: origin,
      clearDestination: origin == null,
      planOrigin: planDestination,
      clearPlanOrigin: planDestination == null,
      planDestination: planOrigin,
      clearPlanDestination: planOrigin == null,
      submitted: false,
      replanPending: false,
      selectedOptionIndex: 0,
    );
  }

  /// Envía la consulta: planifica con lo que los campos muestran AHORA (por
  /// si quedó un drop pendiente de aplicar al cambiar la hora u otro campo).
  /// La pantalla decide antes si los extremos están demasiado cerca para
  /// pedir un viaje imposible ([JourneyPlannerState.endpointsTooClose]).
  void submit() {
    state = state.copyWith(
      planOrigin: state.origin,
      clearPlanOrigin: state.origin == null,
      planDestination: state.destination,
      clearPlanDestination: state.destination == null,
      submitted: true,
      clearExpandedIndex: true,
    );
  }

  /// Vuelve al modo exploración: limpia origen/destino y resultados.
  void clear() {
    _cancelDebouncers();
    state = const JourneyPlannerState();
  }

  /// Descarta los resultados pendientes de aplicar (nuevo origen/destino/
  /// hora): el modo "recalculando" muere, y por lo tanto también los
  /// lids del debounce.
  void _cancelDebouncers() {
    _replanOriginDebouncer.cancel();
    _replanDestinationDebouncer.cancel();
  }

  // ------------------------------------------------------------------
  // Selección de opciones del panel de resultados
  // ------------------------------------------------------------------

  /// El usuario marcó una opción en la hoja de resultados (o la expandió).
  void selectOption(int itemIndex) {
    final collapsing = state.expandedIndex == itemIndex;
    state = state.copyWith(
      selectedOptionIndex: itemIndex,
      expandedIndex: itemIndex,
      clearExpandedIndex: collapsing,
    );
  }

  // ------------------------------------------------------------------
  // Micros: capas del modo exploración (panel de líneas)
  // ------------------------------------------------------------------

  /// Dibuja/borra la polilínea de UNA dirección (0 = ida, 1 = vuelta) de un
  /// micro; la forma la sirve `/routes/:id?directionId=`. Devuelve el
  /// resultado para que la pantalla mapee los snacks.
  Future<MicroRouteToggleOutcome> toggleRouteDirection(
    RouteSummary route,
    int directionId,
  ) async {
    final key = microDirectionKey(route.id, directionId);
    if (state.visibleRouteKeys.contains(key)) {
      state = state.copyWith(
        visibleRouteKeys: {...state.visibleRouteKeys}..remove(key),
        routeLines: {...state.routeLines}..remove(key),
        routeMarkers: {...state.routeMarkers}..remove(key),
      );
      return MicroRouteToggleOutcome.toggledOff;
    }

    state = state.copyWith(loadingRoutes: true);
    try {
      final detail = await ref
          .read(routeRepositoryProvider)
          .detail(route.id, directionId: directionId);
      final shape = detail.shape;
      if (shape == null || shape.points.length < 2) {
        return MicroRouteToggleOutcome.missingShape;
      }
      final points = shape.points;
      final label = route.shortName.trim();
      final color = AppColors.fromHex(detail.color);
      final marker = MapMarker(
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
      state = state.copyWith(
        visibleRouteKeys: {...state.visibleRouteKeys}..add(key),
        routeLines: {
          ...state.routeLines,
          key: MapPolyline(points: points, color: color, outline: true),
        },
        // Insignia del micro ENCIMA de su línea (número o nombre), con el
        // mismo estilo que la planificación del viaje.
        routeMarkers: {
          ...state.routeMarkers,
          if (label.isNotEmpty) key: marker,
        },
      );
      return MicroRouteToggleOutcome.toggledOn;
    } catch (_) {
      return MicroRouteToggleOutcome.failed;
    } finally {
      if (!_disposed) {
        state = state.copyWith(loadingRoutes: false);
      }
    }
  }

  /// Apaga TODAS las capas de micros («Limpiar» del panel).
  void clearMicros() {
    if (state.visibleRouteKeys.isEmpty) return;
    state = state.copyWith(
      visibleRouteKeys: const {},
      routeLines: const {},
      routeMarkers: const {},
    );
  }
}
