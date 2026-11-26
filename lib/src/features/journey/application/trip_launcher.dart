import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/journey_place.dart';
import 'journey_planner_controller.dart';
import 'saved_trips_controller.dart';
import 'trip_history_controller.dart';

/// Caso de uso «planificar este viaje» de la portada: deja los extremos en el
/// planeador, envía la consulta y lo anota en viajes guardados e historial.
///
/// No navega ni cierra hojas (eso es de la presentación): así se prueba con
/// un `ProviderContainer`, sin widgets (`test/trip_launcher_test.dart`).
class TripLauncher {
  const TripLauncher(this._ref);

  final Ref _ref;

  Future<void> launch({
    required JourneyPlace origin,
    required JourneyPlace destination,
  }) async {
    _ref.read(journeyPlannerControllerProvider.notifier)
      ..setPlace(origin, isOrigin: true)
      ..setPlace(destination, isOrigin: false)
      // Se planifica ya: los resultados llegan mientras se cambia a Viaje.
      ..submit();
    await _ref
        .read(savedTripsControllerProvider.notifier)
        .add(origin: origin, destination: destination);
    await _ref
        .read(tripHistoryControllerProvider.notifier)
        .record(destination: destination);
  }
}

final tripLauncherProvider = Provider<TripLauncher>(TripLauncher.new);
