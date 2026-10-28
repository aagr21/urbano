import 'package:flutter/material.dart';

/// Contraste WCAG 2.x entre dos colores opacos (razón 1:1 – 21:1).
///
/// Mismo cálculo que usa `AppColors` internamente: sirve para **medir** en los
/// tests que ninguna letra, ícono o borde quede oscuro sobre un fondo oscuro
/// (o claro sobre claro), que es la regla de la casa documentada arriba de
/// `lib/src/core/theme/app_colors.dart`.
double colorContrast(Color a, Color b) {
  final la = a.computeLuminance() + 0.05;
  final lb = b.computeLuminance() + 0.05;
  return la > lb ? la / lb : lb / la;
}
