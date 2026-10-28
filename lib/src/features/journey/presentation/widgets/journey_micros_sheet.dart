import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/map_theme_scope.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../routes/data/route_models.dart';
import '../../../routes/data/route_repository.dart';
import '../../../stops/data/stop_search_models.dart';
import '../../../stops/presentation/stop_search_providers.dart';
import '../journey_markers.dart';
import '../journey_planner_controller.dart';
import '../journey_providers.dart';
import 'journey_micros_tile.dart';
import 'micros_places_list.dart';

part 'micros_panel_sections.dart';

/// Panel de **micros**: un cajón que se desliza de izquierda a derecha sobre
/// el mapa (no un bottom sheet). Lista **todas** las líneas del sistema con
/// buscador; cada línea es una tarjeta con su insignia y dos botones
/// independientes —**Ida** y **Vuelta**— que dibujan/borran ese recorrido
/// sobre el mapa.
///
/// El trabajo hecho aquí **persiste** mientras la app esté abierta: búsqueda,
/// scroll, listado descargado y headsign consultados viven en
/// [journeyMicrosSessionProvider], así que cerrar y reabrir el panel devuelve
/// exactamente el mismo estado (y abre al instante, sin volver a pagar
/// `/routes`). Para refrescar el catálogo hay "jalar para actualizar".
Future<void> showJourneyMicrosPanel(
  BuildContext context, {
  required WidgetRef ref,
  required Set<String> Function() activeDirectionKeys,
  required Future<void> Function(RouteSummary micro, int directionId)
  onToggleDirection,
  required VoidCallback onClearAll,
  void Function(List<({double lat, double lon})> points)? onFramePlaces,
}) async {
  final session = ref.read(journeyMicrosSessionProvider);

  // Con el listado ya en la sesión no se toca la red: reabrir es instantáneo.
  // Si vino vacío (feed sin rutas o petición fallida) `loaded` sigue `false`
  // y la próxima apertura vuelve a intentarlo.
  if (!session.loaded) {
    final micros = await _fetchAllMicros(ref);
    session.micros = micros;
    session.loaded = micros.isNotEmpty;
  }

  if (!context.mounted) return;

  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'Cerrar panel de micros',
      // Nombre de la ruta: la pantalla Viaje lo usa para sacar del stack
      // cualquier panel viejo antes de abrir uno nuevo (reabrir «Ver todas»
      // con el cajón a medio cerrar nunca debe apilar dos paneles).
      settings: const RouteSettings(name: 'journey-micros-panel'),
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      // El brillo propio del mapa se instala AQUÍ, por ENCIMA del panel entero:
      // el panel es una RUTA montada en el `Overlay` del Navigator (fuera del
      // ámbito que pone la pantalla Viaje) y su `build` lee `context.colors`
      // para pintar el buscador, las tarjetas y el encabezado. Instalándolo aquí
      // ese `context` ya ve el modo del mapa; si se instalara solo dentro del
      // `build`, los colores que ese `build` captura seguirían siendo los de la
      // app (letra oscura sobre vidrio oscuro con mapa oscuro + app clara).
      pageBuilder: (_, _, _) => MapThemeScope(
        child: _MicrosPanel(
          ref: ref,
          session: session,
          activeDirectionKeys: activeDirectionKeys,
          onToggleDirection: onToggleDirection,
          onClearAll: onClearAll,
          onFramePlaces: onFramePlaces,
        ),
      ),
      // Entrada desde la izquierda: el panel se desliza hacia adentro
      // mientras el scrim (barrera oscura) se funde con la misma curva.
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        // Entra deslizándose desde la izquierda y con un leve crecimiento
        // (0.94 → 1) anclado al borde izquierdo: se "despliega" sobre el mapa.
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            alignment: Alignment.centerLeft,
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Descarga **todas** las rutas paginando `/routes` (100 por página) hasta
/// cubrir `meta.total` (el backend limita `limit` a 100). Ordenadas por
/// numeral (`sort: 'name'` → `route_short_name`). Ante un error devuelve lo
/// acumulado hasta ese momento (o vacío si falló la primera página).
Future<List<RouteSummary>> _fetchAllMicros(WidgetRef ref) async {
  const pageSize = 100;
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

/// Fundido + deslizamiento desde la izquierda para la entrada escalonada de
/// las secciones del panel (impulsado por [_entrance], va de 0 a 1 una vez).
Widget _rise(Animation<double> a, Widget child) => FadeTransition(
  opacity: a,
  child: SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(-0.05, 0),
      end: Offset.zero,
    ).animate(a),
    child: child,
  ),
);

