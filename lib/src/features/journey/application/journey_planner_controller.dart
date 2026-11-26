import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/debouncer.dart';
import '../domain/endpoint_drag.dart';
import '../domain/journey_place.dart';
import '../domain/journey_planner_state.dart';

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

/// Controlador del **planeador de viajes**: traduce gestos y acciones de UI
/// a [JourneyPlannerState]. La política de drop (debounce / barrera anti-zoom)
/// vive en dominio ([decideEndpointDrag]); aquí quedan el reloj, los
/// debouncers y el I/O de capas de micros.
///
/// Desacoplado del `State` de la pantalla: el estado es dato puro y en la
/// pantalla queda solo el cableado (GlobalKey del mapa, hoja, panel abierto).
class JourneyPlannerController extends Notifier<JourneyPlannerState> {
  /// Constructor que permite inyectar fábricas de timer (útil para tests con
  /// `FakeAsync`). En producción se usan los valores por defecto.
  JourneyPlannerController({
    TimerFactory? originTimerFactory,
    TimerFactory? destinationTimerFactory,
  }) : _replanOriginDebouncer = Debouncer(
         delay: JourneyPlannerTiming.replanDebounce,
         timerFactory: originTimerFactory,
       ),
       _replanDestinationDebouncer = Debouncer(
         delay: JourneyPlannerTiming.replanDebounce,
         timerFactory: destinationTimerFactory,
       );

  /// Un debounce POR EXTREMO: compartir uno solo hacía que soltar el
  /// destino poco después del origen CANCELARA el cambio del origen (el
  /// marcador se quedaba en el punto soltado, pero el viaje se planificaba
  /// con el punto viejo).
  late final Debouncer _replanOriginDebouncer;
  late final Debouncer _replanDestinationDebouncer;

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
            // Respuesta nueva: la mejor opción abre con su paso a paso.
            expandedIndex: 0,
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
      expandedIndex: 0,
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
      // La opción dibujada abre con su paso a paso.
      expandedIndex: state.selectedOptionIndex,
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
}
