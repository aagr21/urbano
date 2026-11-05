import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/map.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/debouncer.dart';
import '../../routes/data/route_models.dart';
import '../../routes/data/route_repository.dart';
import '../../stops/data/stop_search_models.dart';
import '../domain/endpoint_drag.dart';
import '../domain/journey_place.dart';
import '../domain/journey_planner_state.dart';
import '../presentation/journey_markers.dart';

export '../domain/journey_planner_state.dart';

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

/// Controlador del **planeador de viajes**: traduce gestos y acciones de UI
/// a [JourneyPlannerState]. La política de drop (debounce / barrera anti-zoom)
/// vive en dominio ([decideEndpointDrag]); aquí quedan el reloj, los
/// debouncers y el I/O de capas de micros.
///
/// Desacoplado del `State` de la pantalla: el estado es dato puro y en la
/// pantalla queda solo el cableado (GlobalKey del mapa, hoja, panel abierto).
class JourneyPlannerController extends Notifier<JourneyPlannerState> {
  /// Un debounce POR EXTREMO: compartir uno solo hacía que soltar el
  /// destino poco después del origen CANCELARA el cambio del origen (el
  /// marcador se quedaba en el punto soltado, pero el viaje se planificaba
  /// con el punto viejo).
  late final Debouncer _replanOriginDebouncer = Debouncer(
    delay: JourneyPlannerTiming.replanDebounce,
  );
  late final Debouncer _replanDestinationDebouncer = Debouncer(
    delay: JourneyPlannerTiming.replanDebounce,
  );

  /// Momento del ÚLTIMO movimiento de cámara por GESTO del usuario.
  ///
  /// Alimenta la barrera anti-zoom de [endpointDragged]: un "drop" de pin
  /// inmediatamente después de un gesto del mapa (pellizco, pan) es un
  /// fantasma del zoom, nunca un arrastre de verdad (un arrastre legítimo de
  /// pin NO mueve la cámara: la arena se la queda el pin y el mapa está
  /// quieto).
  DateTime? _lastGestureCameraAt;

