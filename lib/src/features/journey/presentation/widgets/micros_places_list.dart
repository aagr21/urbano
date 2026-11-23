import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../stops/data/stop_search_models.dart';
import '../../../stops/presentation/stop_search_providers.dart';
import '../../application/micros_catalog.dart';
import '../journey_planner_controller.dart';
import 'micros_place_guide.dart';
import 'micros_place_tile.dart';

/// Lista de resultados y guía del modo LUGARES del panel de micros
/// («¿qué línea pasa por aquí?»). El `State` del panel decide la fuente
/// (texto confirmado, punto del GPS o punto marcado en el mapa) y entra aquí
/// con `setState`.
///
/// Además de pintar el listado, este widget **sincroniza el mapa** del
/// planeador (montado debajo del cajón): clava el pin del lugar buscado y un
/// punto por parada devuelta, y encuadra la cámara sobre ellos. Lo hace desde
/// un `addPostFrameCallback` (nunca durante el `build`) para no escribir un
/// provider a media construcción.
class MicrosPlacesList extends ConsumerStatefulWidget {
  const MicrosPlacesList({
    super.key,
    required this.query,
    required this.point,
    required this.onUseMyLocation,
    required this.onPickOnMap,
    required this.activeDirectionKeys,
    required this.busyKey,
    required this.locked,
    required this.directionsOf,
    required this.onToggleDirection,
    this.onFramePlaces,
  });

  final String query;
  final ({double lat, double lon})? point;
  final Future<void> Function() onUseMyLocation;

  /// «Marcar en el mapa»: abre el selector de punto y consulta ESOS lugares.
  final Future<void> Function() onPickOnMap;

  /// Estado de los recorridos ya dibujados (para pintar los toggles de sentido).
  final Set<String> activeDirectionKeys;
  final String? busyKey;
  final bool locked;

  /// Sentidos (Ida/Vuelta) que sirve cada línea del resultado, con su headsign
  /// si el detalle ya se conoce. Viene del controller (cachea el detalle en la
  /// sesión), no del payload: la tarjeta solo pinta.
  final List<MicroDirection> Function(StopRouteRef route) directionsOf;

  /// Dibuja/borra en el mapa UN sentido (ida o vuelta) de UNA línea del
  /// resultado; cada sentido se visualiza de forma independiente.
  final Future<void> Function(StopRouteRef route, int directionId)
  onToggleDirection;

  /// Encuadre del mapa sobre el lugar + sus paradas (`null` = sin capacidad).
  final void Function(List<({double lat, double lon})> points)? onFramePlaces;

  @override
  ConsumerState<MicrosPlacesList> createState() => _MicrosPlacesListState();
}

class _MicrosPlacesListState extends ConsumerState<MicrosPlacesList> {
  /// Firma de la última sincronización de marcadores: evita re-clavar los
  /// mismos pines en cada rebuild (solo cuando cambia fuente o llegan datos).
  String _lastSignature = '';

  @override
  void didUpdateWidget(covariant MicrosPlacesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cambió la fuente (otra consulta / otro punto / se fue a la guía): la
    // firma vieja queda invalidada para que el próximo `_push` re-sincronice.
    if (oldWidget.query != widget.query ||
        oldWidget.point != widget.point ||
        (oldWidget.point == null) != (widget.point == null)) {
      _lastSignature = '';
    }
  }

  /// Programa (fuera del `build`) la escritura de marcadores en el mapa y el
  /// encuadre. Se llama con los datos ya resueltos del `ref.watch`.
  void _pushMarkers({
    required ({double lat, double lon})? point,
    required List<StopHit> stops,
    required String signature,
  }) {
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(journeyPlannerControllerProvider.notifier)
          .showPlaceResults(point: point, stops: stops);
      final points = <({double lat, double lon})>[
        ?point,
        for (final s in stops) (lat: s.lat, lon: s.lon),
      ];
      if (points.isNotEmpty) widget.onFramePlaces?.call(points);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (widget.query.isNotEmpty) {
      final source = ref.watch(stopNameSearchProvider(widget.query));
      final stops = source.valueOrNull ?? const <StopHit>[];
      _pushMarkers(
        point: null,
        stops: stops,
        signature: 'q:${widget.query}:${stops.length}',
      );
      return AsyncValueView<List<StopHit>>(
        value: source,
        onRetry: () => ref.invalidate(stopNameSearchProvider(widget.query)),
        isEmpty: (items) => items.isEmpty,
        emptyIcon: Icons.search_off_rounded,
        emptyTitle: 'Nada para “${widget.query}”',
        emptyMessage: 'Prueba otra calle, barrio o hito (anillo, radial).',
        loadingCount: 4,
        data: (items) => _hitsListView(colors, items),
      );
    }
    final local = widget.point;
    if (local != null) {
      final source = ref.watch(stopNearbyProvider(local));
      final stops = source.valueOrNull ?? const <StopHit>[];
      _pushMarkers(
        point: local,
        stops: stops,
        signature: 'p:${local.lat},${local.lon}:${stops.length}',
      );
      return AsyncValueView<List<StopHit>>(
        value: source,
        onRetry: () => ref.invalidate(stopNearbyProvider(local)),
        isEmpty: (items) => items.isEmpty,
        emptyIcon: Icons.search_off_rounded,
        emptyTitle: 'No hay lugares cerca',
        emptyMessage: 'Prueba buscando por nombre o marcando otro punto.',
        loadingCount: 4,
        data: (items) => _hitsListView(colors, items),
      );
    }
    // Sin texto y sin punto: guía en vez de red a ciegas.
    return MicrosPlaceGuide(
      onNearby: widget.onUseMyLocation,
      onPickOnMap: widget.onPickOnMap,
    );
  }

  Widget _hitsListView(ColorScheme colors, List<StopHit> hits) =>
      ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        itemCount: hits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _tileFor(hits[index]),
      );

  Widget _tileFor(StopHit hit) => MicrosPlaceTile(
    hit: hit,
    activeKeys: widget.activeDirectionKeys,
    busyKey: widget.busyKey,
    locked: widget.locked,
    directionsOf: widget.directionsOf,
    onToggleDirection: widget.onToggleDirection,
  );
}
