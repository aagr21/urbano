import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart' show AppSpace;
import '../../application/recent_destinations.dart';
import '../../application/saved_trips_controller.dart';
import '../../application/trip_history_controller.dart';
import '../../data/saved_trips.dart';
import '../../data/trip_history.dart';
import 'journey_destination_recents.dart';
import 'journey_recent_destinations.dart';

/// «Tus destinos recientes» de la hoja «¿A dónde vas?»: viajes guardados e
/// historial unidos, paginados de [pageSize] en [pageSize].
///
/// Es dueña de su página y de BORRAR filas (eso es de los recientes); elegir
/// una fila sube por [onPick] porque repone el viaje de la hoja.
class DestinationRecentsSection extends ConsumerStatefulWidget {
  const DestinationRecentsSection({super.key, required this.onPick});

  final ValueChanged<RecentDestinationItem> onPick;

  static const int pageSize = 5;

  @override
  ConsumerState<DestinationRecentsSection> createState() =>
      _DestinationRecentsSectionState();
}

class _DestinationRecentsSectionState
    extends ConsumerState<DestinationRecentsSection> {
  int _page = 0;

  Future<void> _delete(RecentDestinationItem item) => switch (item) {
    RecentDestinationSavedTrip(:final trip) =>
      ref.read(savedTripsControllerProvider.notifier).remove(trip),
    RecentDestinationHistoryEntry(:final entry) =>
      ref.read(tripHistoryControllerProvider.notifier).remove(entry),
  };

  @override
  Widget build(BuildContext context) {
    final unified = buildUnifiedRecentList(
      savedTrips:
          ref.watch(savedTripsControllerProvider).valueOrNull ??
          const <SavedTrip>[],
      history:
          ref.watch(tripHistoryControllerProvider).valueOrNull ??
          const <TripHistoryEntry>[],
    );
    final page = pageOf(
      unified,
      page: _page,
      pageSize: DestinationRecentsSection.pageSize,
    );
    if (page.items.isEmpty) return const DestinationRecentsEmpty();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.lg + AppSpace.xs),
        DestinationRecentsHeader(count: unified.length),
        const SizedBox(height: AppSpace.sm),
        for (final item in page.items)
          RecentDestinationTile(
            key: ValueKey('recent-${item.key}'),
            item: item,
            onTap: () => widget.onPick(item),
            onDelete: () => _delete(item),
          ),
        if (page.totalPages > 1) ...[
          const SizedBox(height: AppSpace.sm),
          DestinationRecentsPagination(
            page: page.page,
            totalPages: page.totalPages,
            onPrevious: () => setState(() => _page = page.page - 1),
            onNext: () => setState(() => _page = page.page + 1),
          ),
        ],
      ],
    );
  }
}
