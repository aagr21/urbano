import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Flecha de vuelta ÚNICA de la app.
///
/// Toda pantalla que se empuja sobre otra regresa con esta flecha; las ramas
/// de primer nivel (Viaje y Denuncias) también la muestran, pero como no hay
/// nada debajo en su pila vuelven a Inicio. Así el gesto nunca deja al usuario
/// en un callejón: si [GoRouter] puede retroceder, retrocede; si no, aterriza
/// en la portada.
///
/// Inicio NO la muestra: es la raíz de la app y el botón del sistema debe
/// salir de ella, no volver a sí misma.
class UrbanoBackButton extends StatelessWidget {
  const UrbanoBackButton({
    super.key,
    this.tooltip = 'Volver',
    this.color,
    this.onPressed,
  });

  final String tooltip;

  /// Tinta de la flecha cuando vive sobre un campo de color (p. ej. la
  /// portada de Denuncias). `null` deja el color del tema.
  final Color? color;

  /// Acción explícita; por defecto usa el retroceso seguro.
  final VoidCallback? onPressed;

  /// Retrocede si hay pila; si no, vuelve a Inicio.
  static void goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed ?? () => goBack(context),
      icon: Icon(Icons.arrow_back_rounded, color: color),
    );
  }
}
