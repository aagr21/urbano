import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'map_theme_controller.dart';

/// Ámbito de brillo **para el mapa y lo que flota sobre él**.
///
/// Envuelve el `Stack` de cada superficie de mapa (planeador, panel de micros,
/// selector en el mapa, tarjeta destacada, recorrido completo) con un [Theme]
/// cuyo brillo es el que el usuario eligió para el mapa. Dos consecuencias:
///
/// 1. [UrbanoMap] lee su estilo de `Theme.of(context).brightness`, así que el
///    mapa usa su propio modo aunque el tema de la app sea el contrario.
/// 2. TODOS los overlays del subtree (`GlassCard` y su blur translúcido, chips,
///    controles, leyendas, el panel de micros, la hoja de resultados, campos de
///    texto) resuelven `context.colors` / `context.text` contra ESE brillo: la
///    letra, los bordes y los íconos se ven sobre el fondo que realmente está
///    pintado, sin cruces de tema (lema claro sobre vidrio oscuro, etc.).
///
/// Sin elección explícita ([mapThemeControllerProvider] en `null`) devuelve el
/// `child` tal cual: el mapa hereda el brillo de la app, el comportamiento
/// histórico.
class MapThemeScope extends ConsumerWidget {
  const MapThemeScope({super.key, required this.child}) : builder = null;

  /// Variante con constructor de [builder]: el `BuildContext` que recibe YA está
  /// dentro del ámbito. Hace falta cuando el `build` llamador lee
  /// `context.colors` / `context.text` y los pasa al subtree (paneles, chips con
  /// color de relleno): con [MapThemeScope] a secas esos valores seguirían
  /// saliendo del tema de la app y el arreglo sería un no-op.
  const MapThemeScope.builder({super.key, required this.builder})
    : child = null;

  final Widget? child;
  final WidgetBuilder? builder;

  static ThemeData? _light;
  static ThemeData? _dark;

  /// Brillo efectivo del mapa en el subtree más cercano de [MapThemeScope].
  static bool isDarkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Tema que instalaría el ámbito para la elección [choice]. `null` = sin
  /// override (hereda el tema de la app). Se expone para que lo que se monta
  /// FUERA del árbol del mapa (hojas modales, rutas del `Overlay`) pinte también
  /// su fondo a juego con el brillo del mapa.
  static ThemeData? themeFor(bool? choice) => switch (choice) {
    null => null,
    true => _dark ??= AppTheme.dark(),
    false => _light ??= AppTheme.light(),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Los mismos objetos que el `MaterialApp` usa por brillo: nada de un tema
    // a medias que herede colores del otro modo.
    final data = themeFor(ref.watch(mapThemeControllerProvider));
    if (data == null) return _content(context);
    return Theme(data: data, child: _content(context));
  }

  Widget _content(BuildContext context) =>
      builder != null ? builder!(context) : child!;
}
