import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/time_formatters.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/photo_shine.dart';
import '../../../core/widgets/route_badge.dart';
import '../../../core/widgets/route_photo.dart';
import '../data/route_models.dart';
import '../presentation/widgets/route_map_card.dart';
import '../presentation/widgets/route_places.dart';
import 'route_providers.dart';

/// Detalle de ruta: foto, mapa con polilínea y dirección (ida/vuelta).
class RouteDetailScreen extends ConsumerStatefulWidget {
  const RouteDetailScreen({
    super.key,
    required this.routeId,
    this.heroPrefix = 'routes',
  });

  final String routeId;

  /// Prefijo de la tag del Hero del badge, para que coincida con la lista de
  /// la que se navegó (`home`, `search`) y la insignia vuele hasta la AppBar.
  final String heroPrefix;

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  int _directionId = 0;

  RouteKey get _key => RouteKey(widget.routeId, directionId: _directionId);

  void _refresh() {
    ref.invalidate(routeDetailProvider(_key));
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(routeDetailProvider(_key));

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(widget.routeId)),
        body: const SkeletonList(count: 5),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(widget.routeId)),
        body: ErrorView(error: error, onRetry: _refresh),
      ),
      data: (detail) => _DetailBody(
        detail: detail,
        heroPrefix: widget.heroPrefix,
        directionId: _directionId,
        onDirectionChanged: (value) => setState(() => _directionId = value),
        onRefresh: _refresh,
        routeKey: _key,
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.heroPrefix,
    required this.directionId,
    required this.onDirectionChanged,
    required this.onRefresh,
    required this.routeKey,
  });

  final RouteDetail detail;

  /// Debe coincidir con el prefijo que llevó la lista de origen (`home`,
  /// `search`): si las tags no calzan, el Hero no vuela.
  final String heroPrefix;
  final int directionId;
  final ValueChanged<int> onDirectionChanged;
  final VoidCallback onRefresh;
  final RouteKey routeKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final routeColor = AppColors.fromHex(detail.color);
    final direction = detail.directionById(directionId);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            RouteBadge(
              label: detail.shortName,
              colorHex: detail.color,
              textColorHex: detail.textColor,
              heroTag: 'route-badge-$heroPrefix-${detail.id}',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                detail.longName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      // SafeArea (solo abajo): los botones/barra de gestos del teléfono se
      // comen el final del scroll si el listado corre hasta el borde.
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (detail.shape != null && detail.shape!.points.length > 1)
              Reveal(
                slide: 10,
                child: RouteMapCard(detail: detail, routeColor: routeColor),
              ),
            if (detail.imageUrl != null)
              Reveal(
                slide: 10,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: PhotoShine(
                    child: SizedBox(
                      height: 300,
                      child: RoutePhoto(
                        url: detail.imageUrl!,
                        radius: BorderRadius.circular(AppRadius.lg),
                        fit: BoxFit.fitHeight,
                        showFull: true,
                      ),
                    ),
                  ),
                ),
              ),
            if (detail.directions.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SegmentedButton<int>(
                  segments: [
                    for (final dir in detail.directions)
                      ButtonSegment(
                        value: dir.directionId,
                        label: Text(
                          dir.headsign.isEmpty
                              ? 'Dir ${dir.directionId}'
                              : dir.headsign,
                        ),
                        icon: Icon(
                          dir.directionId == 0
                              ? Icons.arrow_forward_rounded
                              : Icons.arrow_back_rounded,
                          size: 18,
                        ),
                      ),
                  ],
                  selected: {directionId},
                  onSelectionChanged: (selection) =>
                      onDirectionChanged(selection.first),
                  showSelectedIcon: false,
                ),
              ),
            Reveal(
              index: 1,
              slide: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (direction != null && direction.firstDeparture != null)
                      MetaChip(
                        icon: Icons.play_arrow_rounded,
                        label:
                            'Primera ${GtfsTime.toHm(direction.firstDeparture)}',
                      ),
                    if (direction != null && direction.lastDeparture != null)
                      MetaChip(
                        icon: Icons.stop_rounded,
                        label:
                            'Última ${GtfsTime.toHm(direction.lastDeparture)}',
                      ),
                    if (direction != null && direction.headwaySeconds != null)
                      MetaChip(
                        icon: Icons.schedule_rounded,
                        label: Fmt.headway(direction.headwaySeconds),
                        color: colors.primary,
                        background: colors.primary.withValues(alpha: 0.1),
                      ),
                    if (detail.directions.length > 1)
                      const MetaChip(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Ida y vuelta',
                      ),
                  ],
                ),
              ),
            ),
            // Lugares principales del recorrido (calles de referencia, sin
            // horarios): reemplaza la lectura de «próximas salidas».
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: RoutePlaces(routeKey: routeKey, routeColor: routeColor),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