/// Entrada escalonada del listado, calculada sobre el valor de [entrance]
/// (la `_entrance` del panel):
/// matemática pura en `build`, sin timers ni listeners por tarjeta. Así el
/// escalonado no se re-dispara al hacer scroll (en cuanto termina la entrada
/// la tarjeta ya sale en su sitio) y el árbol se asienta sin relojes
/// pendientes en los tests de widget.
Widget _stagger(AnimationController entrance, int index, Widget tile) {
  if (entrance.isCompleted) return tile;
  final start = math.min(0.4 + index * 0.05, 0.9);
  final t = Curves.easeOutCubic.transform(
    ((entrance.value - start) / 0.18).clamp(0.0, 1.0),
  );
  return Opacity(
    opacity: t,
    child: Transform.translate(offset: Offset(-16 * (1 - t), 0), child: tile),
  );
}

/// Panel lateral de micros: fondo `surface`, esquinas redondeadas a la
/// derecha y el listado a toda altura. El estado de verdad de los recorridos
/// activos vive en la pantalla padre (`_visibleRouteKeys`, pasado por
/// referencia) y el estado de trabajo (búsqueda, scroll, detalles) en la
/// sesión; en este `State` solo queda lo efímero: el toggle en vuelo
/// (`_pendingKey`) y las animaciones de entrada/cierre.
class _MicrosPanel extends StatefulWidget {
  const _MicrosPanel({
    required this.ref,
    required this.session,
    required this.activeDirectionKeys,
    required this.onToggleDirection,
    required this.onClearAll,
    this.onFramePlaces,
  });

  /// Acceso al repositorio de rutas desde el State (refresco de la lista).
  final WidgetRef ref;

  /// Estado que sobrevive a cerrar el panel.
  final JourneyMicrosSession session;
  final Set<String> Function() activeDirectionKeys;
  final Future<void> Function(RouteSummary micro, int directionId)
  onToggleDirection;
  final VoidCallback onClearAll;

  /// Encuadre del mapa (debajo del cajón) sobre el lugar marcado y sus
  /// paradas, para que el pin recién clavado se vea. `null` = sin capacidad
  /// de encuadrar (p. ej. harness de tests que abre el panel suelto).
  final void Function(List<({double lat, double lon})> points)? onFramePlaces;

  @override
  State<_MicrosPanel> createState() => _MicrosPanelState();
}

