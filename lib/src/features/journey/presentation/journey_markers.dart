import 'dart:ui' as ui;

import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/map/map.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/urbano_map.dart' show MapsPin;
import '../domain/route_arrows.dart';

/// La clave de un recorrido activo nació aquí; hoy vive con el resto de las
/// funciones puras del catálogo de micros (`application/micros_catalog.dart`)
/// y se reexporta para no cambiar los imports de quien la usa.
export '../application/micros_catalog.dart' show microDirectionKey;

/// Capa de INSIGNIAS del mapa — el pequeño módulo compartido entre los dos
/// consumidores de capas: la planificación del viaje ([JourneyResultMap]) y
/// el panel de micros (el controller clava estos marcadores). Vive APARTE de
/// `journey_result_map.dart`/`journey_micros_sheet.dart` para que ningún
/// módulo de lógica (el controller del planeador) dependa de la pantalla del
/// mapa: la dependencia gira hacia este archivo, que solo sabe pintar pins.
///
/// Contenido: el punto medio de una polilínea, el ancho de la insignia y los
/// tres widgets de marcador (pin de lugar, punto de parada e insignia de
/// micro).

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

/// Ancho de la CAJA del marcador de una insignia: la insignia en función del
/// texto (icono + texto + padding) más el aire de su sombra a cada lado
/// ([kMarkerShadowMargin]).
double routeBadgeWidth(String label) {
  final width = 30 + label.length * 6.6;
  return width.clamp(46, 170).toDouble() + kMarkerShadowMargin * 2;
}

/// Alto de la caja del marcador de una insignia (24 visibles + el aire de la
/// sombra).
const double routeBadgeHeight = 24 + kMarkerShadowMargin * 2;

/// Lado de la caja del marcador de un punto de parada de 16 px.
const double stopDotBox = 16 + kMarkerShadowMargin * 2;

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
    // El aire alrededor deja entrar la sombra entera en la imagen nativa: sin
    // él se recortaba contra la caja y asomaban puntas en las esquinas.
    return Padding(
      padding: const EdgeInsets.all(kMarkerShadowMargin),
      child: Container(
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
      ),
    );
  }
}

/// Lado del marcador de una flecha de sentido sobre un trazado de micro.
const double kRouteArrowSize = 16;

/// Clave de la imagen nativa de una flecha: depende SOLO de su color (todas
/// las flechas del mismo trazo comparten una imagen; con la clave por id el
/// motor reutilizaba la flecha ya rasterizada con el color de otro micro).
String routeArrowIconKey(Color color) =>
    'route-arrow-${color.toARGB32().toRadixString(16)}';

/// Flechas de sentido a lo largo de [path], cada [spacingMeters], en el
/// [color] del trazo. La geometría (reparto y rumbo) es pura y vive en
/// `domain/route_arrows.dart`; aquí solo se arma el marcador.
///
/// El rumbo es GEOGRÁFICO (`rotateWithMap`): la flecha gira con el mapa y
/// sigue apuntando a lo largo del trazo aunque el usuario lo rote.
List<MapMarker> routeArrowMarkers({
  required String idPrefix,
  required List<LatLng> path,
  required Color color,
  double spacingMeters = 200,
}) {
  final arrows = arrowsAlongPath(path, spacingMeters);
  return [
    for (var i = 0; i < arrows.length; i++)
      MapMarker(
        id: '$idPrefix-$i',
        point: arrows[i].point,
        width: kRouteArrowSize,
        height: kRouteArrowSize,
        rotation: arrows[i].bearing,
        rotateWithMap: true,
        iconKey: routeArrowIconKey(color),
        child: RouteArrowMarker(color: color),
      ),
  ];
}

/// Cabeza de flecha de sentido sobre un trazado de micro. La comparten la
/// planificación del viaje y «Micros cerca».
class RouteArrowMarker extends StatelessWidget {
  const RouteArrowMarker({super.key, required this.color});

  /// Color del trazo sobre el que se apoya (opaco: el motor nativo descarta
  /// el alfa de la línea, y la punta debe ser del mismo tono).
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(kRouteArrowSize),
      painter: _RouteArrowPainter(color: color),
    );
  }
}

/// Cabeza de flecha rellena del MISMO color que el trazo, con el borde blanco
/// de la polilínea (`MapPolyline.outlineColor`): se lee como una punta de la
/// propia línea, no como un marcador aparte.
class _RouteArrowPainter extends CustomPainter {
  _RouteArrowPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    // Apunta hacia arriba (0° = norte); la rotación la aplica el marcador.
    final head = ui.Path()
      ..moveTo(c.dx, c.dy - r * 0.78)
      ..lineTo(c.dx + r * 0.72, c.dy + r * 0.55)
      ..lineTo(c.dx, c.dy + r * 0.2)
      ..lineTo(c.dx - r * 0.72, c.dy + r * 0.55)
      ..close();
    canvas
      ..drawPath(
        head,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.3
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      )
      ..drawPath(
        head,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
  }

  @override
  bool shouldRepaint(covariant _RouteArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
