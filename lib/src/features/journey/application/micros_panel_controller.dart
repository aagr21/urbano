import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routes/data/route_models.dart';
import '../../routes/data/route_repository.dart';
import '../../stops/data/stop_search_models.dart';
import 'journey_planner_controller.dart';
import 'journey_providers.dart';
import 'micros_catalog.dart';

/// Instantánea inmutable que publica [MicrosPanelController].
///
/// El store de trabajo ([JourneyMicrosSession]) es mutable y **no notifica**;
/// este snapshot es la señal de cambio: cada comando del controller muta la
/// sesión y publica una instancia nueva para que el panel se reconstruya.
class MicrosPanelSnapshot {
  const MicrosPanelSnapshot({this.busyKey, this.placesDraft = ''});

  /// Clave (`routeId#directionId`) del toggle en curso: bloquea dobles toques
  /// y las acciones rápidas mientras hay una petición andando.
  final String? busyKey;

  /// Borrador del buscador de lugares, AÚN SIN COMMIT: teclear solo guarda el
  /// borrador; la petición se dispara al confirmar (teclado o botón).
  final String placesDraft;

  bool get locked => busyKey != null;
}

/// Lógica de estado y negocio del **panel de micros**: descarga del catálogo,
/// filtro de líneas, modos (líneas ⇆ lugares), toggles de ida/vuelta y
/// activar/limpiar todo.
///
/// El panel (`MicrosPanelState`) queda con lo que solo puede vivir en un
/// widget: animaciones, gestos, `TextEditingController` y scroll. Todo lo que
/// se puede probar sin árbol está aquí.
///
/// Es un `NotifierProvider` vivo con la app (no `autoDispose`) porque su
/// estado de trabajo — igual que [JourneyMicrosSession] — tiene que sobrevivir
/// a cerrar y reabrir el cajón, y porque la carga del catálogo ocurre ANTES de
/// montar la ruta del panel.
class MicrosPanelController extends Notifier<MicrosPanelSnapshot> {
  /// Tamaño de página de `/routes` (el backend limita `limit` a 100).
  static const int pageSize = 100;

  @override
  MicrosPanelSnapshot build() => const MicrosPanelSnapshot();

  // ------------------------------------------------------------------
  // Lectura del store (sesión persistente + planeador)
  // ------------------------------------------------------------------

  /// Estado de trabajo que sobrevive a cerrar el panel.
  JourneyMicrosSession get session => ref.read(journeyMicrosSessionProvider);

  JourneyPlannerController get _planner =>
      ref.read(journeyPlannerControllerProvider.notifier);

  /// Recorridos dibujados AHORA en el mapa (`routeId#directionId`), leídos
  /// frescos del controller: activar una ruta cambia este conjunto a mitad de
  /// un recorrido por el catálogo.
  Set<String> get activeKeys =>
      ref.read(journeyPlannerControllerProvider).visibleRouteKeys;

  List<RouteSummary> get micros => session.micros;

  String get query => session.query;

  String get placesQuery => session.placesQuery;

  bool get placesMode => session.placesMode;

  String get placesDraft => state.placesDraft;

  bool get locked => state.locked;

  String? get busyKey => state.busyKey;

  /// Micros visibles según el texto del buscador (filtrado local).
  List<RouteSummary> get visibleMicros =>
      filterMicros(session.micros, session.query);

  /// Direcciones dibujables de un micro (detalle ya cacheado o 0/1 por
  /// defecto).
  List<MicroDirection> directionsOf(RouteSummary micro) =>
      directionsOfMicro(micro, session.details[micro.id]);

  /// `true` si el recorrido (ida) de esta línea ya está dibujado en el mapa.
  bool routeActive(StopRouteRef route) =>
      activeKeys.contains(microDirectionKey(route.id, 0));

  /// Texto que debe mostrar el buscador en el modo indicado (el campo se
  /// reinicia con la consulta de SU modo al cambiar de pestaña).
  String searchTextForMode(bool places) =>
      places ? session.placesQuery : session.query;

