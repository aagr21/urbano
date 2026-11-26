import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/map/map.dart';
import '../../../core/theme/app_colors.dart';
import '../../journey/presentation/journey_markers.dart';
import '../../stops/data/stop_search_models.dart';
import '../domain/nearby_micros.dart';

/// Capas del mapa de «Micros cerca», armadas en un solo sitio y en orden de
/// lectura (lo de abajo se pinta primero).
class NearbyMapLayers {
  const NearbyMapLayers(this.polylines, this.markers);

  final List<MapPolyline> polylines;
  final List<MapMarker> markers;

  static NearbyMapLayers build({
    required NearbyQuery query,
    required List<StopHit> stops,
    required NearbyMicro? micro,
    required NearbyBoarding? boarding,
    required List<LatLng> shape,
    required Color zoneColor,
    required Color walkColor,
    required Color stopColor,
  }) {
    final routeColor = micro == null
        ? null
        : AppColors.fromHex(micro.route.color);
    final polylines = <MapPolyline>[
      // Zona buscada: un aro punteado, fino, que no compite con la ruta.
      MapPolyline(
        points: circlePath(query.point, query.radiusMeters.toDouble()),
        color: zoneColor,
        width: 2,
        opacity: 0.75,
        dashed: true,
      ),
      if (routeColor != null)
        MapPolyline(points: shape, color: routeColor, width: 6, outline: true),
      // Tramo a pie del lugar a la parada de subida.
      if (boarding != null)
        MapPolyline(
          points: [query.point, boarding.point],
          color: walkColor,
          width: 3,
          dashed: true,
        ),
    ];

    final markers = <MapMarker>[
      // Paradas de la zona: puntos discretos (la elegida se pinta aparte).
      for (final stop in stops)
        if (stop.id != boarding?.stopId)
          MapMarker(
            id: 'nearby-stop-${stop.id}',
            point: LatLng(stop.lat, stop.lon),
            width: 10 + kMarkerShadowMargin * 2,
            height: 10 + kMarkerShadowMargin * 2,
            iconKey: 'nearby-stop-dot-${stopColor.toARGB32()}',
            child: MapStopDot(color: stopColor, size: 10),
          ),
      if (routeColor != null) ...[
        ...routeArrowMarkers(
          idPrefix: 'nearby-arrow-${micro!.route.id}',
          path: shape,
          color: routeColor,
          spacingMeters: arrowSpacingFor(pathLengthMeters(shape)),
        ),
        if (micro.route.shortName.trim().isNotEmpty)
          MapMarker(
            id: 'nearby-route-badge',
            point: routePathMidpoint(shape),
            width: routeBadgeWidth(micro.route.shortName.trim()),
            height: routeBadgeHeight,
            iconKey:
                'route-badge-${micro.route.id}-${micro.route.shortName}-'
                '${micro.route.color}',
            child: MapRouteBadge(
              label: micro.route.shortName.trim(),
              color: routeColor,
            ),
          ),
      ],
      if (boarding != null && routeColor != null)
        MapMarker(
          id: 'nearby-boarding',
          point: boarding.point,
          width: stopDotBox + 6,
          height: stopDotBox + 6,
          iconKey: 'nearby-boarding-${micro!.route.color}',
          child: MapStopDot(color: routeColor, size: 22),
        ),
      MapMarker(
        id: 'nearby-place',
        point: query.point,
        width: MapPlacePin.widthFor(34),
        height: MapPlacePin.heightFor(34),
        anchor: MapMarkerAnchor.bottom,
        iconKey: 'nearby-place-pin',
        child: const MapPlacePin(color: AppColors.accent, size: 34),
      ),
    ];
    return NearbyMapLayers(polylines, markers);
  }
}
