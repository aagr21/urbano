// Piezas visuales del selector de punto (MapPickerScreen) y sus dos reglas
// puras: cuándo centrar en el GPS y cómo se escribe la coordenada.

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/urbano_map.dart' show MapsPin;
import '../../data/journey_repository.dart';

/// El selector se centra solo en la ubicación del usuario si NADA lo impide:
/// sin punto inicial pedido, sin gesto del usuario (el punto elegido es el
/// suyo), una sola vez y con el mapa listo para moverse.
bool shouldAutoCenterPicker({
  required bool hasInitialPoint,
  required bool userInteracted,
  required bool alreadyApplied,
  required bool mapReady,
}) => !hasInitialPoint && !userInteracted && !alreadyApplied && mapReady;

/// Coordenada con 5 decimales (≈ 1 m), sin «-0.00000».
String formatPickerCoordinate(double value) =>
    (value == 0 ? 0.0 : value).toStringAsFixed(5);

/// Marcador de punto FIJO (no arrastrable) con el aspecto del de Google
/// Maps: gota con círculo blanco al centro. Su PUNTA queda clavada en el
/// centro exacto del mapa, que es la coordenada que se devuelve. Para
/// cambiarla se mueve el mapa por debajo, nunca el pin.
class MapPickerCenterPin extends StatelessWidget {
  const MapPickerCenterPin({super.key});

  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    // Altura REAL del pin (gota + margen de sombra): subir media altura
    // encajada deja la punta justo en el punto central.
    final height = MapsPin.boxedHeight(_size);
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Sombra elíptica justo en el punto del centro.
          Container(
            width: 30,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          Transform.translate(
            offset: Offset(0, -height / 2),
            child: const MapsPin(color: Color(0xFFDB4437), size: _size),
          ),
        ],
      ),
    );
  }
}

/// Píldora con el título del selector (`Origen`, `Destino`…).
class MapPickerTitlePill extends StatelessWidget {
  const MapPickerTitlePill({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_with_rounded, size: 15, color: colors.primary),
          const SizedBox(width: 7),
          Text(
            title,
            style: context.text.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip con la coordenada exacta que se devolverá al planificador.
///
/// Con el pin fijo al centro no hay otra forma de "leer" el número; se
/// actualiza en vivo mientras el mapa se desplaza.
class MapPickerPointChip extends StatelessWidget {
  const MapPickerPointChip({super.key, required this.point});

  final JourneyPoint point;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_location_alt_rounded, size: 17, color: colors.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Punto: ${formatPickerCoordinate(point.lat)}, '
              '${formatPickerCoordinate(point.lon)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón circular flotante (zoom).
class MapPickerCircleButton extends StatelessWidget {
  const MapPickerCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 46,
      height: 46,
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
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 21, color: colors.primary),
      ),
    );
  }
}
