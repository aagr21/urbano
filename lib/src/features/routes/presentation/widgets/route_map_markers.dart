import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/map/map.dart';
import '../../../../core/theme/app_colors.dart';

/// Punto medio aproximado del trazado (por índice): alcanza para colgar el
/// micro sobre la polilínea sin importar cuántos vértices traiga el feed.
LatLng routeShapeMidpoint(List<LatLng> points) => points[points.length ~/ 2];

/// Punto de origen/destino del trazado.
class RouteEndDot extends StatelessWidget {
  const RouteEndDot({super.key, required this.color});

  final Color color;

  /// Diámetro visible del punto.
  static const double _diameter = 22;

  /// Marcador del extremo: la caja deja [kMarkerShadowMargin] de aire
  /// alrededor del punto para que la sombra entre entera en la imagen nativa.
  static MapMarker marker({
    required String id,
    required LatLng point,
    required Color color,
  }) => MapMarker(
    id: id,
    point: point,
    width: _diameter + kMarkerShadowMargin * 2,
    height: _diameter + kMarkerShadowMargin * 2,
    iconKey: 'route-end-${color.toARGB32().toRadixString(16)}',
    child: RouteEndDot(color: color),
  );

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 5),
        ],
      ),
    ),
  );
}

/// Micro de la línea sobre su propio trazo: disco del MISMO color que la
/// polilínea con el ícono del bus en la tinta legible.
class RouteBusMarker extends StatelessWidget {
  const RouteBusMarker({super.key, required this.color});

  final Color color;

  /// Diámetro visible del disco.
  static const double _diameter = 34;

  /// Marcador del micro.
  ///
  /// - `iconKey` lleva el COLOR: la caché de imágenes del rasterizador es
  ///   global y su clave salía del id (`route-shape-bus`, igual en todas las
  ///   líneas), así que el primer recorrido abierto fijaba el color del disco
  ///   para todos los demás.
  /// - La caja deja [kMarkerShadowMargin] de aire: con el disco ocupando toda
  ///   la imagen, la sombra se recortaba contra el cuadrado y solo quedaban
  ///   sus cuatro esquinas, unas «puntas» oscuras alrededor del círculo.
  static MapMarker marker({
    required String id,
    required LatLng point,
    required Color color,
  }) => MapMarker(
    id: id,
    point: point,
    width: _diameter + kMarkerShadowMargin * 2,
    height: _diameter + kMarkerShadowMargin * 2,
    iconKey: 'route-bus-${color.toARGB32().toRadixString(16)}',
    child: RouteBusMarker(color: color),
  );

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 5),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.directions_bus_rounded,
        size: 19,
        color: AppColors.onColor(color),
      ),
    ),
  );
}
