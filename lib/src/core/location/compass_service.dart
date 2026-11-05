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

      final rawHeading = tiltCompensatedHeading(
        gx: g.x,
        gy: g.y,
        gz: g.z,
        mx: m.x,
        my: m.y,
        mz: m.z,
      );

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

  /// Rumbo (grados, sentido horario desde el norte) al que apunta el **borde
  /// superior** del teléfono, compensando la inclinación con la gravedad.
  ///
  /// El marco de ejes de Android es: `x` = lado derecho de la pantalla, `y` =
  /// borde superior, `z` = sale de la pantalla hacia el usuario. El ángulo del
  /// campo magnético medido desde el eje `+x` (`atan2(my, mx)`) va en sentido
  /// ANTIhorario y parte del canto derecho, así que describe el norte medido
  /// desde ese canto: sostiene el teléfono en vertical y camina apuntando con
  /// el borde de arriba al norte, y ese `atan2` devuelve 90°, no 0°. De ahí el
  /// desplazamiento constante que se veía al iniciar —la aguja giraba bien pero
  /// quedaba 90° corrida—: el rumbo de avance es `atan2(my, mx) - 90`.
  static double tiltCompensatedHeading({
    required double gx,
    required double gy,
    required double gz,
    required double mx,
    required double my,
    required double mz,
  }) {
    // Compensa la inclinación para que pequeños cambios de postura no conviertan
    // el ruido del magnetómetro en saltos de rumbo.
    final roll = math.atan2(gy, gz);
    final pitch = math.atan2(-gx, math.sqrt(gy * gy + gz * gz));
    final hx = mx * math.cos(pitch) + mz * math.sin(pitch);
    final hy =
        mx * math.sin(roll) * math.sin(pitch) +
        my * math.cos(roll) -
        mz * math.sin(roll) * math.cos(pitch);
    final fromXAxis = math.atan2(hy, hx) * 180 / math.pi;
    return _normalize(fromXAxis - 90);
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