  // ------------------------------------------------------------------
  // Catálogo
  // ------------------------------------------------------------------

  /// Abre una sesión del panel: descarta un `busyKey` que quedó de un cierre a
  /// mitad de un toggle y restaura el borrador de lugares desde la sesión.
  void startSession() {
    state = MicrosPanelSnapshot(placesDraft: session.placesQuery);
  }

  /// Con el listado ya en la sesión no se toca la red: reabrir es
  /// instantáneo. Si vino vacío (feed sin rutas o petición fallida) `loaded`
  /// sigue `false` y la próxima apertura lo vuelve a intentar.
  Future<void> ensureCatalog() async {
    if (session.loaded) return;
    final micros = await _fetchAllMicros();
    session.micros = micros;
    session.loaded = micros.isNotEmpty;
    _publish();
  }

  /// "Jalar para actualizar": vuelve a pagar `/routes` y reemplaza el catálogo
  /// (las líneas activas en el mapa no se tocan).
  Future<void> refreshCatalog() async {
    final micros = await _fetchAllMicros();
    if (micros.isEmpty) return;
    session.micros = micros;
    session.loaded = true;
    _publish();
  }

  /// Descarga **todas** las líneas paginando `/routes` hasta cubrir
  /// `meta.total`, ordenadas por numeral. Ante un error devuelve lo acumulado
  /// hasta ese momento (o vacío si falló la primera página).
  Future<List<RouteSummary>> _fetchAllMicros() async {
    final repository = ref.read(routeRepositoryProvider);
    try {
      final first = await repository.list(limit: pageSize, sort: 'name');
      final micros = [...first.items];
      var page = 1;
      while (micros.length < first.meta.safeTotal) {
        page++;
        final next = await repository.list(
          page: page,
          limit: pageSize,
          sort: 'name',
        );
        if (next.items.isEmpty) break; // defensa contra bucles infinitos.
        micros.addAll(next.items);
      }
      return micros;
    } catch (_) {
      return const <RouteSummary>[];
    }
  }

  // ------------------------------------------------------------------
  // Buscador y modos
  // ------------------------------------------------------------------

  /// Tecla en el buscador: en LÍNEAS filtra en vivo (local); en LUGARES solo
  /// guarda el borrador (la petición espera al commit).
  void setSearchText(String value) {
    if (placesMode) {
      state = MicrosPanelSnapshot(busyKey: state.busyKey, placesDraft: value);
      return;
    }
    session.query = value;
    _publish();
  }

  void clearLineQuery() {
    session.query = '';
    _publish();
  }

  /// COMMIT de la búsqueda de lugares: el texto queda en la sesión y la lista
  /// de resultados vuela (indicadores de `AsyncValueView` + caché TTL si la
  /// consulta ya pasó por el repositorio).
  void commitPlacesSearch() {
    session.placesQuery = state.placesDraft.trim();
    _publish();
  }

  /// Borra la búsqueda de lugares (borrador Y confirmada) — vuelve a la guía
  /// de «cerca de mí».
  void clearPlacesSearch() {
    state = MicrosPanelSnapshot(busyKey: state.busyKey);
    session.placeResults = null;
    session.placesNearbyPoint = null;
    session.placesQuery = '';
    _planner.clearPlaceMarkers();
  }

  /// Cambia de modo (líneas ⇆ lugares). Al salir de lugares se quitan sus
  /// marcadores del mapa (los recorridos dibujados quedan: esos los apaga
  /// «Limpiar»). El campo lo reinicia el panel con [searchTextForMode].
  void switchMode(bool toPlaces) {
    if (!toPlaces) _planner.clearPlaceMarkers();
    session.placesMode = toPlaces;
    state = MicrosPanelSnapshot(
      busyKey: state.busyKey,
      placesDraft: toPlaces ? session.placesQuery : state.placesDraft,
    );
  }

