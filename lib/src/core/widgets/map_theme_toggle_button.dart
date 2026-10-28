import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animation/motion.dart';
import '../theme/app_theme.dart';
import '../theme/map_theme_controller.dart';
import '../theme/map_theme_scope.dart';
import '../utils/extensions.dart';

/// Cambiador de brillo **del mapa**, independiente del tema de la app.
///
/// Tocar alterna mapa claro ↔ oscuro y guarda la elección (persiste entre
/// sesiones y no se mueve cuando el usuario cambia el tema de la app). Mantener
/// pulsado devuelve el mapa a seguir al tema de la app.
///
/// Va SIEMPRE dentro de un [MapThemeScope]: ahí `Theme.of(context).brightness`
/// ya es el brillo efectivo del mapa, así que el ícono nunca miente (fuera del
/// ámbito leería el brillo de la app y propondría el cambio equivocado).
class MapThemeToggleButton extends ConsumerWidget {
  const MapThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final dark = MapThemeScope.isDarkOf(context);
    final pinned = ref.watch(mapThemeControllerProvider) != null;

    return SizedBox(
      // MISMO diámetro que el resto de la columna (el `Tooltip` fuera del
      // lado del botón infla 3 px por lado y rompería la uniformidad).
      width: AppControl.mapButton,
      height: AppControl.mapButton,
      child: Tooltip(
        message: dark
            ? 'Poner el mapa claro'
            : 'Poner el mapa oscuro${pinned ? '' : ' (ahora sigue al tema de la app)'}',
        child: GestureDetector(
          // Mantener pulsado = dejar que el mapa vuelva a seguir el tema.
          onLongPress: pinned
              ? () {
                  ref
                      .read(mapThemeControllerProvider.notifier)
                      .followAppTheme();
                  context.showSnack(
                    'El mapa vuelve a seguir el tema de la app',
                  );
                }
              : null,
          child: PressScale(
            scale: 0.92,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.outlineVariant),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                // MISMO diámetro que el resto de la columna de controles del
                // mapa ([AppControl.mapButton]): el brillo no va ni más grande
                // ni más chico que el zoom.
                constraints: const BoxConstraints.tightFor(
                  width: AppControl.mapButton,
                  height: AppControl.mapButton,
                ),
                onPressed: () => ref
                    .read(mapThemeControllerProvider.notifier)
                    .setDark(!dark),
                // El ícono ofrece el MODO CONTRARIO: es la acción, no el estado.
                icon: Icon(
                  dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20,
                  color: colors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
