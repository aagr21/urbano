import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../data/journey_models.dart';
import 'journey_option_card.dart';
import 'journey_result_map.dart';

/// Hoja arrastrable con las opciones del viaje: handle, header resumen
/// (opción N de M, tipo + duración, horarios) + leyenda + lista de
/// `JourneyOptionCard` (tocar una tarjeta selecciona la opción que ya
/// está dibujada en el mapa).
class JourneyResultsSheet extends StatelessWidget {
  const JourneyResultsSheet({
    super.key,
    required this.controller,
    required this.options,
    required this.bare,
    required this.selectedIndex,
    required this.expandedIndex,
    required this.selectedOption,
    required this.endpointsTooClose,
    required this.endpointsDistanceM,
    required this.onOptionSelected,
  });

  final DraggableScrollableController controller;
  final List<JourneyOption> options;

  /// `true` si la respuesta no trajo ninguna opción (mostrar vacío).
  final bool bare;
  final int selectedIndex;

  /// Índice de tarjeta expandida (`null` = ninguna).
  final int? expandedIndex;

  /// Opción actualmente dibujada en el mapa (para el header del resumen).
  final JourneyOption selectedOption;

  /// Mensajes de vacío: origen y destino (casi) en el mismo sitio.
  final bool endpointsTooClose;
  final double? endpointsDistanceM;

  /// Tocar una tarjeta: la selecciona (y expande/colapsa su detalle).
  final void Function(int index) onOptionSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0.45,
      minChildSize: 0.18,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.18, 0.45, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.sheet,
            boxShadow: AppTheme.softShadow(opacity: 0.18, dy: -4),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                      const SizedBox(height: 12),
                      if (!bare)
                        Reveal(
                          // Cambiar de opción re-entra el resumen: el número y
                          // los horarios que se leen acaban de cambiar.
                          key: ValueKey('sheet-summary-$selectedIndex'),
                          slide: 6,
                          duration: Motion.quick,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.map_rounded,
                                          size: 14,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Opción ${selectedIndex + 1} de ${options.length}',
                                          style: context.text.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: colors.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${selectedOption.type.label} · '
                                          '${Fmt.duration(selectedOption.durationMinutes)}',
                                          style: context.text.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        Text(
                                          'Sale ${GtfsTime.toHm(selectedOption.departAt)}'
                                          ' → llega ${GtfsTime.toHm(selectedOption.arriveAt)}',
                                          style: context.text.labelSmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              MapLegend(selectedOption),
                            ],
                          ),
                        )
                      else
                        Text(
                          _emptyTitle,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (bare)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        endpointsTooClose
                            ? 'El origen y el destino están a '
                                  '${(endpointsDistanceM ?? 0).round()} m: '
                                  'camina hasta allí.'
                            : 'No hay rutas directas ni con un transbordo '
                                  'para ese origen/destino a esa hora. Prueba '
                                  'otra hora u otro punto.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index.isOdd) return const SizedBox(height: 12);
                      final itemIndex = index ~/ 2;
                      final item = options[itemIndex];
                      return JourneyOptionCard(
                        // La firma de la respuesta entra en la clave: cuando
                        // `/journey` devuelve otras opciones (se movió un pin,
                        // se cambió la hora) las tarjetas se remontan y la
                        // cascada vuelve a sonar; con la misma respuesta, no.
                        key: ValueKey(
                          '${identityHashCode(options)}-$itemIndex',
                        ),
                        option: item,
                        index: itemIndex,
                        expanded: expandedIndex == itemIndex,
                        selected: selectedIndex == itemIndex,
                        onToggle: () => onOptionSelected(itemIndex),
                      );
                    }, childCount: options.length * 2 - 1),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String get _emptyTitle =>
      endpointsTooClose ? 'Están muy cerca' : 'No encontramos viajes';
}