class _MicrosPanelState extends State<_MicrosPanel>
    with TickerProviderStateMixin {
  /// Reproducir UNA sola vez al abrir el panel (no en cada toggle/rebuild):
  /// controlador de entrada que escalona el fundido+deslizamiento de las
  /// secciones (encabezado, buscador y acciones).
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final Animation<double> _aHeader = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _aSearch = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.16, 0.66, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _aActions = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.32, 0.82, curve: Curves.easeOutCubic),
  );

  /// Muelle del arrastre horizontal: devuelve el panel a su sitio cuando el
  /// gesto no llegó al umbral de cierre.
  late final AnimationController _snap =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _dragDx = 0);
        }
      });
  late final Animation<double> _snapCurved = CurvedAnimation(
    parent: _snap,
    curve: Curves.easeOut,
  );

  /// Desplazamiento horizontal del arrastre (0 = pegado al borde; negativo
  /// mientras se tira hacia la izquierda para cerrar).
  double _dragDx = 0;
  Tween<double>? _snapFrom;

  /// Distancia de arrastre (px) que cierra el panel al soltar.
  static const double _dismissDrag = 88;

  /// Clave (`routeId#directionId`) del toggle en curso: bloquea dobles toques
  /// y las acciones rápidas mientras hay una petición andando.
  String? _pendingKey;

  /// Buscador: filtra el listado ya cargado por numeral, nombre o id. El
  /// texto vive en la sesión, así que reabrir el panel lo recupera.
  late final TextEditingController _searchController = TextEditingController(
    text: widget.session.query,
  );
  late final FocusNode _searchFocus = FocusNode()
    ..addListener(() {
      if (mounted) setState(() {}); // glow del campo al enfocar
    });
  late String _query = widget.session.query;

  /// Modo del panel: líneas (catálogo) o lugares (¿qué pasa por aquí?).
  bool get _placesMode => widget.session.placesMode;

  /// Texto del buscador de lugares, AÚN SIN COMMIT: buscar dispara la
  /// petición (acción de teclado o botón), teclar solo guarda el borrador —
  /// así no hay una petición de red por cada letra.
  String _placesDraft = '';

  /// Última consulta de lugares ya enviada (persistida en la sesión para
  /// que reabrir el panel la restaure junto con sus resultados).
  String get _placesQuery => widget.session.placesQuery;

  /// Scroll del listado: se restaura al abrir y se guarda al cerrar.
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: math.max(0.0, widget.session.scrollOffset),
  );

  bool get _locked => _pendingKey != null;

  /// Claves activas AHORA: el widget entrega un GETTER, no una copia — el
  /// snapshot por valor hacía que un toggle quedara pintado en el botón
  /// equivocado (stale) hasta reabrir el panel.
  Set<String> get _activeKeys => widget.activeDirectionKeys();

  /// Catálogo de líneas (persistido en la sesión).
  List<RouteSummary> get _micros => widget.session.micros;

  /// Offset mostrado: durante el arrastre sigue al dedo; al soltar sin cerrar,
  /// lo interpola el muelle [_snap].
  double get _shownDx {
    final from = _snapFrom;
    if (_snap.isAnimating && from != null) return from.evaluate(_snapCurved);
    return _dragDx;
  }

  /// Micros visibles según el texto de búsqueda (filtrado local).
  List<RouteSummary> get _filteredMicros {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _micros;
    return _micros
        .where(
          (micro) =>
              micro.shortName.toLowerCase().contains(q) ||
              micro.longName.toLowerCase().contains(q) ||
              micro.id.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Direcciones dibujables de un micro: las reales del detalle si ya se
  /// cargó (con su headsign), o `0`/`1` por defecto (GTFS: 0 = ida,
  /// 1 = vuelta) mientras no se conozcan.
  List<MicroDirection> _directionsOf(RouteSummary micro) {
    final detail = widget.session.details[micro.id];
    if (detail != null && detail.directions.isNotEmpty) {
      return [
        for (final d in detail.directions)
          MicroDirection(d.directionId, d.headsign),
      ];
    }
    final count = micro.directionsCount.clamp(1, 2);
    return [for (var i = 0; i < count; i++) MicroDirection(i, '')];
  }

  @override
  void initState() {
    super.initState();
    // El modo de lugares restaura su última consulta confirmada (borrador =
    // lo mismo que quedó, listo para refinar sin re-pedir).
    _placesDraft = widget.session.placesQuery;
    // El scroll se guarda EN CADA movimiento: al cerrar, los descendants se
    // desmontan antes de nuestro `dispose`, así que ahí el controller ya no
    // tiene clients y esperar al dispose perdería la posición.
    _scroll.addListener(_saveScrollOffset);
    _entrance.forward();
  }

  void _saveScrollOffset() {
    if (_scroll.hasClients) widget.session.scrollOffset = _scroll.offset;
  }

  @override
  void dispose() {
    // Se guarda el estado de trabajo EN la sesión: al reabrir el panel
    // siguen ahí la búsqueda y los headsign ya consultados (el scroll ya se
    // fue guardando con [_saveScrollOffset]).
    widget.session.query = _query;
    _saveScrollOffset();
    _entrance.dispose();
    _snap.dispose();
    _scroll.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Carga el detalle del micro (si falta) y delega el dibuja/borra de la
  /// dirección en la pantalla padre.
  Future<void> _toggle(RouteSummary micro, int directionId) async {
    if (_locked) return;
    final key = microDirectionKey(micro.id, directionId);
    setState(() => _pendingKey = key);
    try {
      if (!widget.session.details.containsKey(micro.id)) {
        try {
          final detail = await widget.ref
              .read(routeRepositoryProvider)
              .detail(micro.id);
          widget.session.details[micro.id] = detail;
        } catch (_) {
          // Sin detalle igual podemos dibujar: el padre pide su propia
          // polilínea; aquí solo perdemos los headsign en los botones.
        }
      }
      if (!mounted) return;
      await widget.onToggleDirection(micro, directionId);
    } finally {
      if (mounted) setState(() => _pendingKey = null);
    }
  }

  Future<void> _activateAll() async {
    if (_locked) return;
    for (final micro in _micros) {
      for (final direction in _directionsOf(micro)) {
        final key = microDirectionKey(micro.id, direction.directionId);
        if (_activeKeys.contains(key)) continue;
        if (!mounted) return;
        await _toggle(micro, direction.directionId);
        if (!mounted) return;
      }
    }
  }

  void _clearAll() {
    if (_locked) return;
    widget.onClearAll();
    setState(() {});
  }

  /// "Jalar para actualizar": vuelve a pagar `/routes` y reemplaza el
  /// catálogo de la sesión (las líneas activas en el mapa no se tocan).
  Future<void> _refresh() async {
    final micros = await _fetchAllMicros(widget.ref);
    if (micros.isEmpty || !mounted) return;
    setState(() {
      widget.session.micros = micros;
      widget.session.loaded = true;
    });
  }

  /// Borra la búsqueda de lugares (borrador Y confirmada) — vuelve a la
  /// guía de «cerca de mí».
  void _clearPlacesSearch() {
    _searchController.clear();
    setState(() {
      _placesDraft = '';
      widget.session.placeResults = null;
      widget.session.placesNearbyPoint = null;
      widget.session.placesQuery = '';
    });
    _planner.clearPlaceMarkers();
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() {
      _query = '';
      widget.session.query = '';
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      if (_placesMode) {
        // Solo borrador: la petición de lugares se dispara al COMMIT
        // (teclado «buscar» o el botón), no por cada letra.
        _placesDraft = value;
      } else {
        _query = value;
        widget.session.query = value;
      }
    });
  }

  /// COMMIT de la búsqueda de lugares: el texto queda en la sesión y la
  /// lista de resultados vuela (indicadores AsyncValueView + caché TTL si
  /// la consulta ya pasó por el repositorio).
  void _commitPlacesSearch() {
    final q = _placesDraft.trim();
    widget.session.placesQuery = q;
    setState(() {});
  }

  /// Cambia de modo (líneas ⇆ lugares): el campo se reinicia con la consulta
  /// de ese modo y el commit es el texto guardado.
  void _switchMode(bool toPlaces) {
    // Al salir de lugares se quitan sus marcadores del mapa (los recorridos
    // dibujados quedan: esos los apaga «Limpiar»).
    if (!toPlaces) _planner.clearPlaceMarkers();
    setState(() {
      widget.session.placesMode = toPlaces;
      if (toPlaces) {
        _placesDraft = widget.session.placesQuery;
        _searchController.text = widget.session.placesQuery;
      } else {
        _query = widget.session.query;
        _searchController.text = widget.session.query;
      }
    });
  }

  /// «Cerca de mí»: GPS una vez → punto a la sesión → este `setState` deja
  /// ver el listado de [stopNearbyProvider]. Sin ubicación queda la guía.
  Future<void> _applyMyLocation() async {
    if (_locked) return;
    final me = await widget.ref.read(myLocationProvider.future);
    if (!mounted || me == null) return;
    setState(() {
      widget.session.placesQuery = '';
      widget.session.placesNearbyPoint = (lat: me.latitude, lon: me.longitude);
    });
  }

  /// Notifier del planeador: dueño de los marcadores del mapa (el mapa vive
  /// debajo del cajón, en la pantalla base, no aquí).
  JourneyPlannerController get _planner =>
      widget.ref.read(journeyPlannerControllerProvider.notifier);

  /// «Marcar en el mapa» del modo LUGARES: abre el selector de punto (el
  /// MISMO `/journey/pick` que origen/destino) y usa lo elegido como el lugar
  /// a consultar — equivale a un «cerca de mí» pero en el punto que el usuario
  /// clava. El listado de [stopNearbyProvider] y sus marcadores se refrescan
  /// solos al cambiar el punto en la sesión.
  Future<void> _pickPlaceOnMap() async {
    if (_locked) return;
    final current = widget.session.placesNearbyPoint;
    final params = <String, String>{'title': 'Lugar'};
    if (current != null) {
      params['lat'] = '${current.lat}';
      params['lon'] = '${current.lon}';
    }
    final picked = await context.push<({double lat, double lon})>(
      Uri(path: '/journey/pick', queryParameters: params).toString(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      widget.session.placesQuery = '';
      widget.session.placesNearbyPoint = picked;
    });
  }

  /// `true` si el recorrido (ida) de esta línea ya está dibujado en el mapa.
  bool _routeActive(StopRouteRef route) =>
      _activeKeys.contains(microDirectionKey(route.id, 0));

  /// Dibuja/borra en el mapa el recorrido COMPLETO de UNA línea del resultado
  /// (ida y vuelta juntas), no una sola orientación: «Ver ruta» muestra la
  /// línea entera. Cada `_toggle` invierte SU dirección, así que la bandera se
  /// decide con la ida y luego la vuelta se aplica solo si está en el estado
  /// contrario (y la ruta realmente la tiene: una de mano única no tiene vuelta).
  Future<void> _toggleStopRoute(StopRouteRef route) async {
    if (_locked) return;
    final summary = _summaryForRef(route);
    final turnOff = _routeActive(route);
    await _toggle(summary, 0);
    if (!mounted) return;
    // El detalle de la ruta ya quedó cacheado por el toggle de la ida, así que
    // aquí sabemos si de verdad existe la vuelta.
    final detail = widget.session.details[route.id];
    final hasVuelta =
        detail == null || detail.directions.any((d) => d.directionId == 1);
    final vueltaActive = _activeKeys.contains(microDirectionKey(route.id, 1));
    if (hasVuelta && turnOff == vueltaActive) {
      await _toggle(summary, 1);
    }
  }

  /// Referencia de línea de un resultado → [RouteSummary] mínima para el
  /// toggle: el controller solo lee `id` y `shortName` (la forma la pide él).
  RouteSummary _summaryForRef(StopRouteRef ref) => RouteSummary(
    id: ref.id,
    shortName: ref.shortName,
    longName: 'Línea ${ref.shortName}',
    color: ref.color,
    textColor: 'FFFFFF',
    description: 'Transporte publico urbano de micros',
    type: 3,
    directionsCount: 2,
    stopCount: 0,
    tripCount: 0,
  );

  void _onDragUpdate(DragUpdateDetails details) {
    if (_snap.isAnimating) _snap.stop();
    setState(() {
      _dragDx = (_dragDx + details.delta.dx).clamp(-140.0, 0.0);
      _snapFrom = null;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_dragDx < -_dismissDrag || velocity < -520) {
      // Se suelta dentro del gesto: el pop corre la transición de salida del
      // PageRouteBuilder, que ya desliza el panel hacia la izquierda.
      Navigator.of(context).pop();
      return;
    }
    setState(() => _snapFrom = Tween<double>(begin: _dragDx, end: 0.0));
    _snap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final activeCount = _activeKeys.length;
    final dx = _shownDx;
    final panelWidth = math.min(340.0, MediaQuery.sizeOf(context).width * 0.85);
    // El tirador sobresale del panel hacia el mapa: la caja del Stack tiene que
    // ser más ancha que el Material o el punto quedaría fuera de su size y no
    // recibiría taps (RenderBox solo hit-testa dentro de su propio tamaño).
    const handleZone = 18.0;

    // El ámbito de brillo del mapa lo pone la ruta (`pageBuilder`), así que el
    // `context` de este `build` ya resuelve `context.colors` contra el modo del
    // mapa: reabrir el panel nunca pinta letra oscura sobre vidrio oscuro.
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        // Tirar del panel hacia la izquierda lo cierra (con muelle si el
        // arrastre se queda corto). Los gestos verticales los deja pasar la
        // lista.
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: Opacity(
            opacity: (1 - dx.abs() / 460).clamp(0.0, 1.0),
            child: SizedBox(
              width: panelWidth + handleZone,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: colors.surface,
                    elevation: 10,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(AppRadius.lg),
                    ),
                    child: SizedBox(
                      width: panelWidth,
                      height: double.infinity,
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _header(colors, text, activeCount),
                            _modeToggle(colors, text),
                            _searchField(colors),
                            if (!_placesMode) _actions(activeCount),
                            Expanded(
                              child: AnimatedBuilder(
                                // [_entrance] manda: mientras dura la entrada
                                // el listado se reconstruye frame a frame (así
                                // escala sus tarjetas) y al terminar deja de
                                // escuchar.
                                animation: _entrance,
                                builder: (_, _) => _placesMode
                                    ? MicrosPlacesList(
                                        query: _placesQuery,
                                        point: widget.session.placesNearbyPoint,
                                        onUseMyLocation: _applyMyLocation,
                                        onPickOnMap: _pickPlaceOnMap,
                                        activeDirectionKeys: _activeKeys,
                                        busyKey: _pendingKey,
                                        locked: _locked,
                                        onToggleRoute: _toggleStopRoute,
                                        onFramePlaces: widget.onFramePlaces,
                                      )
                                    : _list(colors),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Tirador pegado al borde derecho: vive sobre el mapa y
                  // cierra el panel (invita al arrastre horizontal).
                  Positioned(
                    right: 0,
                    top: 120,
                    child: SizedBox(
                      width: handleZone,
                      child: _EdgeHandle(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resultados del modo LUGARES: con consulta confirmada busca por nombre
/// (`/stops/search`); sin consulta y con el punto ya resuelto, lista las
/// paradas cercanas (`/stops/nearby`); sin nada, guía. Los parámetros vienen
/// del `State` del panel (sesión mutada + `setState`), así que este Consumer
/// observa SIEMPRE la fuente de la verdad correcta.
class _EdgeHandle extends StatelessWidget {
  const _EdgeHandle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      elevation: 4,
      borderRadius: const BorderRadius.horizontal(
        right: Radius.circular(AppRadius.tile),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(AppRadius.tile),
        ),
        child: SizedBox(
          width: 16,
          height: 44,
          child: Center(
            // Color explícito: el tirador vive flotando sobre el mapa y
            // heredaría el IconTheme de la página, que en oscuro es claro y en
            // claro es oscuro según el tema.
            child: Icon(
              Icons.chevron_left_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
