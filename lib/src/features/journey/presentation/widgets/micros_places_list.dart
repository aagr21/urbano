import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../stops/data/stop_search_models.dart';
import '../../../stops/presentation/stop_search_providers.dart';
import '../journey_planner_controller.dart';

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
    required this.onToggleRoute,
    this.onFramePlaces,
  });

  final String query;
  final ({double lat, double lon})? point;
  final Future<void> Function() onUseMyLocation;

  /// «Marcar en el mapa»: abre el selector de punto y consulta ESOS lugares.
  final Future<void> Function() onPickOnMap;

  /// Estado de los recorridos ya dibujados (para pintar el toggle de ruta).
  final Set<String> activeDirectionKeys;
  final String? busyKey;
  final bool locked;

  /// Dibuja/borra en el mapa el recorrido de UNA línea del resultado (cada
  /// línea se visualiza de forma independiente, no todas juntas).
  final Future<void> Function(StopRouteRef route) onToggleRoute;

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
        emptyTitle: 'No hay paradas cerca',
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
    onToggleRoute: widget.onToggleRoute,
  );
}

/// Tarjeta de resultado de lugar: la esquina (nombre completo), la distancia
/// en modo «cerca de mí» y UNA FILA POR LÍNEA servida — el badge con el color
/// real del GTFS (tap → DETALLE de la línea) y su propio botón «Ver ruta», que
/// dibuja/borra el recorrido de ESA línea en el mapa de forma independiente
/// (sin atarse a una sola orientación: pinta la ruta completa). Las líneas
/// repetidas del feed se muestran una sola vez.
class MicrosPlaceTile extends StatelessWidget {
  const MicrosPlaceTile({
    super.key,
    required this.hit,
    required this.activeKeys,
    required this.busyKey,
    required this.locked,
    required this.onToggleRoute,
  });

  final StopHit hit;

  /// Claves `routeId#directionId` ya dibujadas en el mapa.
  final Set<String> activeKeys;

  /// Clave del toggle en vuelo (deshabilita mientras hay una petición).
  final String? busyKey;

  /// Bloqueado porque OTRA dirección está en vuelo (toggle de red pendiente).
  final bool locked;

  /// Dibuja/borra el recorrido de una línea del resultado.
  final Future<void> Function(StopRouteRef route) onToggleRoute;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final routes = uniqueStopRoutes(hit.routes);
    return GlassCard(
      radius: AppRadius.tile,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.near_me_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hit.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (hit.distanceMeters != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        _distance(hit.distanceMeters!),
                        style: text.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Sin líneas servidas (feed pequeño): aviso sutil, sin acción.
            if (routes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ninguna línea declarada en esta parada',
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  children: [
                    for (final route in routes) _routeRow(context, route),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Fila de una línea: badge (tap → detalle) + su toggle «Ver ruta».
  ///
  /// El badge va dentro de `Expanded` + `Align` a la izquierda: así ocupa como
  /// máximo el espacio restante y **se corta con ellipsis** si el `shortName`
  /// es largo, en vez de estirar su fondo o desbordar el Row. El chip queda
  /// fijado a la derecha y SIEMPRE es visible/tappable, sin importar la
  /// longitud de la línea ni el ancho del panel. El estado (dibujado o no) lo
  /// comunica el propio chip («Ocultar» / «Ver ruta»), por lo que no se
  /// duplica un texto intermedio.
  Widget _routeRow(BuildContext context, StopRouteRef route) {
    final idaKey = '${route.id}#0';
    final drawn = activeKeys.contains(idaKey);
    final pending = busyKey == idaKey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: RouteBadge(
                label: route.shortName,
                colorHex: route.color,
                size: RouteBadgeSize.small,
                onTap: () => _openLine(context, route),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RouteToggleChip(
            routeId: route.id,
            active: drawn || pending,
            enabled: !locked,
            onPressed: () => onToggleRoute(route),
          ),
        ],
      ),
    );
  }

  static String _distance(double meters) => Fmt.distance(meters);

  void _openLine(BuildContext context, StopRouteRef micro) {
    unawaited(
      context.push(UrbanoRoutes.routeDetail(micro.id, from: 'panel-lugares')),
    );
  }
}

/// Quita líneas repetidas (mismo `id`) conservando el primer orden. Cubre
/// también los `StopHit` construidos a mano (tests), no solo los que vienen
/// de `StopHit.fromJson`.
List<StopRouteRef> uniqueStopRoutes(List<StopRouteRef> routes) {
  var duplicated = false;
  final ids = <String>{};
  for (final route in routes) {
    if (!ids.add(route.id)) {
      duplicated = true;
      break;
    }
  }
  if (!duplicated) return routes;
  final seen = <String>{};
  return [
    for (final route in routes)
      if (seen.add(route.id)) route,
  ];
}

/// Botón compacto que dibuja/retira EN EL MAPA el recorrido de UNA línea del
/// resultado. Activo: relleno sólido del primario (letra `onPrimary`);
/// inactivo: fondo de contorno. Colores del tema en ambos estados, nunca un
/// tinte GTFS arbitrario (el badge de la izquierda ya lleva el color real).
class _RouteToggleChip extends StatelessWidget {
  const _RouteToggleChip({
    required this.routeId,
    required this.active,
    required this.enabled,
    required this.onPressed,
  });

  final String routeId;
  final bool active;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final radius = BorderRadius.circular(AppRadius.pill);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: active ? colors.primary : colors.surfaceContainerHighest,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('place-route-toggle-$routeId'),
          borderRadius: radius,
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.route_rounded : Icons.alt_route_rounded,
                  size: 15,
                  color: active ? colors.onPrimary : colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  active ? 'Ocultar' : 'Ver ruta',
                  style: (text.labelMedium ?? text.bodySmall)?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: active
                        ? colors.onPrimary
                        : AppColors.legible(colors.primary, colors.surface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Guía del modo lugares cuando no hay consulta ni punto: invitar a escribir,
/// pulsar «cerca de mí» o CLAVAR el lugar directamente en el mapa.
class MicrosPlaceGuide extends StatelessWidget {
  const MicrosPlaceGuide({
    super.key,
    required this.onNearby,
    required this.onPickOnMap,
  });

  final Future<void> Function() onNearby;
  final Future<void> Function() onPickOnMap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.travel_explore_rounded,
            size: 44,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            '¿Qué línea pasa por donde quieres ir?',
            textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Escribe una calle, esquina, barrio o hito '
            '(Terminal, Mercado, Cuarto Anillo…), marca el punto en el mapa '
            'o usa tu ubicación, y te decimos qué micros sirven ese lugar.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: onNearby,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Cerca de mí'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onPickOnMap,
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: const Text('Marcar en el mapa'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
