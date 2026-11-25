import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/map/map.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/urbano_map.dart';
import '../../journey/presentation/journey_markers.dart';
import '../../routes/data/route_models.dart';
import '../../routes/presentation/route_providers.dart';
import '../../routes/presentation/widgets/route_map_chrome.dart';
import '../../stops/data/stop_search_models.dart';
import '../application/nearby_providers.dart';
import '../domain/nearby_micros.dart';
import 'widgets/nearby_micro_card.dart';

/// «Micros cerca»: qué líneas pasan cerca de un punto, en qué sentido y por
/// dónde.
///
/// El mapa va a sangre y cuenta la historia en capas: la ZONA buscada (un
/// círculo punteado), el LUGAR (pin), las PARADAS de la zona (puntos) y, para
/// la línea elegida, su RECORRIDO con flechas de sentido, la parada donde se
/// sube resaltada y el TRAMO A PIE punteado desde el lugar. La hoja inferior
/// lista las líneas de la más cercana a la más lejana; cada una se elige por
/// sentido (Ida/Vuelta). Al llegar se elige sola la más cercana para que el
/// mapa nunca arranque vacío.
class NearbyMicrosScreen extends ConsumerStatefulWidget {
  const NearbyMicrosScreen({super.key, required this.query});

  final NearbyQuery query;

  @override
  ConsumerState<NearbyMicrosScreen> createState() => _NearbyMicrosScreenState();
}

class _NearbyMicrosScreenState extends ConsumerState<NearbyMicrosScreen> {
  final _map = UrbanoMapController();
  final _sheet = DraggableScrollableController();

  /// Radio activo (se puede ampliar desde la hoja sin salir de la vista).
  late int _radius = widget.query.radiusMeters;

  /// Consultas en las que ya se eligió la línea más cercana (no pisar la
  /// elección del usuario cuando la lista se reconstruye).
  final Set<NearbyQuery> _autoSelected = {};

  /// Último trazado encuadrado: re-encuadrar solo cuando cambia el recorrido.
  String? _framedKey;

  static const double _sheetInitial = 0.46;
  static const double _sheetMin = 0.2;
  static const double _sheetMax = 0.9;

  /// Altura de la hoja con la zona vacía: cabe el aviso completo.
  static const double _sheetEmpty = 0.66;

  NearbyQuery get _query => widget.query.withRadius(_radius);

  @override
  void dispose() {
    _map.dispose();
    _sheet.dispose();
    super.dispose();
  }

  /// Margen inferior del encuadre: lo que tapa la hoja en su altura inicial.
  EdgeInsets _fitPadding(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final top = MediaQuery.paddingOf(context).top + 110;
    return EdgeInsets.fromLTRB(36, top, 36, height * _sheetInitial + 24);
  }

  void _frameZone() {
    _framedKey = null;
    _map.fitBounds(
      circlePath(_query.point, _radius.toDouble(), steps: 16),
      padding: _fitPadding(context),
    );
  }

  /// Encuadra el lugar + la parada de subida + el recorrido elegido.
  void _frameRoute(String key, List<LatLng> path, LatLng boarding) {
    if (_framedKey == key) return;
    _framedKey = key;
    _map.fitBounds(
      [...path, _query.point, boarding],
      padding: _fitPadding(context),
      maxZoom: 16,
    );
  }

