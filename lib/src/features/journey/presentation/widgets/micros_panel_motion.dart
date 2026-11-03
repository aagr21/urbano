import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Movimiento compartido por las secciones del panel de micros. Son funciones
/// puras sobre el `AnimationController` del panel: no montan relojes propios
/// (nada de timers pendientes en los tests de widget).

/// Fundido + deslizamiento desde la izquierda para la entrada escalonada de
/// las secciones (cada una con su `Animation` recortado del mismo
/// `_entrance`, que va de 0 a 1 una sola vez).
Widget microsRise(Animation<double> animation, Widget child) => FadeTransition(
  opacity: animation,
  child: SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(-0.05, 0),
      end: Offset.zero,
    ).animate(animation),
    child: child,
  ),
);

/// Entrada escalonada del listado, calculada sobre el valor de [entrance]
/// matemática pura en `build`, sin timers ni listeners por tarjeta. Así el
/// escalonado no se re-dispara al hacer scroll (en cuanto termina la entrada
/// la tarjeta ya sale en su sitio) y el árbol se asienta sin relojes
/// pendientes en los tests.
Widget microsStagger(AnimationController entrance, int index, Widget tile) {
  if (entrance.isCompleted) return tile;
  final start = math.min(0.4 + index * 0.05, 0.9);
  final t = Curves.easeOutCubic.transform(
    ((entrance.value - start) / 0.18).clamp(0.0, 1.0),
  );
  return Opacity(
    opacity: t,
    child: Transform.translate(offset: Offset(-16 * (1 - t), 0), child: tile),
  );
}
