import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/features/journey/application/journey_planner_controller.dart';
import 'package:urbano/src/features/journey/domain/journey_place.dart';

/// Planifica un viaje como lo hace la hoja «¿A dónde vas?» de la portada:
/// fija origen y destino en el planeador y envía la consulta.
///
/// `/journey` ya no tiene globo ni panel de origen/destino, así que los tests
/// arman el viaje por aquí y luego ejercitan el mapa y la hoja de resultados.
Future<void> planTripFromHome(
  WidgetTester tester,
  ProviderContainer container, {
  required LatLng origin,
  required LatLng destination,
  bool settle = true,
}) async {
  container.read(journeyPlannerControllerProvider.notifier)
    ..setPlace(
      JourneyPlacePoint(lat: origin.latitude, lon: origin.longitude),
      isOrigin: true,
    )
    ..setPlace(
      JourneyPlacePoint(lat: destination.latitude, lon: destination.longitude),
      isOrigin: false,
    )
    ..submit();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
