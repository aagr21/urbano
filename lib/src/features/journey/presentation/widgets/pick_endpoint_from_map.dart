import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/reverse_geocoding.dart';
import '../../domain/journey_place.dart';

/// Elige un extremo (origen o destino) desde el mapa, con reverse geocoding.
///
/// Navega a `/journey/pick`, espera el punto seleccionado y lo convierte en
/// un [JourneyPlacePoint] con la dirección geocodificada.
Future<JourneyPlacePoint?> pickEndpointFromMap({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  JourneyPoint? currentPoint,
}) async {
  final params = <String, String>{'title': title};
  if (currentPoint != null) {
    params['lat'] = '${currentPoint.lat}';
    params['lon'] = '${currentPoint.lon}';
  }

  final point = await context.push<JourneyPoint>(
    Uri(path: '/journey/pick', queryParameters: params).toString(),
  );

  if (point == null || !context.mounted) return null;

  String? address;
  try {
    final result = await ref.read(
      reverseGeocodeProvider(LatLng(point.lat, point.lon)).future,
    );
    address = result?.shortFormatted;
  } catch (_) {}

  return JourneyPlacePoint(lat: point.lat, lon: point.lon, address: address);
}
