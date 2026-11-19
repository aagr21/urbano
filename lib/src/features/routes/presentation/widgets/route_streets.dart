import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../route_providers.dart';

/// «Por dónde pasa»: las avenidas y calles principales del recorrido.
///
/// La lista sale de **OpenStreetMap** (Overpass) a partir de la polilínea del
/// sentido que se está viendo. Si el servicio no responde, la sección se
/// retira sin ruido: el detalle conserva «Pasa por», que se deriva del propio
/// feed GTFS y siempre está disponible sin red.
class RouteStreets extends ConsumerWidget {
  const RouteStreets({
    super.key,
    required this.routeKey,
    required this.routeColor,
  });

  final RouteKey routeKey;
  final Color routeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streets = ref.watch(routeStreetsProvider(routeKey));

    return streets.when(
      loading: () => const _StreetsSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : _StreetsSection(streets: items, color: routeColor),
    );
  }
}

class _StreetsSection extends StatelessWidget {
  const _StreetsSection({required this.streets, required this.color});

  final List<String> streets;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final railAccent = dark ? colors.secondary : AppColors.aqua;
    final fill = AppColors.tint(color, colors.surface, 0.10);
    final ink = AppColors.legible(color, fill);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                margin: const EdgeInsets.only(right: AppSpace.sm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.primary, railAccent],
                  ),
                ),
              ),
              Icon(Icons.signpost_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Por dónde pasa',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'OpenStreetMap',
                style: text.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Calles y avenidas del recorrido, en el sentido del micro.',
            style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (final street in streets)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_road_rounded, size: 14, color: ink),
                      const SizedBox(width: 6),
                      Text(
                        street,
                        style: text.labelSmall?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreetsSkeleton extends StatelessWidget {
  const _StreetsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingShimmer(width: 150, height: 18),
          SizedBox(height: 10),
          // Píldoras flexibles: el esqueleto debe caber en cualquier ancho
          // (en un móvil de 320 px tres anchos fijos desbordaban la fila).
          Row(
            children: [
              Expanded(
                child: LoadingShimmer(
                  width: double.infinity,
                  height: 28,
                  radius: AppRadius.pill,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: LoadingShimmer(
                  width: double.infinity,
                  height: 28,
                  radius: AppRadius.pill,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: LoadingShimmer(
                  width: double.infinity,
                  height: 28,
                  radius: AppRadius.pill,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