  void _setRadius(int radius) {
    if (radius == _radius) return;
    ref.read(nearbySelectionProvider.notifier).clear();
    setState(() => _radius = radius);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _frameZone();
    });
  }

  void _openRoute(String routeId) {
    context.push(UrbanoRoutes.routeDetail(routeId, from: 'nearby'));
  }

  /// La primera vez que llega una lista con líneas, elige la más cercana. Si
  /// la zona está vacía, sube la hoja para que se lea el aviso y su «Ampliar»
  /// (a la altura inicial el botón quedaba bajo el borde de la pantalla).
  void _autoSelect(NearbyResult result) {
    final query = _query;
    if (_autoSelected.contains(query)) return;
    _autoSelected.add(query);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (result.isEmpty) {
        if (_sheet.isAttached) {
          _sheet.animateTo(
            _sheetEmpty,
            duration: Motion.settle,
            curve: Curves.easeOutCubic,
          );
        }
        return;
      }
      final selection = ref.read(nearbySelectionProvider);
      if (selection != null) return;
      ref
          .read(nearbySelectionProvider.notifier)
          .focusMicro(result.micros.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final colors = context.colors;
    final result = ref.watch(nearbyMicrosProvider(query));
    final selection = ref.watch(nearbySelectionProvider);
    final data = result.valueOrNull;
    if (data != null) _autoSelect(data);

    final selectedMicro = selection == null || data == null
        ? null
        : data.micros.where((m) => m.route.id == selection.routeId).firstOrNull;
    final boarding = selectedMicro?.boardingFor(selection!.directionId);
    final detail = selection == null
        ? null
        : ref.watch(
            routeDetailProvider(
              RouteKey(selection.routeId, directionId: selection.directionId),
            ),
          );
    final shape = detail?.valueOrNull?.shape?.points ?? const <LatLng>[];
    final drawRoute =
        selectedMicro != null && boarding != null && shape.length > 1;

    if (drawRoute) {
      final key = '${selection!.routeId}#${selection.directionId}';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _frameRoute(key, shape, boarding.point);
      });
    }

    final layers = _MapLayers.build(
      query: query,
      stops: data?.stops ?? const [],
      micro: drawRoute ? selectedMicro : null,
      boarding: drawRoute ? boarding : null,
      shape: drawRoute ? shape : const [],
      zoneColor: colors.primary,
      walkColor: colors.onSurfaceVariant,
      stopColor: colors.outline,
    );

    return Scaffold(
      backgroundColor: colors.surfaceContainerHighest,
      body: Stack(
        children: [
          Positioned.fill(
            child: UrbanoMap(
              key: const ValueKey('nearby-map'),
              controller: _map,
              center: query.point,
              zoom: 15,
              cameraFit: MapCameraFit.bounds(
                bounds: MapBounds.fromPoints(
                  circlePath(query.point, _radius.toDouble(), steps: 16),
                ),
                padding: _fitPadding(context),
              ),
              polylines: layers.polylines,
              markers: layers.markers,
            ),
          ),
          // Chrome flotante: salida + placa del lugar + recentrar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.sm,
                AppSpace.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MapFloatingBack(),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: _PlacePlate(
                          label: query.label,
                          radius: _radius,
                          lines: data?.micros.length,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _MapRoundButton(
                    key: const ValueKey('nearby-recenter'),
                    tooltip: 'Ver la zona',
                    icon: Icons.filter_center_focus_rounded,
                    onTap: _frameZone,
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheet,
            initialChildSize: _sheetInitial,
            minChildSize: _sheetMin,
            maxChildSize: _sheetMax,
            snap: true,
            snapSizes: const [_sheetMin, _sheetInitial, _sheetEmpty, _sheetMax],
            builder: (context, scroll) => _ResultsSheet(
              scroll: scroll,
              result: result,
              radius: _radius,
              selection: selection,
              headsign: _headsign(detail?.valueOrNull, selection),
              onRadius: _setRadius,
              onRetry: () => ref.invalidate(nearbyMicrosProvider(query)),
              onFocusMicro: (micro) =>
                  ref.read(nearbySelectionProvider.notifier).focusMicro(micro),
              onSelectDirection: (micro, directionId) => ref
                  .read(nearbySelectionProvider.notifier)
                  .select(micro.route.id, directionId),
              onOpenRoute: _openRoute,
            ),
          ),
        ],
      ),
    );
  }

  /// Destino del sentido elegido. «Ida»/«Vuelta» a secas no dicen nada (el
  /// botón ya lo dice), así que solo se usa un headsign con nombre real.
  static String? _headsign(RouteDetail? detail, NearbySelection? selection) {
    if (detail == null || selection == null) return null;
    for (final direction in detail.directions) {
      if (direction.directionId != selection.directionId) continue;
      final headsign = direction.headsign.trim();
      final generic = {'ida', 'vuelta', ''};
      return generic.contains(headsign.toLowerCase()) ? null : headsign;
    }
    return null;
  }
}

/// Capas del mapa de «Micros cerca», armadas en un solo sitio y en orden de
/// lectura (lo de abajo se pinta primero).
class _MapLayers {
  const _MapLayers(this.polylines, this.markers);

  final List<MapPolyline> polylines;
  final List<MapMarker> markers;

