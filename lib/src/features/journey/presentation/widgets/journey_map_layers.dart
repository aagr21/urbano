import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/map/map.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/urbano_map.dart';
import '../../application/journey_map_geometry.dart';
import '../../application/leg_stroke_colors.dart';
import '../../data/journey_models.dart';
import '../journey_markers.dart';

/// Estilo de las capas del viaje en el mapa: convierte la geometría pura de
/// [JourneyMapGeometry] en polilíneas y marcadores con sus colores. Sin
/// estado: el mapa solo decide CUÁNDO pintarlas.
abstract final class JourneyMapLayers {
  /// Alto (px lógicos) de los pines de origen/destino.
  static const double endpointPinSize = 40;

  /// Caminatas punteadas en gris y micros con su color (cada tramo distinto
  /// de los demás y del gris de la caminata: `LegStrokeColors.forLegs`).
  /// `mapPoints` ya viene en el sentido del tramo (fromStop → toStop): no se
  /// compara con el origen/destino del usuario.
  static List<MapPolyline> polylines(
    JourneyOption option,
    LatLng origin,
    LatLng destination,
  ) {
    final legAltColors = LegStrokeColors.forLegs(option.legs);
    return [
      for (final path in JourneyMapGeometry.walkPaths(
        option,
        origin,
        destination,
      ))
        MapPolyline(
          points: path,
          width: 4,
          color: LegStrokeColors.walk,
          dashed: true,
        ),
      for (final leg in option.busLegs)
        if (leg.mapPoints case final path? when path.isNotEmpty)
          MapPolyline(
            points: path,
            width: 6,
            color: busLegStrokeColor(
              legAltColors[option.legs.indexOf(leg)] ?? leg.routeColor,
            ),
            outline: true,
          ),
    ];
  }

  /// Insignia de cada micro sobre el punto medio de su tramo, con el color
  /// de su línea (o el alternativo del transbordo).
  static List<MapMarker> routeBadges(JourneyOption option) {
    final legAltColors = LegStrokeColors.forLegs(option.legs);
    final busLegs = option.busLegs;
    final markers = <MapMarker>[];
    for (var i = 0; i < busLegs.length; i++) {
      final leg = busLegs[i];
      final path = leg.mapPoints;
      final name = leg.routeShortName;
      if (path == null || path.isEmpty || name == null || name.isEmpty) {
        continue;
      }
      final colorHex = legAltColors[option.legs.indexOf(leg)] ?? leg.routeColor;
      final label = name.trim();
      markers.add(
        MapMarker(
          id: 'journey-map-route-$i',
          point: routePathMidpoint(path),
          // La insignia mide distinto por ruta para no compartir caché con
          // un badge de otro color/texto.
          width: routeBadgeWidth(label),
          height: routeBadgeHeight,
          iconKey: 'route-badge-${leg.routeId ?? label}-$label-$colorHex',
          child: MapRouteBadge(
            key: ValueKey('journey-map-route-$i'),
            label: label,
            color: AppColors.fromHex(colorHex),
          ),
        ),
      );
    }
    return markers;
  }

  /// Flechas de sentido a lo largo de cada tramo de micro, en el MISMO color
  /// que su trazo (la flecha es parte de la línea). El reparto y el rumbo
  /// son puros (`domain/route_arrows.dart`).
  static List<MapMarker> routeArrows(JourneyOption option) {
    final legAltColors = LegStrokeColors.forLegs(option.legs);
    return [
      for (final leg in option.busLegs)
        if (leg.mapPoints case final path? when path.length >= 2)
          ...routeArrowMarkers(
            idPrefix: 'journey-map-arrow-${option.legs.indexOf(leg)}',
            path: path,
            color: busLegStrokeColor(
              legAltColors[option.legs.indexOf(leg)] ?? leg.routeColor,
            ),
          ),
    ];
  }

  /// Pines de origen/destino (fijos y tocables). Se pintan aunque no haya
  /// resultados: lo que el usuario fijó debe verse en el mapa.
  static List<MapMarker> endpoints({
    required LatLng origin,
    required LatLng destination,
    required bool showOrigin,
    required bool showDestination,
    VoidCallback? onOriginTap,
    VoidCallback? onDestinationTap,
  }) => [
    if (showOrigin)
      _endpoint('journey-map-origin', origin, AppColors.success, onOriginTap),
    if (showDestination)
      _endpoint(
        'journey-map-destination',
        destination,
        AppColors.danger,
        onDestinationTap,
      ),
  ];

  static MapMarker _endpoint(
    String id,
    LatLng point,
    Color color,
    VoidCallback? onTap,
  ) => MapMarker(
    id: id,
    point: point,
    width: EndpointMarker.widthFor(endpointPinSize),
    height: EndpointMarker.heightFor(endpointPinSize),
    anchor: MapMarkerAnchor.bottom,
    onTap: onTap,
    child: EndpointMarker(key: ValueKey(id), color: color, onTap: onTap),
  );

  /// Color del trazo de un tramo de micro (GTFS o alternativo). Lo usan la
  /// polilínea y sus flechas: una sola fuente para que nunca diverjan.
  ///
  /// OPACO a propósito: el motor nativo descarta el alfa del color de una
  /// línea, así que un trazo «al 92 %» se pintaba opaco mientras la flecha
  /// rasterizada sí quedaba translúcida.
  static Color busLegStrokeColor(String? hex) => AppColors.fromHex(hex);

  /// Clave de la imagen de una flecha: depende SOLO de su color (todas las
  /// flechas del mismo trazo comparten una imagen nativa).
  static String arrowIconKey(Color color) => routeArrowIconKey(color);
}
