import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../data/journey_models.dart';
import 'journey_option_card.dart';

/// Hoja arrastrable con las opciones del viaje.
///
/// La cabecera (asa, «Opción N de M», tipo + duración, horario y acción de
/// quitar) es FIJA: solo se desplaza la lista de tarjetas. Arrastrar la
/// cabecera también mueve la hoja (0.18 / 0.45 / 0.85) para no perder el gesto
/// de siempre.
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
    required this.onClear,
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

  /// Quita la consulta y las capas del viaje del mapa.
  final VoidCallback onClear;

  static const double _minSize = 0.18;
  static const double _initialSize = 0.45;
  static const double _maxSize = 0.85;
  static const List<double> _snapSizes = [_minSize, _initialSize, _maxSize];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // La hoja se dibuja edge-to-edge: el contenido final (la última tarjeta o
    // el texto de "sin rutas") tiene que poder subir por encima del gesto o de
    // la barra del sistema. `viewPadding` vale 0 en los tests.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // Altura disponible de la hoja: convierte el arrastre de la cabecera (px)
    // en fracción de hoja sin perder la proporción al crecer/encoger.
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;
        return DraggableScrollableSheet(
          controller: controller,
          initialChildSize: _initialSize,
          minChildSize: _minSize,
          maxChildSize: _maxSize,
          snap: true,
          snapSizes: _snapSizes,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.sheet,
                boxShadow: AppTheme.softShadow(opacity: 0.18, dy: -4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    // El asa/cabecera ya no vive dentro del scroll: se le da
                    // el mismo gesto de arrastre para que siga abriendo y
                    // cerrando la hoja.
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) =>
                        _dragHeader(details.delta.dy, available),
                    onVerticalDragEnd: (_) => _snapHeader(),
                    child: _SheetHeader(
                      options: options,
                      bare: bare,
                      selectedIndex: selectedIndex,
                      selectedOption: selectedOption,
                      emptyTitle: _emptyTitle,
                      onClear: onClear,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        if (bare)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(24 + bottomInset),
                                child: Text(
                                  _emptyBody,
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
                            padding: EdgeInsets.fromLTRB(
                              16,
                              12,
                              16,
                              24 + bottomInset,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                if (index.isOdd) {
                                  return const SizedBox(height: 12);
                                }
                                final itemIndex = index ~/ 2;
                                final item = options[itemIndex];
                                final card = JourneyOptionCard(
                                  // La firma de la respuesta entra en la clave:
                                  // cuando `/journey` devuelve otras opciones
                                  // (se movió un pin, se cambió la hora) las
                                  // tarjetas se remontan y la cascada vuelve a
                                  // sonar; con la misma respuesta, no.
                                  key: ValueKey(
                                    '${identityHashCode(options)}-$itemIndex',
                                  ),
                                  option: item,
                                  index: itemIndex,
                                  expanded: expandedIndex == itemIndex,
                                  selected: selectedIndex == itemIndex,
                                  onToggle: () => onOptionSelected(itemIndex),
                                );
                                // La primera opción es la mejor rankeada por
                                // el planificador: lleva un título grande
                                // ENCIMA de la tarjeta, no una píldora dentro.
                                if (itemIndex != 0) return card;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _BestOptionHeading(),
                                    const SizedBox(height: 10),
                                    card,
                                  ],
                                );
                              }, childCount: options.length * 2 - 1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Arrastre de la cabecera: subir agranda la hoja, bajar la encoge.
  void _dragHeader(double deltaDy, double available) {
    if (!controller.isAttached || available <= 0) return;
    final next = (controller.size - deltaDy / available).clamp(
      _minSize,
      _maxSize,
    );
    controller.jumpTo(next);
  }

  /// Al soltar, la hoja cae en el tamaño de enganche más cercano.
  void _snapHeader() {
    if (!controller.isAttached) return;
    final current = controller.size;
    var nearest = _snapSizes.first;
    for (final size in _snapSizes) {
      if ((size - current).abs() < (nearest - current).abs()) nearest = size;
    }
    controller.animateTo(
      nearest,
      duration: Motion.quick,
      curve: Curves.easeOutCubic,
    );
  }

  String get _emptyTitle =>
      endpointsTooClose ? 'Están muy cerca' : 'No encontramos viajes';

  String get _emptyBody => endpointsTooClose
      ? 'El origen y el destino están a '
            '${(endpointsDistanceM ?? 0).round()} m: camina hasta allí.'
      : 'No hay rutas directas ni con un transbordo para ese origen/destino a '
            'esa hora. Prueba otra hora u otro punto.';
}

/// Cabecera fija: asa + resumen de UNA sola fila (opción, tipo, duración y
/// acción de quitar) + horario. Nada de bloques apilados: el alto es el mínimo
/// para que la lista de tarjetas se lleve el espacio.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.options,
    required this.bare,
    required this.selectedIndex,
    required this.selectedOption,
    required this.emptyTitle,
    required this.onClear,
  });

  final List<JourneyOption> options;
  final bool bare;
  final int selectedIndex;
  final JourneyOption selectedOption;
  final String emptyTitle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 6),
          if (bare)
            Row(
              children: [
                Expanded(
                  child: Text(
                    emptyTitle,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _ClearButton(onClear: onClear),
              ],
            )
          else
            Reveal(
              // Cambiar de opción re-entra el resumen: el número y los
              // horarios que se leen acaban de cambiar.
              key: ValueKey('sheet-summary-$selectedIndex'),
              slide: 4,
              duration: Motion.quick,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.map_rounded,
                                    size: 13,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Opción ${selectedIndex + 1} '
                                    'de ${options.length}',
                                    style: text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 15,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${selectedOption.type.label} · '
                                  '${Fmt.duration(selectedOption.durationMinutes)}',
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _ClearButton(onClear: onClear),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.login_rounded,
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text.rich(
                          _timeSpan(
                            'Sale ',
                            GtfsTime.toHm(selectedOption.departAt),
                            text,
                            muted: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: colors.outline,
                        ),
                      ),
                      Icon(
                        Icons.logout_rounded,
                        size: 14,
                        color: colors.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text.rich(
                          _timeSpan(
                            'Llega ',
                            GtfsTime.toHm(selectedOption.arriveAt),
                            text,
                            muted: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  TextSpan _timeSpan(
    String label,
    String time,
    TextTheme text, {
    required Color muted,
  }) {
    return TextSpan(
      children: [
        TextSpan(
          text: label,
          style: text.labelSmall?.copyWith(color: muted),
        ),
        TextSpan(
          text: time,
          style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

/// Acción «quitar resultados» como ícono con tooltip: el botón con rótulo
/// ocupaba una fila entera y empujaba la lista.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Quitar resultados',
      onPressed: onClear,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.clear_all_rounded, size: 20),
    );
  }
}

/// Título de la primera tarjeta: la opción mejor rankeada por el planificador.
/// Va FUERA de la tarjeta (encima) y con jerarquía de título, para que se lea
/// como una recomendación y no como una etiqueta más del contenido.
class _BestOptionHeading extends StatelessWidget {
  const _BestOptionHeading();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mejor opción de viaje', style: text.titleLarge),
                Text(
                  'La mejor combinación de tiempo y transbordos',
                  style: text.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
