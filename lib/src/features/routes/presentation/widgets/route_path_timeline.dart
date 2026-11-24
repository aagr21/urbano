import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../data/route_models.dart';
import '../route_providers.dart';
import 'route_places.dart';

/// «Por dónde pasa»: el recorrido del sentido elegido como una línea vertical,
/// de donde sale a donde llega, con las calles y lugares principales en el
/// orden en que el micro los pisa.
///
/// Fuente de los puntos intermedios, en orden de preferencia:
/// 1. las calles y avenidas del trazado ([routeStreetsProvider], OSM): son
///    los nombres más limpios y ya vienen en el sentido del micro;
/// 2. si OSM no responde, los lugares principales derivados de las paradas
///    del feed ([RoutePlaces.mainPlaces]).
///
/// Arranca PLEGADO: solo «Sale de» y «Llega a», con «Ver las N calles» entre
/// ambos. El detalle no se vuelve una lista larga a menos que el pasajero la
/// pida.
class RoutePathTimeline extends ConsumerStatefulWidget {
  const RoutePathTimeline({
    super.key,
    required this.routeKey,
    required this.routeColor,
    this.origin,
    this.destination,
  });

  final RouteKey routeKey;
  final Color routeColor;

  /// Extremos con nombre del sentido (headsigns); si faltan se usan la
  /// primera y la última parada del feed.
  final String? origin;
  final String? destination;

  @override
  ConsumerState<RoutePathTimeline> createState() => _RoutePathTimelineState();
}

class _RoutePathTimelineState extends ConsumerState<RoutePathTimeline> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant RoutePathTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Otro sentido, otra lista: se vuelve a mostrar recogida.
    if (oldWidget.routeKey != widget.routeKey) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final streets = ref.watch(routeStreetsProvider(widget.routeKey));
    final stops = ref.watch(routeStopsProvider(widget.routeKey));
    final stopList = stops.valueOrNull ?? const <RouteStop>[];

    final streetList = streets.valueOrNull ?? const <String>[];
    final loading =
        (streets.isLoading && stops.isLoading) ||
        (streets.isLoading && stopList.isEmpty && !stops.hasError);
    if (loading) return const _TimelineSkeleton();

    final middle = streetList.isNotEmpty
        ? streetList
        : RoutePlaces.mainPlaces(stopList, max: 12);
    final origin =
        widget.origin ??
        (stopList.isNotEmpty ? _shortStop(stopList.first.name) : null);
    final destination =
        widget.destination ??
        (stopList.isNotEmpty ? _shortStop(stopList.last.name) : null);
    if (middle.isEmpty && origin == null && destination == null) {
      return const SizedBox.shrink();
    }

    // Una sola calle no merece un botón: se muestra directa.
    final collapsed = !_expanded && middle.length > 1;
    final nodes = <_Node>[
      if (origin != null) _Node(origin, _NodeKind.start),
      if (collapsed)
        _Node('Ver las ${middle.length} calles por donde pasa', _NodeKind.more)
      else
        for (final place in middle) _Node(place, _NodeKind.middle),
      if (destination != null) _Node(destination, _NodeKind.end),
    ];

    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.lg,
        AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: dark
              ? AppColors.lineDark
              : colors.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < nodes.length; i++)
            _TimelineRow(
              node: nodes[i],
              first: i == 0,
              last: i == nodes.length - 1,
              routeColor: widget.routeColor,
              onTap: nodes[i].kind == _NodeKind.more
                  ? () => setState(() => _expanded = true)
                  : null,
            ),
        ],
      ),
    );
  }

  /// «Avenida X esquina Calle Y» → «Avenida X».
  static String _shortStop(String name) => name.split(' esquina ').first;
}

enum _NodeKind { start, middle, more, end }

class _Node {
  const _Node(this.label, this.kind);

  final String label;
  final _NodeKind kind;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.node,
    required this.first,
    required this.last,
    required this.routeColor,
    this.onTap,
  });

  final _Node node;
  final bool first;
  final bool last;
  final Color routeColor;
  final VoidCallback? onTap;

  static const _railWidth = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final rail = AppColors.legible(routeColor, colors.surface);
    final isEnd = node.kind == _NodeKind.start || node.kind == _NodeKind.end;

    final caption = switch (node.kind) {
      _NodeKind.start => 'Sale de',
      _NodeKind.end => 'Llega a',
      _ => null,
    };

    final Widget label = node.kind == _NodeKind.more
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  node.label,
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: rail,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, size: 18, color: rail),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (caption != null)
                Text(
                  caption,
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                node.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (isEnd ? text.titleSmall : text.bodyMedium)?.copyWith(
                  fontWeight: isEnd ? FontWeight.w800 : FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
            ],
          );

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _railWidth,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 4,
                    color: first ? Colors.transparent : rail,
                  ),
                ),
                _Dot(kind: node.kind, rail: rail),
                Expanded(
                  child: Container(
                    width: 4,
                    color: last ? Colors.transparent : rail,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: isEnd ? 10 : 8),
              child: Align(alignment: Alignment.centerLeft, child: label),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      key: const ValueKey('route-path-more'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: row,
    );
  }
}

/// Nodo de la línea: extremos grandes (verde sale / rojo llega, los mismos
/// colores del mapa), intermedios pequeños y huecos sobre el color de la línea.
class _Dot extends StatelessWidget {
  const _Dot({required this.kind, required this.rail});

  final _NodeKind kind;
  final Color rail;

  @override
  Widget build(BuildContext context) {
    final surface = context.colors.surface;
    return switch (kind) {
      _NodeKind.start || _NodeKind.end => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: kind == _NodeKind.start ? AppColors.success : AppColors.danger,
          shape: BoxShape.circle,
          border: Border.all(color: surface, width: 3),
          boxShadow: [BoxShadow(color: rail, spreadRadius: 1.5)],
        ),
      ),
      _NodeKind.middle => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: surface,
          shape: BoxShape.circle,
          border: Border.all(color: rail, width: 3),
        ),
      ),
      _NodeKind.more => Icon(Icons.more_vert_rounded, size: 18, color: rail),
    };
  }
}

class _TimelineSkeleton extends StatelessWidget {
  const _TimelineSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LoadingShimmer(width: double.infinity, height: 44),
        SizedBox(height: AppSpace.sm),
        LoadingShimmer(width: double.infinity, height: 44),
        SizedBox(height: AppSpace.sm),
        LoadingShimmer(width: double.infinity, height: 44),
      ],
    );
  }
}
