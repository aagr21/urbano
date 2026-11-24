import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../map/map.dart';
import '../utils/extensions.dart';

/// Punto «mi ubicación» de la app: círculo primario con anillo blanco y la
/// flecha de navegación orientada con la brújula.
///
/// Es EL punto de ubicación de todos los mapas (planeador de Viaje y mapa a
/// sangre del recorrido): el puck nativo de MapLibre no se usa porque pide su
/// propio GPS continuo. El aura pulsante no va aquí — viaja como [MapPulse]
/// (la pintan los motores en capas nativas, sin re-rasterizar).
class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});

  /// Diámetro del marcador.
  static const double size = 30;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Relleno = primario del tema, el MISMO color de los botones de
        // ubicación y del pin de origen: en oscuro es la menta de la marca.
        color: context.colors.primary,
        // Anillo SIEMPRE blanco: el punto va sobre el mapa, no sobre una
        // superficie de la app; con `surface` el borde se volvía negro en
        // modo oscuro y el punto se confundía con la cartografía oscura.
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Center(
        child: Icon(
          Icons.navigation_rounded,
          size: 18,
          color: context.colors.onPrimary,
        ),
      ),
    );
  }

  /// Marcador listo para el mapa en [point], girado [heading] grados.
  static MapMarker marker({
    required String id,
    required LatLng point,
    double heading = 0,
  }) => MapMarker(
    id: id,
    point: point,
    width: size,
    height: size,
    rotation: heading,
    child: const MyLocationDot(),
  );
}
