import 'package:latlong2/latlong.dart';

import '../../../core/map/map.dart';
import 'journey_place.dart';

/// Sentinel para "no toques este campo" en [JourneyPlannerState.copyWith]:
/// los parámetros van tipados como `Object?` así `null` significa LIMPIAR
/// (poner `null` en el campo) y omitir el parámetro significa CONSERVAR.
const Object keepJourneyField = Object();

/// Estado completo del **planeador de viaje**: los lugares marcados, la
/// consulta comprometida (con el par planificado separado del mostrado), la
/// selección de opción del panel de resultados y las capas de micros del modo
/// exploración.
///
/// Dato puro (sin Riverpod): el [Notifier] avisa por identidad, no por
/// igualdad profunda. Cada mutación produce un objeto nuevo vía [copyWith].
class JourneyPlannerState {
  const JourneyPlannerState({
    this.origin,
    this.destination,
    this.planOrigin,
    this.planDestination,
    this.time,
    this.submitted = false,
    this.replanPending = false,
    this.selectedOptionIndex = 0,
    this.expandedIndex,
    this.routeLines = const {},
    this.routeMarkers = const {},
    this.visibleRouteKeys = const {},
    this.placeMarkers = const [],
    this.loadingRoutes = false,
  });

  /// Lugares que muestran los campos.
  final JourneyPlace? origin;
  final JourneyPlace? destination;

  /// Puntos que viajan a la consulta de planificación. Selector, swap,
  /// limpiar y planificar los mantienen al día al momento.
  final JourneyPlace? planOrigin;
  final JourneyPlace? planDestination;

  /// Hora de salida personalizada (`HH:mm`), o `null` = ahora.
  final String? time;

  /// `true` después de planificar: al estado se añade la hoja de resultados.
  final bool submitted;

  /// `true` entre el drop del marcador y la aplicación del nuevo punto
  /// (debounce para no re-planificar con micro-movimientos).
  final bool replanPending;

  /// Opción mostrada en el mapa (índice 0 por defecto).
  final int selectedOptionIndex;

  /// Índice de opción expandida en la hoja de resultados, `null` = ninguna.
  final int? expandedIndex;

  /// Polilíneas de exploración (micros del panel), por clave
  /// `routeId#directionId`.
  final Map<String, MapPolyline> routeLines;

  /// Insignia (número/nombre del micro) colocada sobre el punto medio de cada
  /// recorrido activado, igual que en la planificación del viaje.
  final Map<String, MapMarker> routeMarkers;

  /// Recorridos dibujados, por clave igual que arriba (ida y vuelta son capas
  /// independientes).
  final Set<String> visibleRouteKeys;

  /// Marcadores del **modo lugares** del panel: el pin del punto consultado y
  /// un punto por cada parada devuelta. Viven aquí (no en el `State` del panel,
  /// que es una ruta encima) para que el mapa SIEMPRE montado del planeador los
  /// dibuje mientras el cajón está abierto.
  final List<MapMarker> placeMarkers;

  /// `true` mientras una polilínea de micro se descarga.
  final bool loadingRoutes;

  /// `true` cuando el panel de origen/destino tiene los dos extremos listos.
  bool get ready => origin != null && destination != null;

  /// Distancia en línea recta entre los dos puntos elegidos, o `null` si
  /// aún falta alguno.
  double? get endpointsDistanceM {
    final src = origin.pointOrNull;
    final dst = destination.pointOrNull;
    if (src == null || dst == null) return null;
    return const Distance().as(
      LengthUnit.Meter,
      LatLng(src.lat, src.lon),
      LatLng(dst.lat, dst.lon),
    );
  }

  /// Origen y destino están (casi) en el mismo sitio: no hay viaje que
  /// planificar.
  bool get endpointsTooClose =>
      (endpointsDistanceM ?? double.infinity) < minTransitDistanceM;

  /// Distancia mínima (línea recta) entre origen y destino para planificar
  /// en transporte: por debajo, caminar es más rápido. Coincide con el guard
  /// del backend (`MIN_TRANSIT_DISTANCE_M` en journey.service.ts).
  static const double minTransitDistanceM = 150.0;

  /// Copia con cambios: cada mutación produce un objeto nuevo (el [Notifier]
  /// avisa por identidad, no por igualdad profunda).
  ///
  /// Convención con sentinel [keepJourneyField]:
  /// omitir el parámetro → el campo CONSERVA su valor; pasar `null` → LIMPIA
  /// el campo; pasar un valor → lo reemplaza.
  JourneyPlannerState copyWith({
    Object? origin = keepJourneyField,
    Object? destination = keepJourneyField,
    Object? planOrigin = keepJourneyField,
    Object? planDestination = keepJourneyField,
    Object? time = keepJourneyField,
    bool? submitted,
    bool? replanPending,
    int? selectedOptionIndex,
    Object? expandedIndex = keepJourneyField,
    Map<String, MapPolyline>? routeLines,
    Map<String, MapMarker>? routeMarkers,
    Set<String>? visibleRouteKeys,
    List<MapMarker>? placeMarkers,
    bool? loadingRoutes,
  }) {
    T? take<T>(Object? v, T? old) =>
        identical(v, keepJourneyField) ? old : v as T?;
    return JourneyPlannerState(
      origin: take(origin, this.origin),
      destination: take(destination, this.destination),
      planOrigin: take(planOrigin, this.planOrigin),
      planDestination: take(planDestination, this.planDestination),
      time: take(time, this.time),
      submitted: submitted ?? this.submitted,
      replanPending: replanPending ?? this.replanPending,
      selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
      expandedIndex: take(expandedIndex, this.expandedIndex),
      routeLines: routeLines ?? this.routeLines,
      routeMarkers: routeMarkers ?? this.routeMarkers,
      visibleRouteKeys: visibleRouteKeys ?? this.visibleRouteKeys,
      placeMarkers: placeMarkers ?? this.placeMarkers,
      loadingRoutes: loadingRoutes ?? this.loadingRoutes,
    );
  }
}
