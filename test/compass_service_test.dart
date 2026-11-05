import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/location/compass_service.dart';

/// Vector de gravedad y campo magnético para el teléfono **plano** (pantalla
/// hacia arriba): la gravedad sale por `+z`, así que gz = 9.8 y gx = gy = 0.
/// El campo horizontal (mz = 0) se orienta según hacia dónde apunte el borde
/// superior: `+y` es el canto de arriba, `+x` el canto derecho.
double headingFlat({required double northX, required double northY}) =>
    CompassService.tiltCompensatedHeading(
      gx: 0,
      gy: 0,
      gz: 9.8,
      mx: northX,
      my: northY,
      mz: 0,
    );

void main() {
  group('CompassService.tiltCompensatedHeading', () {
    // Regresión: la aguja giraba bien pero quedaba 90° corrida al iniciar,
    // porque el rumbo se mediaba desde el canto derecho (+x) en vez del borde
    // de avance (borde superior). Estos cuatro puntos fijan esa convención.
    test('borde superior apuntando al norte = 0°', () {
      // Norte a lo largo de +y (hacia el canto de arriba).
      expect(headingFlat(northX: 0, northY: 1), closeTo(0, 0.001));
    });

    test('borde superior apuntando al este = 90°', () {
      // Si avanzo al este, el norte queda a mi izquierda (canto -x).
      expect(headingFlat(northX: -1, northY: 0), closeTo(90, 0.001));
    });

    test('borde superior apuntando al sur = 180°', () {
      // Avanzo al sur: el norte queda detrás (canto -y).
      expect(headingFlat(northX: 0, northY: -1), closeTo(180, 0.001));
    });

    test('borde superior apuntando al oeste = 270°', () {
      // Avanzo al oeste: el norte queda a mi derecha (canto +x).
      expect(headingFlat(northX: 1, northY: 0), closeTo(270, 0.001));
    });

    test('noreste = 45° (descarta el signo del desplazamiento)', () {
      // Avanzo al NE: el norte está 45° a mi izquierda → vector (-√2/2, √2/2).
      const s = 0.7071;
      expect(headingFlat(northX: -s, northY: s), closeTo(45, 0.1));
    });

    test('el resultado siempre cae en [0, 360)', () {
      // Barrido del norte alrededor del teléfono: el rumbo cubre toda la rosa.
      for (var deg = 0; deg < 360; deg += 15) {
        final rad = deg * math.pi / 180;
        // Norte girado `deg` en sentido horario visto desde arriba.
        final h = headingFlat(northX: -math.sin(rad), northY: math.cos(rad));
        expect(h, inInclusiveRange(0, 360));
        expect(h, closeTo(deg.toDouble(), 0.1));
      }
    });
  });
}
