import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../stops/data/stop_search_models.dart';
import '../../stops/data/stop_search_repository.dart';
import '../domain/nearby_micros.dart';

/// Máximo de paradas que se piden a `/stops/nearby` (el tope del backend).
const int kNearbyStopLimit = 50;

/// Lo que devuelve una consulta de «Micros cerca»: las paradas (para el mapa)
/// y las líneas agrupadas con su embarque por sentido (para la lista).
class NearbyResult {
  const NearbyResult({required this.stops, required this.micros});

  final List<StopHit> stops;
  final List<NearbyMicro> micros;

  bool get isEmpty => micros.isEmpty;
}

/// Paradas a ≤ `radiusMeters` del punto y las líneas que pasan por ellas.
///
/// Family por consulta completa (punto + radio): cambiar el radio es otra
/// consulta, y volver al anterior sale de la caché del repositorio.
final nearbyMicrosProvider = FutureProvider.autoDispose
    .family<NearbyResult, NearbyQuery>((ref, query) async {
      final stops = await ref
          .watch(stopSearchRepositoryProvider)
          .nearby(
            lat: query.lat,
            lon: query.lon,
            radiusMeters: query.radiusMeters,
            limit: kNearbyStopLimit,
          );
      return NearbyResult(
        stops: stops,
        micros: groupNearbyMicros(stops, query.point),
      );
    });

/// Línea y sentido que el mapa está dibujando.
typedef NearbySelection = ({String routeId, int directionId});

/// Selección activa de la vista. Vive fuera del `State` para que la lista,
/// el mapa y la tarjeta expandida lean la misma fuente; muere con la vista.
final nearbySelectionProvider =
    NotifierProvider.autoDispose<NearbySelectionController, NearbySelection?>(
      NearbySelectionController.new,
    );

class NearbySelectionController extends AutoDisposeNotifier<NearbySelection?> {
  @override
  NearbySelection? build() => null;

  /// Selecciona un sentido; tocar el mismo otra vez lo deja seleccionado
  /// (el mapa no se queda vacío por un doble toque).
  void select(String routeId, int directionId) {
    state = (routeId: routeId, directionId: directionId);
  }

  /// Toca la tarjeta de una línea: si ya estaba elegida no cambia nada; si no,
  /// abre su sentido más cercano.
  void focusMicro(NearbyMicro micro) {
    if (state?.routeId == micro.route.id) return;
    select(micro.route.id, micro.nearest.directionId);
  }

  void clear() => state = null;
}
