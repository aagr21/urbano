// Hoja de resultados de «Micros cerca»: cabecera con radio, tarjetas
// por línea y estado de zona vacía.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../application/nearby_providers.dart';
import '../domain/nearby_micros.dart';
import 'widgets/nearby_micro_card.dart';

/// Hoja inferior: encabezado con conteo y radio, y la lista de líneas.
class NearbyResultsSheet extends StatelessWidget {
  const NearbyResultsSheet({
    super.key,
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
            child: NearbySheetHeader(
              count: data?.micros.length,
              loading: result.isLoading && data == null,
              radius: radius,
              onRadius: onRadius,
            ),
          ),
          ...switch (result) {
            AsyncData(:final value) when value.isEmpty => [
              SliverToBoxAdapter(
                child: NearbyEmptyZone(radius: radius, onRadius: onRadius),
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
class NearbySheetHeader extends StatelessWidget {
  const NearbySheetHeader({
    super.key,
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
class NearbyEmptyZone extends StatelessWidget {
  const NearbyEmptyZone({
    super.key,
    required this.radius,
    required this.onRadius,
  });

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