  static _MapLayers build({
    required NearbyQuery query,
    required List<StopHit> stops,
    required NearbyMicro? micro,
    required NearbyBoarding? boarding,
    required List<LatLng> shape,
    required Color zoneColor,
    required Color walkColor,
    required Color stopColor,
  }) {
    final routeColor = micro == null
        ? null
        : AppColors.fromHex(micro.route.color);
    final polylines = <MapPolyline>[
      // Zona buscada: un aro punteado, fino, que no compite con la ruta.
      MapPolyline(
        points: circlePath(query.point, query.radiusMeters.toDouble()),
        color: zoneColor,
        width: 2,
        opacity: 0.75,
        dashed: true,
      ),
      if (routeColor != null)
        MapPolyline(points: shape, color: routeColor, width: 6, outline: true),
      // Tramo a pie del lugar a la parada de subida.
      if (boarding != null)
        MapPolyline(
          points: [query.point, boarding.point],
          color: walkColor,
          width: 3,
          dashed: true,
        ),
    ];

    final markers = <MapMarker>[
      // Paradas de la zona: puntos discretos (la elegida se pinta aparte).
      for (final stop in stops)
        if (stop.id != boarding?.stopId)
          MapMarker(
            id: 'nearby-stop-${stop.id}',
            point: LatLng(stop.lat, stop.lon),
            width: 10 + kMarkerShadowMargin * 2,
            height: 10 + kMarkerShadowMargin * 2,
            iconKey: 'nearby-stop-dot-${stopColor.toARGB32()}',
            child: MapStopDot(color: stopColor, size: 10),
          ),
      if (routeColor != null) ...[
        ...routeArrowMarkers(
          idPrefix: 'nearby-arrow-${micro!.route.id}',
          path: shape,
          color: routeColor,
          spacingMeters: arrowSpacingFor(pathLengthMeters(shape)),
        ),
        if (micro.route.shortName.trim().isNotEmpty)
          MapMarker(
            id: 'nearby-route-badge',
            point: routePathMidpoint(shape),
            width: routeBadgeWidth(micro.route.shortName.trim()),
            height: routeBadgeHeight,
            iconKey:
                'route-badge-${micro.route.id}-${micro.route.shortName}-'
                '${micro.route.color}',
            child: MapRouteBadge(
              label: micro.route.shortName.trim(),
              color: routeColor,
            ),
          ),
      ],
      if (boarding != null && routeColor != null)
        MapMarker(
          id: 'nearby-boarding',
          point: boarding.point,
          width: stopDotBox + 6,
          height: stopDotBox + 6,
          iconKey: 'nearby-boarding-${micro!.route.color}',
          child: MapStopDot(color: routeColor, size: 22),
        ),
      MapMarker(
        id: 'nearby-place',
        point: query.point,
        width: MapPlacePin.widthFor(34),
        height: MapPlacePin.heightFor(34),
        anchor: MapMarkerAnchor.bottom,
        iconKey: 'nearby-place-pin',
        child: const MapPlacePin(color: AppColors.accent, size: 34),
      ),
    ];
    return _MapLayers(polylines, markers);
  }
}

/// Placa flotante del lugar: «Micros cerca de · Plaza 24 · 12 líneas · 500 m».
class _PlacePlate extends StatelessWidget {
  const _PlacePlate({
    required this.label,
    required this.radius,
    required this.lines,
  });

