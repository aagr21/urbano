import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../routes/data/route_models.dart';
import '../../application/micros_catalog.dart';
import 'journey_micros_tile.dart';
import 'micros_panel_motion.dart';

/// Listado de líneas del panel: relleno/estado vacío con animación propia y
/// «jalar para actualizar» (el catálogo ya está cacheado, así que abrir no
/// cuesta red).
class MicrosPanelList extends StatelessWidget {
  const MicrosPanelList({
    super.key,
    required this.micros,
    required this.filtered,
    required this.query,
    required this.activeKeys,
    required this.busyKey,
    required this.locked,
    required this.scrollController,
    required this.entrance,
    required this.directionsOf,
    required this.onRefresh,
    required this.onClearQuery,
    required this.onToggle,
  });

  /// Catálogo completo (decide si hay líneas registradas).
  final List<RouteSummary> micros;

  /// Ya filtrado por [query] (el filtro es lógica del controller).
  final List<RouteSummary> filtered;

  /// Texto del buscador, solo para el mensaje de «sin resultados».
  final String query;

  final Set<String> activeKeys;
  final String? busyKey;
  final bool locked;

  final ScrollController scrollController;

  /// Entrada del panel (el escalonado de las tarjetas se calcula sobre ella).
  final AnimationController entrance;

  final List<MicroDirection> Function(RouteSummary micro) directionsOf;
  final Future<void> Function() onRefresh;
  final VoidCallback onClearQuery;
  final void Function(RouteSummary micro, int directionId) onToggle;

  @override
  Widget build(BuildContext context) {
    if (micros.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: EmptyState(
          icon: Icons.directions_bus_rounded,
          title: 'No hay micros registrados todavía.',
          compact: true,
        ),
      );
    }

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Sin resultados para "$query".',
          message: 'Prueba con otro numeral o nombre de línea.',
          actionLabel: 'Ver todas',
          onAction: onClearQuery,
          compact: true,
        ),
      );
    }

    return RefreshIndicator(
      color: context.colors.primary,
      backgroundColor: context.colors.surface,
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final micro = filtered[index];
          final tile = JourneyMicroTile(
            key: ValueKey('micro-tile-${micro.id}'),
            micro: micro,
            directions: directionsOf(micro),
            activeDirectionKeys: activeKeys,
            busyKey: busyKey,
            locked: locked,
            onToggle: (directionId) => onToggle(micro, directionId),
          );
          // El escalonado de entrada solo vale para la primera hornada: una
          // vez terminado [entrance], las tarjetas que entran al hacer scroll
          // se muestran ya en su sitio (nada de re-animar en cada frame).
          return microsStagger(entrance, index, tile);
        },
      ),
    );
  }
}