  /// «Cerca de mí» y «marcar en el mapa» fijan el punto a consultar y limpian
  /// la consulta confirmada: el listado de cercanas se refresca solo.
  void applyPlacesPoint(({double lat, double lon}) point) {
    session.placesQuery = '';
    session.placesNearbyPoint = point;
    _publish();
  }

  // ------------------------------------------------------------------
  // Recorridos
  // ------------------------------------------------------------------

  /// Carga el detalle del micro (si falta) y delega el dibuja/borra de la
  /// dirección en la pantalla padre.
  ///
  /// Ya no hay `if (!mounted)`: el controller no muere con el panel, así que
  /// cerrar el cajón a mitad de la carga no cancela una acción que el usuario
  /// pidió (antes se descartaba).
  Future<void> toggleDirection(
    RouteSummary micro,
    int directionId, {
    required Future<void> Function(RouteSummary micro, int directionId)
    onToggle,
  }) async {
    if (locked) return;
    _setBusy(microDirectionKey(micro.id, directionId));
    try {
      await _ensureDetail(micro);
      await onToggle(micro, directionId);
    } finally {
      _setBusy(null);
    }
  }

  /// Dibuja/borra en el mapa el recorrido COMPLETO de UNA línea del resultado
  /// (ida y vuelta juntas), no una sola orientación: «Ver ruta» muestra la
  /// línea entera. La bandera se decide con la ida y luego la vuelta se aplica
  /// solo si está en el estado contrario (y la ruta realmente la tiene: una de
  /// mano única no tiene vuelta).
  Future<void> toggleStopRoute(
    StopRouteRef route, {
    required Future<void> Function(RouteSummary micro, int directionId)
    onToggle,
  }) async {
    if (locked) return;
    final summary = summaryForStopRoute(route);
    final turnOff = routeActive(route);
    await toggleDirection(summary, 0, onToggle: onToggle);
    // El detalle de la ruta ya quedó cacheado por el toggle de la ida, así que
    // aquí sabemos si de verdad existe la vuelta.
    final detail = session.details[route.id];
    final hasVuelta =
        detail == null || detail.directions.any((d) => d.directionId == 1);
    final vueltaActive = activeKeys.contains(microDirectionKey(route.id, 1));
    if (hasVuelta && turnOff == vueltaActive) {
      await toggleDirection(summary, 1, onToggle: onToggle);
    }
  }

  /// «Activar todas»: dibuja cada dirección del catálogo que aún no esté en el
  /// mapa, saltando las ya activas.
  Future<void> activateAll({
    required Future<void> Function(RouteSummary micro, int directionId)
    onToggle,
  }) async {
    for (final micro in session.micros) {
      for (final direction in directionsOf(micro)) {
        if (activeKeys.contains(
          microDirectionKey(micro.id, direction.directionId),
        )) {
          continue;
        }
        await toggleDirection(micro, direction.directionId, onToggle: onToggle);
      }
    }
  }

  /// «Limpiar»: apaga todos los recorridos dibujados (la pantalla es la dueña
  /// del controller del planeador).
  void clearAll(void Function() onClearAll) {
    if (locked) return;
    onClearAll();
    _publish();
  }

  Future<void> _ensureDetail(RouteSummary micro) async {
    if (session.details.containsKey(micro.id)) return;
    try {
      session.details[micro.id] = await ref
          .read(routeRepositoryProvider)
          .detail(micro.id);
    } catch (_) {
      // Sin detalle igual podemos dibujar: el padre pide su propia polilínea;
      // aquí solo perdemos los headsign en los botones.
    }
  }

  void _setBusy(String? key) =>
      state = MicrosPanelSnapshot(busyKey: key, placesDraft: state.placesDraft);

  /// Republica el snapshot (la sesión cambió y la UI tiene que releerla).
  void _publish() => state = MicrosPanelSnapshot(
    busyKey: state.busyKey,
    placesDraft: state.placesDraft,
  );
}

/// Estado de trabajo del panel de micros (vivo con la app).
final microsPanelProvider =
    NotifierProvider<MicrosPanelController, MicrosPanelSnapshot>(
      MicrosPanelController.new,
    );