  final String label;
  final int radius;
  final int? lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final count = lines;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.sm,
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.accent, colors.surface, 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.place_rounded,
              size: 20,
              color: AppColors.legible(
                AppColors.accent,
                AppColors.tint(AppColors.accent, colors.surface, 0.18),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Micros cerca de',
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null)
                CountUp(
                  value: count,
                  format: (n) => '$n',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.primary,
                  ),
                ),
              Text(
                count == null
                    ? formatNearbyDistance(radius.toDouble())
                    : '${count == 1 ? 'línea' : 'líneas'} · '
                          '${formatNearbyDistance(radius.toDouble())}',
                style: text.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botón redondo del mapa (misma talla que los controles del planificador).
class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surface,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: colors.shadow.withValues(alpha: 0.3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: AppControl.mapButton,
            child: Icon(icon, size: 22, color: colors.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior: encabezado con conteo y radio, y la lista de líneas.
class _ResultsSheet extends StatelessWidget {
  const _ResultsSheet({
    required this.scroll,
    required this.result,
    required this.radius,
    required this.selection,
    required this.headsign,
    required this.onRadius,
    required this.onRetry,
    required this.onFocusMicro,
    required this.onSelectDirection,
    required this.onOpenRoute,
  });

  final ScrollController scroll;
  final AsyncValue<NearbyResult> result;
  final int radius;
  final NearbySelection? selection;
  final String? headsign;
  final ValueChanged<int> onRadius;
  final VoidCallback onRetry;
  final ValueChanged<NearbyMicro> onFocusMicro;
  final void Function(NearbyMicro micro, int directionId) onSelectDirection;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final data = result.valueOrNull;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: CustomScrollView(
        key: const ValueKey('nearby-sheet'),
        controller: scroll,
        slivers: [
          SliverToBoxAdapter(
            child: _SheetHeader(
              count: data?.micros.length,
              loading: result.isLoading && data == null,
              radius: radius,
              onRadius: onRadius,
            ),
          ),
          ...switch (result) {
            AsyncData(:final value) when value.isEmpty => [
              SliverToBoxAdapter(
                child: _EmptyZone(radius: radius, onRadius: onRadius),
              ),
            ],
            AsyncData(:final value) => [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  0,
                  AppSpace.lg,
                  AppSpace.xl + bottom,
                ),
                sliver: SliverList.separated(
                  itemCount: value.micros.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.md),
                  itemBuilder: (context, i) {
                    final micro = value.micros[i];
                    final isSelected = selection?.routeId == micro.route.id;
                    return Reveal(
                      key: ValueKey('nearby-reveal-${micro.route.id}'),
                      index: i,
                      child: NearbyMicroCard(
                        micro: micro,
                        selectedDirection: isSelected
                            ? selection!.directionId
                            : null,
                        headsign: isSelected ? headsign : null,
                        onTap: () => onFocusMicro(micro),
                        onSelectDirection: (d) => onSelectDirection(micro, d),
                        onOpenRoute: () => onOpenRoute(micro.route.id),
                      ),
                    );
                  },
                ),
              ),
            ],
            AsyncError(:final error) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: ErrorView(
                    error: error,
                    onRetry: onRetry,
                    compact: true,
                  ),
                ),
              ),
            ],
            _ => [
              const SliverToBoxAdapter(
                child: SkeletonList(count: 3, leading: 56),
              ),
            ],
          },
        ],
      ),
    );
  }
}

/// Asa + «12 líneas pasan cerca» + selector de radio.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.count,
    required this.loading,
    required this.radius,
    required this.onRadius,
  });

  final int? count;
  final bool loading;
  final int radius;
  final ValueChanged<int> onRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final n = count;
    final title = loading || n == null
        ? 'Buscando micros…'
        : n == 0
        ? 'Sin micros en la zona'
        : n == 1
        ? '1 línea pasa cerca'
        : '$n líneas pasan cerca';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.lg,
        AppSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            title,
            key: const ValueKey('nearby-title'),
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'Elige Ida o Vuelta: las flechas del mapa marcan hacia dónde va.',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Icon(
                Icons.radar_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpace.sm),
              for (final r in kNearbyRadii) ...[
                ChoiceChip(
                  key: ValueKey('nearby-radius-$r'),
                  label: Text(formatNearbyDistance(r.toDouble())),
                  selected: r == radius,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onRadius(r),
                ),
                const SizedBox(width: AppSpace.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Zona sin micros: lo dice y ofrece mirar más lejos.
class _EmptyZone extends StatelessWidget {
  const _EmptyZone({required this.radius, required this.onRadius});

  final int radius;
  final ValueChanged<int> onRadius;

  @override
  Widget build(BuildContext context) {
    final wider = kNearbyRadii.where((r) => r > radius).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: EmptyState(
        compact: true,
        icon: Icons.directions_bus_outlined,
        title:
            'Ninguna línea a menos de '
            '${formatNearbyDistance(radius.toDouble())}',
        message: wider == null
            ? 'Prueba con otro punto: esta zona no tiene paradas cerca.'
            : 'Amplía la búsqueda para ver las paradas un poco más lejos.',
        actionLabel: wider == null
            ? null
            : 'Ampliar a ${formatNearbyDistance(wider.toDouble())}',
        onAction: wider == null ? null : () => onRadius(wider),
      ),
    );
  }
}
