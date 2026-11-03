import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/journey/domain/endpoint_drag.dart';

void main() {
  const committed = (lat: -17.78, lon: -63.18);
  final now = DateTime(2026, 10, 29, 12);

  group('decideEndpointDrag', () {
    test('cancela el replan si el pin volvió al punto comprometido', () {
      expect(
        decideEndpointDrag(
          lat: committed.lat,
          lon: committed.lon,
          committed: committed,
          now: now,
          lastGestureAt: now.subtract(const Duration(milliseconds: 50)),
          gestureWindow: JourneyPlannerTiming.gestureDropWindow,
        ),
        EndpointDragDecision.cancelReplan,
      );
    });

    test('descarta el drop si la cámara se movió por gesto hace poco', () {
      expect(
        decideEndpointDrag(
          lat: -17.79,
          lon: -63.19,
          committed: committed,
          now: now,
          lastGestureAt: now.subtract(const Duration(milliseconds: 200)),
          gestureWindow: JourneyPlannerTiming.gestureDropWindow,
        ),
        EndpointDragDecision.discardGestureGhost,
      );
    });

    test('programa el replan si el drop es deliberado', () {
      expect(
        decideEndpointDrag(
          lat: -17.79,
          lon: -63.19,
          committed: committed,
          now: now,
          lastGestureAt: now.subtract(const Duration(seconds: 2)),
          gestureWindow: JourneyPlannerTiming.gestureDropWindow,
        ),
        EndpointDragDecision.scheduleReplan,
      );
    });

    test('programa el replan si nunca hubo gesto de cámara', () {
      expect(
        decideEndpointDrag(
          lat: -17.79,
          lon: -63.19,
          committed: committed,
          now: now,
          lastGestureAt: null,
          gestureWindow: JourneyPlannerTiming.gestureDropWindow,
        ),
        EndpointDragDecision.scheduleReplan,
      );
    });
  });
}
