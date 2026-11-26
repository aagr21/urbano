import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/map/map.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/urbano_map.dart';
import '../../routes/data/route_models.dart';
import '../../routes/presentation/route_providers.dart';
import '../../routes/presentation/widgets/route_map_chrome.dart';
import '../application/nearby_providers.dart';
import '../domain/nearby_micros.dart';
import 'nearby_map_layers.dart';
import 'nearby_map_overlays.dart';
import 'nearby_results_sheet.dart';

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

    final layers = NearbyMapLayers.build(
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
                        child: NearbyPlacePlate(
                          label: query.label,
                          radius: _radius,
                          lines: data?.micros.length,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  NearbyMapRoundButton(
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
            builder: (context, scroll) => NearbyResultsSheet(
              scroll: scroll,
              result: result,
              radius: _radius,
              selection: selection,
              headsign: selection == null
                  ? null
                  : meaningfulHeadsign(
                      detail?.valueOrNull,
                      selection.directionId,
                    ),
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
}
