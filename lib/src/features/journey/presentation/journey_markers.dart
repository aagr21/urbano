import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/map.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/urbano_map.dart' show MapsPin;

/// Capa de INSIGNIAS del mapa — el pequeño módulo compartido entre los dos
/// consumidores de capas: la planificación del viaje ([JourneyResultMap]) y
/// el panel de micros (el controller clava estos marcadores). Vive APARTE de
/// `journey_result_map.dart`/`journey_micros_sheet.dart` para que ningún
/// módulo de lógica (el controller del planeador) dependa de la pantalla del
/// mapa: la dependencia gira hacia este archivo, que solo sabe pintar pins.
///
/// Contenido: la clave de un recorrido activo (`routeId#directionId`), el
/// punto medio de una polilínea, el ancho de la insignia y los tres widgets
/// de marcador (pin de lugar, punto de parada e insignia de micro).

/// Clave de un recorrido activo en el mapa: `routeId#directionId`.
/// El panel y la pantalla padre comparten este formato para saber qué
/// direcciones (ida/vuelta) de cada micro están dibujadas.
String microDirectionKey(String routeId, int directionId) =>
    '$routeId#$directionId';

/// Punto medio de una polilínea por longitud acumulada (la insignia de la
/// ruta queda encima de su propia línea, sin importar cuántas curvas tenga).
LatLng routePathMidpoint(List<LatLng> path) {
  if (path.length < 2) return path.first;
  const distance = Distance();
  final segments = <double>[];
  var total = 0.0;
  for (var i = 1; i < path.length; i++) {
    final length = distance.distance(path[i - 1], path[i]);
    segments.add(length);
    total += length;
  }
  if (total == 0) return path.first;

  var walked = 0.0;
  for (var i = 0; i < segments.length; i++) {
    if (walked + segments[i] >= total / 2) {
      final t = segments[i] == 0 ? 0.0 : (total / 2 - walked) / segments[i];
      final a = path[i];
      final b = path[i + 1];
      return LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
    }
    walked += segments[i];
  }
  return path.last;
}

/// Ancho de la insignia en función del texto (icono + texto + padding).
double routeBadgeWidth(String label) {
  final width = 30 + label.length * 6.6;
  return width.clamp(46, 170).toDouble();
}

/// Pin del LUGAR consultado en el modo lugares del panel: marca EN EL MAPA el
/// punto exacto sobre el que se pregunta «¿qué línea pasa por aquí?» (elegido
/// con el selector o resuelto por «cerca de mí»). Se ancla por la punta como
/// los extremos del viaje.
class MapPlacePin extends StatelessWidget {
  const MapPlacePin({super.key, required this.color, this.size = 30});

  final Color color;
  final double size;

  /// Ancho/alto que debe tener el [MapMarker] que envuelva este pin.
  static double widthFor(double size) => MapsPin.boxedWidth(size);
  static double heightFor(double size) => MapsPin.boxedHeight(size);

  @override
  Widget build(BuildContext context) => MapsPin(color: color, size: size);
}

/// Marcador compacto de una PARADA resultante del modo lugares: un punto con
/// anillo blanco (no una gota) para que decenas de esquinas no saturen el
/// mapa, distinguible del pin del lugar buscado ([MapPlacePin]).
class MapStopDot extends StatelessWidget {
  const MapStopDot({super.key, required this.color, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
    ),
  );
}

/// Insignia de micro sobre su tramo en el mapa: "101" (número/nombre) en el
/// color de la línea, con sombra y borde blanco para que se lea sobre
/// cualquier tile. Compartida entre la planificación y el panel de micros.
///
/// La letra y el ícono NO son blancos fijos: el color de línea viene del GTFS y
/// puede ser casi blanco (`F1C40F`), así que el foreground lo decide
/// `AppColors.onColor` sobre ese relleno.
class MapRouteBadge extends StatelessWidget {
  const MapRouteBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor = AppColors.onColor(color);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_rounded, size: 12, color: onColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
