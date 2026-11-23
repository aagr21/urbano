import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/time_formatters.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/photo_shine.dart';
import '../../../core/widgets/photo_viewer.dart';
import '../../../core/widgets/route_badge.dart';
import '../../../core/widgets/route_photo.dart';
import '../../../core/widgets/urbano_back_button.dart';
import '../data/route_models.dart';
import '../presentation/widgets/route_map_card.dart';
import '../presentation/widgets/route_places.dart';
import '../presentation/widgets/route_streets.dart';
import 'route_providers.dart';

/// Detalle de ruta: mapa del sentido activo, horario y recorrido.
///
/// El control de ida/vuelta aparece UNA sola vez ([_DirectionSwitch]): cambia
/// el detalle, la previsualización del mapa y el sentido que abre «Recorrido
/// completo». No hay botones duplicados por sentido ni chip «Ida y vuelta».
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
        appBar: AppBar(
          leading: const UrbanoBackButton(),
          title: Text(widget.routeId),
        ),
        body: const SkeletonList(count: 5),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const UrbanoBackButton(),
          title: Text(widget.routeId),
        ),
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

  /// Abre el mapa a sangre del sentido que se está viendo (`0` = ida,
  /// `1` = vuelta).
  void _openFullMap(BuildContext context) {
    context.push(UrbanoRoutes.routeMap(detail.id, directionId: directionId));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final routeColor = AppColors.fromHex(detail.color);
    final direction = detail.directionById(directionId);
    final hasShape = detail.shape != null && detail.shape!.points.length > 1;

    return Scaffold(
      appBar: AppBar(
        leading: const UrbanoBackButton(),
        title: Text(
          detail.longName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium,
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
          padding: const EdgeInsets.only(top: 4),
          children: [
            // Identidad de la línea: el badge que vuela desde la lista y la
            // descripción del feed, en una sola fila compacta.
            Reveal(
              slide: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.md,
                  AppSpace.lg,
                  0,
                ),
                child: Row(
                  children: [
                    RouteBadge(
                      label: detail.shortName,
                      colorHex: detail.color,
                      textColorHex: detail.textColor,
                      heroTag: 'route-badge-$heroPrefix-${detail.id}',
                    ),
                    if (detail.description.isNotEmpty) ...[
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          detail.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Mapa del sentido activo: la única puerta al recorrido completo.
            if (hasShape)
              Reveal(
                slide: 10,
                child: RouteMapCard(
                  detail: detail,
                  routeColor: routeColor,
                  onOpenFullMap: () => _openFullMap(context),
                ),
              ),
            // ÚNICO control de sentido del detalle.
            if (detail.directions.length > 1)
              _DirectionSwitch(
                directions: detail.directions,
                value: directionId,
                routeColor: routeColor,
                onChanged: onDirectionChanged,
              ),
            if (direction != null) _ScheduleStrip(direction: direction),
            if (detail.imageUrl != null)
              Reveal(
                slide: 10,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.lg,
                    AppSpace.lg,
                    AppSpace.lg,
                    0,
                  ),
                  // La foto se abre a pantalla completa con el mismo vuelo que
                  // en el panel de micros: tocar la imagen la despega del
                  // detalle ([openPhotoViewer]).
                  child: GestureDetector(
                    onTap: () => openPhotoViewer(
                      context,
                      url: detail.imageUrl!,
                      tag: photoHeroTag('detail', detail.id),
                      title: detail.longName,
                      subtitle: 'Foto del micro',
                      accent: routeColor,
                      sourceRadius: AppRadius.lg,
                    ),
                    child: PhotoShine(
                      child: SizedBox(
                        height: 210,
                        child: Hero(
                          tag: photoHeroTag('detail', detail.id),
                          child: RoutePhoto(
                            url: detail.imageUrl!,
                            radius: BorderRadius.circular(AppRadius.lg),
                            showFull: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Calles y avenidas del sentido activo (OpenStreetMap). Si el
            // servicio no responde, la sección no se monta y «Pasa por» sigue
            // contando el recorrido con las paradas del feed.
            Reveal(
              index: 2,
              slide: 8,
              child: RouteStreets(routeKey: routeKey, routeColor: routeColor),
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

/// Cambio de sentido del recorrido: una cápsula con un solo par de opciones.
///
/// Sustituye al `SegmentedButton` más los dos botones «Ver ruta de ida/vuelta»
/// que repetían la misma decisión tres veces. La opción activa se apoya sobre
/// la superficie del tema y el color de la línea marca su tinta.
class _DirectionSwitch extends StatelessWidget {
  const _DirectionSwitch({
    required this.directions,
    required this.value,
    required this.routeColor,
    required this.onChanged,
  });

  final List<RouteDirection> directions;
  final int value;
  final Color routeColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.pill);
    final accent = AppColors.legible(routeColor, colors.surface);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.lg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.xs),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : colors.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: radius,
          border: Border.all(
            color: dark
                ? AppColors.lineDark
                : colors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            for (final direction in directions)
              Expanded(
                child: _DirectionTab(
                  direction: direction,
                  selected: direction.directionId == value,
                  accent: accent,
                  onTap: () => onChanged(direction.directionId),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DirectionTab extends StatelessWidget {
  const _DirectionTab({
    required this.direction,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final RouteDirection direction;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final radius = BorderRadius.circular(AppRadius.pill);
    final label = direction.headsign.isNotEmpty
        ? direction.headsign
        : direction.directionId == 0
        ? 'Ida'
        : 'Vuelta';
    final foreground = selected ? accent : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.surface : Colors.transparent,
        borderRadius: radius,
        elevation: selected ? 2 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: InkWell(
          key: ValueKey('route-direction-tab-${direction.directionId}'),
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: 9,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  direction.directionId == 0
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
                  size: 16,
                  color: foreground,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
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

/// Franja de horario del sentido activo: primera salida, última y frecuencia.
class _ScheduleStrip extends StatelessWidget {
  const _ScheduleStrip({required this.direction});

  final RouteDirection direction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final stats = <_StatData>[
      if (direction.firstDeparture != null)
        _StatData(
          icon: Icons.play_arrow_rounded,
          label: 'Primera',
          value: GtfsTime.toHm(direction.firstDeparture),
        ),
      if (direction.lastDeparture != null)
        _StatData(
          icon: Icons.stop_rounded,
          label: 'Última',
          value: GtfsTime.toHm(direction.lastDeparture),
        ),
      if (direction.headwaySeconds != null)
        _StatData(
          icon: Icons.schedule_rounded,
          label: 'Frecuencia',
          value: Fmt.headway(direction.headwaySeconds),
        ),
    ];
    if (stats.isEmpty) return const SizedBox.shrink();

    final hairline = dark
        ? AppColors.lineDark
        : colors.outlineVariant.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.lg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: hairline),
        ),
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) Container(width: 1, height: 30, color: hairline),
              Expanded(child: _StatTile(data: stats[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatData {
  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(data.icon, size: 17, color: colors.primary),
        const SizedBox(height: 3),
        Text(
          data.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
