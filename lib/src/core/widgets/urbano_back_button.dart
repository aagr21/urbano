import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../animation/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/extensions.dart';

/// Flecha de vuelta ÚNICA de la app (diseño y comportamiento).
///
/// Toda pantalla que se empuja sobre otra regresa con este botón; las ramas
/// de primer nivel (Viaje y Denuncias) también lo muestran, pero como no hay
/// nada debajo en su pila vuelven a Inicio. Así el gesto nunca deja al usuario
/// en un callejón: si [GoRouter] puede retroceder, retrocede; si no, aterriza
/// en la portada.
///
/// El diseño es el del catálogo de Micros: chevron redondeado sobre un círculo
/// con la superficie del tema y un filete fino, con hundimiento al presionar
/// ([PressScale]). Es el mismo en AppBars, cabeceras propias, portadas de
/// color y sobre el mapa — no se pinta otra flecha a mano en ninguna pantalla.
/// Como el círculo siempre es la superficie del tema, la tinta es la del tema
/// y se lee igual sobre un campo oscuro (portada de Denuncias) o sobre el mapa.
///
/// Inicio NO lo muestra: es la raíz de la app y el botón del sistema debe
/// salir de ella, no volver a sí misma.
class UrbanoBackButton extends StatelessWidget {
  const UrbanoBackButton({
    super.key,
    this.tooltip = 'Volver',
    this.onPressed,
    this.floating = false,
  });

  final String tooltip;

  /// Acción explícita; por defecto usa el retroceso seguro ([goBack]).
  final VoidCallback? onPressed;

  /// Flota sobre un mapa: toma el diámetro de los botones del mapa
  /// ([AppControl.mapButton]) y suma sombra para despegarse del trazado.
  final bool floating;

  /// Retrocede si hay pila; si no, vuelve a Inicio.
  static void goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  /// Diámetro visible del círculo fuera del mapa.
  static const double _diameter = 40;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed ?? () => goBack(context),
      icon: const Icon(Icons.chevron_left_rounded, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        side: BorderSide(
          color: dark
              ? AppColors.lineStrongDark
              : colors.outlineVariant.withValues(alpha: 0.8),
        ),
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
        // Diámetro fijo: en la ranura `leading` de una AppBar (56 px tensos)
        // el círculo se estiraba hasta los bordes.
        minimumSize: Size.zero,
        fixedSize: Size.square(floating ? AppControl.mapButton : _diameter),
        tapTargetSize: floating ? MaterialTapTargetSize.shrinkWrap : null,
      ),
    );

    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: PressScale(
        scale: 0.95,
        child: floating
            ? DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: button,
              )
            : button,
      ),
    );
  }
}
