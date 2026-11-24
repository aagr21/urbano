import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/urbano_back_button.dart';
import '../data/route_models.dart';
import 'route_providers.dart';
import 'widgets/route_detail_hero.dart';
import 'widgets/route_direction_picker.dart';
import 'widgets/route_map_card.dart';
import 'widgets/route_path_timeline.dart';
import 'widgets/route_quick_facts.dart';

/// Detalle de una línea: pocas cosas, en el orden en que las busca un
/// pasajero.
///
/// 1. **El micro** — foto real (o ilustración) con numeral y nombre, en una
///    cabecera que se pliega ([RouteDetailHero]).
/// 2. **Sentido** — una cápsula «Hacia X | Hacia Y» ([RouteDirectionPicker]);
///    cambia todo lo de abajo.
/// 3. **Servicio** — si pasa ahora, pasaje, primer y último micro, en una
///    sola tarjeta ([RouteQuickFacts]).
/// 4. **El mapa** del sentido elegido.
/// 5. **Por dónde pasa** — plegado: sale de / llega a, y las calles a pedido
///    ([RoutePathTimeline]).
class RouteDetailScreen extends ConsumerStatefulWidget {
  const RouteDetailScreen({
    super.key,
    required this.routeId,
    this.heroPrefix = 'routes',
  });

  final String routeId;

  /// Prefijo de la tag del Hero del badge, para que coincida con la lista de
  /// la que se navegó (`home`, `search`) y la insignia vuele hasta la cabecera.
  final String heroPrefix;

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  int _directionId = 0;

  /// Último detalle mostrado: al cambiar de sentido se pide otro detalle (otro
  /// trazado), y mientras llega la vista se queda con este en vez de
  /// parpadear a esqueleto.
  RouteDetail? _last;

  RouteKey get _key => RouteKey(widget.routeId, directionId: _directionId);

  void _refresh() {
    ref.invalidate(routeDetailProvider(_key));
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(routeDetailProvider(_key));
    final detail = detailAsync.valueOrNull ?? _last;
    if (detailAsync.valueOrNull != null) _last = detailAsync.valueOrNull;

    if (detail == null) {
      return Scaffold(
        appBar: AppBar(leading: const UrbanoBackButton()),
        body: detailAsync.hasError
            ? ErrorView(error: detailAsync.error, onRetry: _refresh)
            : const SkeletonList(count: 5),
      );
    }
    return _DetailBody(
      detail: detail,
      heroPrefix: widget.heroPrefix,
      directionId: _directionId,
      onDirectionChanged: (value) => setState(() => _directionId = value),
      onRefresh: _refresh,
      routeKey: _key,
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
    final routeColor = AppColors.fromHex(detail.color);
    final direction = detail.directionById(directionId);
    final hasShape = detail.shape != null && detail.shape!.points.length > 1;
    final ends = directionEndpoints(detail, directionId);
    final now = DateTime.now();

    return Scaffold(
      // SafeArea (solo abajo): los botones/barra de gestos del teléfono se
      // comen el final del scroll si el listado corre hasta el borde.
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            // El micro primero: foto (o ilustración) con numeral y nombre.
            // Se pliega a una barra del color de la línea.
            RouteDetailHero(
              detail: detail,
              heroTag: 'route-badge-$heroPrefix-${detail.id}',
              onRefresh: onRefresh,
            ),
            SliverList.list(
              children: [
                const SizedBox(height: AppSpace.lg),
                // Sentido: cambia todo lo que sigue.
                if (detail.directions.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.lg,
                      0,
                      AppSpace.lg,
                      AppSpace.md,
                    ),
                    child: RouteDirectionPicker(
                      detail: detail,
                      value: directionId,
                      routeColor: routeColor,
                      onChanged: onDirectionChanged,
                    ),
                  ),
                // Si pasa ahora + pasaje, primer y último micro.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  child: RouteQuickFacts(
                    direction: direction,
                    routeColor: routeColor,
                    now: now,
                  ),
                ),
                // El mapa del sentido elegido.
                if (hasShape)
                  Reveal(
                    slide: 10,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpace.xs),
                      child: RouteMapCard(
                        detail: detail,
                        routeColor: routeColor,
                        onOpenFullMap: () => _openFullMap(context),
                      ),
                    ),
                  ),
                _SectionTitle(
                  'Por dónde pasa',
                  subtitle: (direction?.stopCount ?? 0) > 0
                      ? '${direction!.stopCount} paradas en este sentido'
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  child: RoutePathTimeline(
                    routeKey: routeKey,
                    routeColor: routeColor,
                    origin: ends?.$1,
                    destination: ends?.$2,
                  ),
                ),
                const SizedBox(height: AppSpace.xxl),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de sección del detalle: una pregunta o rótulo corto, sin íconos ni
/// barras decorativas que compitan con el contenido.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.xl,
        AppSpace.lg,
        AppSpace.sm + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
