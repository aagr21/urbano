import 'journey_place.dart';

/// Tiempos del planeador: debounce del replan por arrastre y ventana que
/// separa un drop deliberado de un fantasma de pellizco/pan.
///
/// Los tests del mapa ([test/journey_result_map_test.dart]) fijan 600/700 ms;
/// no los cambies sin leer ese archivo.
abstract final class JourneyPlannerTiming {
  static const Duration replanDebounce = Duration(milliseconds: 600);
  static const Duration gestureDropWindow = Duration(milliseconds: 700);
}

/// Qué hacer con un evento de arrastre/drop de un extremo.
enum EndpointDragDecision {
  /// El pin volvió al punto ya comprometido: se desarma el recálculo.
  cancelReplan,

  /// Drop dentro de la ventana de un gesto de cámara: fantasma, se restaura.
  discardGestureGhost,

  /// Arrastre deliberado: el campo sigue al dedo y el plan espera el debounce.
  scheduleReplan,
}

/// Política pura del drop de un extremo: sin Riverpod ni reloj global.
///
/// El controller solo traduce la decisión a debounce y `copyWith`.
EndpointDragDecision decideEndpointDrag({
  required double lat,
  required double lon,
  required JourneyPoint? committed,
  required DateTime now,
  required DateTime? lastGestureAt,
  required Duration gestureWindow,
}) {
  if (committed != null && committed.lat == lat && committed.lon == lon) {
    return EndpointDragDecision.cancelReplan;
  }
  if (lastGestureAt != null && now.difference(lastGestureAt) < gestureWindow) {
    return EndpointDragDecision.discardGestureGhost;
  }
  return EndpointDragDecision.scheduleReplan;
}
