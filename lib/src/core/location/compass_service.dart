import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Acceso testeable a la orientación física del dispositivo.
class CompassService {
  Stream<double> headingStream() {
    return _sensorHeadingStream();
  }

  Stream<double> _sensorHeadingStream() {
    final controller = StreamController<double>();
    AccelerometerEvent? gravity;
    MagnetometerEvent? magnetic;
    StreamSubscription<AccelerometerEvent>? gravitySubscription;
    StreamSubscription<MagnetometerEvent>? magneticSubscription;
    double? smoothedHeading;
    double? emittedHeading;

    void emitHeading() {
      final g = gravity;
      final m = magnetic;
      if (g == null || m == null) return;

      // Compensa la inclinación para que pequeños cambios de postura no
      // conviertan el ruido del magnetómetro en saltos de rumbo.
      final roll = math.atan2(g.y, g.z);
      final pitch = math.atan2(-g.x, math.sqrt(g.y * g.y + g.z * g.z));
      final mx = m.x * math.cos(pitch) + m.z * math.sin(pitch);
      final my =
          m.x * math.sin(roll) * math.sin(pitch) +
          m.y * math.cos(roll) -
          m.z * math.sin(roll) * math.cos(pitch);
      final rawHeading = _normalize(math.atan2(my, mx) * 180 / math.pi);

      smoothedHeading = _smoothAngle(smoothedHeading, rawHeading, 0.12);
      final heading = _quantize(smoothedHeading!);
      if (heading == emittedHeading) return;
      emittedHeading = heading;
      controller.add(heading);
    }

    controller.onListen = () {
      try {
        gravitySubscription = accelerometerEventStream().listen((event) {
          gravity = event;
          emitHeading();
        });
        magneticSubscription = magnetometerEventStream().listen((event) {
          magnetic = event;
          emitHeading();
        });
      } catch (_) {
        controller.close();
      }
    };
    controller.onCancel = () async {
      await gravitySubscription?.cancel();
      await magneticSubscription?.cancel();
      await controller.close();
    };
    return controller.stream;
  }

  static double _quantize(double heading) {
    final normalized = _normalize(heading);
    return (normalized / 2).round() * 2 % 360;
  }

  static double _normalize(double angle) => (angle + 360) % 360;

  static double _smoothAngle(double? previous, double next, double factor) {
    if (previous == null) return next;
    final delta = ((next - previous + 540) % 360) - 180;
    return _normalize(previous + delta * factor);
  }
}

final compassServiceProvider = Provider<CompassService>(
  (_) => CompassService(),
);

final deviceHeadingProvider = StreamProvider.autoDispose<double>((ref) {
  final service = ref.watch(compassServiceProvider);
  return service.headingStream();
});

double headingRadians(double degrees) => degrees * math.pi / 180;
