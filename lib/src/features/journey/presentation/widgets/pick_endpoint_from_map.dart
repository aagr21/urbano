import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/location/reverse_geocoding.dart';
import '../../domain/journey_place.dart';

/// Ruta del selector de punto: `/journey/pick?title=…[&lat=…&lon=…]`.
///
/// Se arma con `Uri(path:, queryParameters:)` (un solo `?`): concatenar otro
/// `?` a mano dejaba `/journey/pick??title=…` y el selector perdía el título
/// y el punto inicial. Con [current] el selector ABRE ENCIMA de ese punto.
String mapPickerLocation({required String title, JourneyPoint? current}) => Uri(
  path: '/journey/pick',
  queryParameters: {
    'title': title,
    if (current != null) 'lat': '${current.lat}',
    if (current != null) 'lon': '${current.lon}',
  },
).toString();

/// Elige un extremo (origen o destino) desde el mapa, con reverse geocoding.
///
/// Navega al selector, espera el punto y lo devuelve como [JourneyPlacePoint]
/// con su dirección (sin red queda solo el punto: la dirección es un extra).
Future<JourneyPlacePoint?> pickEndpointFromMap({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  JourneyPoint? currentPoint,
}) async {
  final point = await context.push<JourneyPoint>(
    mapPickerLocation(title: title, current: currentPoint),
  );
  if (point == null || !context.mounted) return null;

  String? address;
  try {
    final result = await ref.read(
      reverseGeocodeProvider(LatLng(point.lat, point.lon)).future,
    );
    address = result?.shortFormatted;
  } catch (_) {
    // El geocodificador es un extra: sin él queda el punto.
  }
  return JourneyPlacePoint(lat: point.lat, lon: point.lon, address: address);
}
