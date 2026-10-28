import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../stops/data/stop_search_models.dart';
import '../../../stops/presentation/stop_search_providers.dart';

/// Lista de resultados y guía del modo LUGARES del panel de micros
/// («¿qué línea pasa por aquí?»). El `State` del panel decide la fuente
/// (texto confirmado o punto del GPS) y entra aquí con `setState`.
class MicrosPlacesList extends ConsumerWidget {
  const MicrosPlacesList({
    super.key,
    required this.query,
    required this.point,
    required this.onUseMyLocation,
  });

  final String query;
  final ({double lat, double lon})? point;
  final Future<void> Function() onUseMyLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    if (query.isNotEmpty) {
      return AsyncValueView<List<StopHit>>(
        value: ref.watch(stopNameSearchProvider(query)),
        onRetry: () => ref.invalidate(stopNameSearchProvider(query)),
        isEmpty: (items) => items.isEmpty,
        emptyIcon: Icons.search_off_rounded,
        emptyTitle: 'Nada para “$query”',
        emptyMessage: 'Prueba otra calle, barrio o hito (anillo, radial).',
        loadingCount: 4,
        data: (items) => _hitsListView(colors, items),
      );
    }
    final local = point;
    if (local != null) {
      return AsyncValueView<List<StopHit>>(
        value: ref.watch(stopNearbyProvider(local)),
        onRetry: () => ref.invalidate(stopNearbyProvider(local)),
        isEmpty: (items) => items.isEmpty,
        emptyIcon: Icons.search_off_rounded,
        emptyTitle: 'No hay paradas cerca',
        emptyMessage: 'Prueba buscando por nombre.',
        loadingCount: 4,
        data: (items) => _hitsListView(colors, items),
      );
    }
    // Sin texto y sin punto: guía en vez de red a ciegas.
    return MicrosPlaceGuide(onNearby: onUseMyLocation);
  }

  Widget _hitsListView(ColorScheme colors, List<StopHit> hits) =>
      ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        itemCount: hits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => MicrosPlaceTile(hit: hits[index]),
      );
}

/// Tarjeta de resultado de lugar: la esquina (nombre completo), la distancia
/// en modo «cerca de mí» y la fila de bad de líneas que la sirven — cada una
/// con el color real del GTFS; un tap abre el DETALLE de esa línea.
class MicrosPlaceTile extends StatelessWidget {
  const MicrosPlaceTile({super.key, required this.hit});

  final StopHit hit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final micro in hit.routes)
                  RouteBadge(
                    label: micro.shortName,
                    colorHex: micro.color,
                    size: RouteBadgeSize.small,
                    onTap: () => _openLine(context, micro),
                  ),
              ],
            ),
            // Sin líneas servidas (feed pequeño): aviso sutil.
            if (hit.routes.isEmpty)
              Text(
                'Ninguna línea declarada en esta parada',
                style: text.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _distance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  void _openLine(BuildContext context, StopRouteRef micro) {
    unawaited(
      context.push(UrbanoRoutes.routeDetail(micro.id, from: 'panel-lugares')),
    );
  }
}

/// Guía del modo lugares cuando no hay consulta ni punto: invitar a escribir
/// o pulsar «cerca de mí» (el GPS solo se golpea con intención).
class MicrosPlaceGuide extends StatelessWidget {
  const MicrosPlaceGuide({super.key, required this.onNearby});

  final Future<void> Function() onNearby;

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
            '(Terminal, Mercado, Cuarto Anillo…) y te decimos'
            ' qué micros sirven exactamente esa esquina.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onNearby,
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Cerca de mí'),
          ),
        ],
      ),
    );
  }
}

/// Tirador pegado al borde derecho del panel: botón que lo cierra, a medio
/// camino entre el panel y el mapa (invita al arrastre horizontal).