  /// `true` cuando el proveedor ya no existe: los callbacks diferidos
  /// (debounce) no deben escribir estado de un notifier muerto.
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
  /// barrera anti-zoom de [endpointDragged]. Es mutación interna: el reloj
  /// no es dato de UI y no debe reconstruir la pantalla.
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
    final decision = decideEndpointDrag(
      lat: point.latitude,
      lon: point.longitude,
      committed:
          (isOrigin ? state.planOrigin : state.planDestination).pointOrNull,
      now: DateTime.now(),
      lastGestureAt: _lastGestureCameraAt,
      gestureWindow: JourneyPlannerTiming.gestureDropWindow,
    );
    switch (decision) {
      case EndpointDragDecision.cancelReplan:
        debouncer.cancel();
        _setEndpointFields(
          isOrigin: isOrigin,
          value: place,
          replanPending: false,
        );
        return;
      case EndpointDragDecision.discardGestureGhost:
        debouncer.cancel();
        final restored = isOrigin ? state.planOrigin : state.planDestination;
        _setEndpointFields(
          isOrigin: isOrigin,
          value: restored,
          replanPending: false,
        );
        return;
      case EndpointDragDecision.scheduleReplan:
        debouncer.run(() {
          if (_disposed) return;
          state = state.copyWith(
            planOrigin: isOrigin ? place : keepJourneyField,
            planDestination: isOrigin ? keepJourneyField : place,
            replanPending: false,
            expandedIndex: null,
            selectedOptionIndex: 0,
          );
        });
        _setEndpointFields(
          isOrigin: isOrigin,
          value: place,
          replanPending: true,
        );
    }
  }

  /// Al solo cambia el campo del extremo (y el tinte de "recalculando"):
  /// cero lógica de selección dentro.
  void _setEndpointFields({
    required bool isOrigin,
    required JourneyPlace? value,
    required bool replanPending,
  }) {
    state = state.copyWith(
      origin: isOrigin ? value : keepJourneyField,
      destination: isOrigin ? keepJourneyField : value,
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
  /// Con el copyWith por sentinel, el lado no tocado va omitido.
  ///
  /// Si YA había un viaje planificado (`submitted`) y tras el cambio siguen
  /// listos los dos extremos (y no caen uno encima del otro), se CONSERVA
  /// `submitted`: modificar un punto vuelve a calcular el viaje en vez de
  /// regresar al modo exploración y obligar a pulsar «Viajar» de nuevo. Es la
  /// misma regla que ya aplica el arrastre del pin ([endpointDragged]).
  /// Sin viaje vigente (aún se están eligiendo los extremos) o con los puntos
  /// demasiado cerca, `submitted` queda `false` y la consulta muere, como antes.
  void setPlace(JourneyPlace place, {required bool isOrigin}) {
    _cancelDebouncers();
    final prospective = JourneyPlannerState(
      origin: isOrigin ? place : state.origin,
      destination: isOrigin ? state.destination : place,
    );
    final keepSubmitted =
        state.submitted && prospective.ready && !prospective.endpointsTooClose;
    state = state.copyWith(
      origin: isOrigin ? place : keepJourneyField,
      destination: isOrigin ? keepJourneyField : place,
      planOrigin: isOrigin ? place : keepJourneyField,
      planDestination: isOrigin ? keepJourneyField : place,
      submitted: keepSubmitted,
      replanPending: false,
      expandedIndex: null,
      selectedOptionIndex: 0,
    );
  }

  /// Cambia la hora de salida: la planificación vigente queda vieja.
  void setTime(String time) {
    _cancelDebouncers();
    state = state.copyWith(time: time, submitted: false, replanPending: false);
  }

  /// Intercambia origen y destino (el plan con ellos). `null` limpia
  /// el lado que quedó sin punto: con el copyWith por sentinel
  /// (`null` = LIMPIAR) no hace falta ningún flag.
  void swap() {
    _cancelDebouncers();
    final origin = state.origin;
    final destination = state.destination;
    final planOrigin = state.planOrigin;
    final planDestination = state.planDestination;
    state = state.copyWith(
      origin: destination,
      destination: origin,
      planOrigin: planDestination,
      planDestination: planOrigin,
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
      planDestination: state.destination,
      submitted: true,
      expandedIndex: null,
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
      expandedIndex: collapsing ? null : itemIndex,
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

  // ------------------------------------------------------------------
  // Micros: marcadores del modo EXPLORACIÓN «LUGARES»
  // ------------------------------------------------------------------

  /// Tope de paradas que se clavan en el mapa: más allá solo saturan (el
  /// listado del panel muestra todas).
  static const int _maxPlaceStopMarkers = 24;

  /// Dibuja en el mapa el resultado del modo lugares: el pin del [point]
  /// consultado (si viene de «cerca de mí» o de marcar en el mapa) y un punto
  /// por cada parada de [stops]. Se llama desde el panel al resolverse la
  /// búsqueda; reemplaza por completo los marcadores anteriores.
  void showPlaceResults({
    ({double lat, double lon})? point,
    List<StopHit> stops = const [],
  }) {
    final markers = <MapMarker>[];
    if (point != null) {
      markers.add(
        MapMarker(
          id: 'place-search-point',
          point: LatLng(point.lat, point.lon),
          width: MapPlacePin.widthFor(30),
          height: MapPlacePin.heightFor(30),
          anchor: MapMarkerAnchor.bottom,
          child: const MapPlacePin(color: AppColors.accent),
        ),
      );
    }
    final count = stops.length < _maxPlaceStopMarkers
        ? stops.length
        : _maxPlaceStopMarkers;
    for (var i = 0; i < count; i++) {
      final stop = stops[i];
      markers.add(
        MapMarker(
          id: 'place-stop-${stop.id}',
          point: LatLng(stop.lat, stop.lon),
          width: 16,
          height: 16,
          child: const MapStopDot(color: AppColors.primary),
        ),
      );
    }
    state = state.copyWith(placeMarkers: markers);
  }

  /// Borra los marcadores del modo lugares (al salir del modo, limpiar la
  /// búsqueda o cerrar el panel): los recorridos dibujados NO se tocan.
  void clearPlaceMarkers() {
    if (state.placeMarkers.isEmpty) return;
    state = state.copyWith(placeMarkers: const []);
  }
}
