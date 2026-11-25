import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../routes/data/route_models.dart';
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
    this.routes = const {},
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

  /// Ficha de cada línea por `routeId` para las fotos de los micros.
  final Map<String, RouteSummary> routes;

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
                  Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        if (bare)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  AppSpace.xl,
                                  AppSpace.lg,
                                  AppSpace.xl,
                                  AppSpace.xl + bottomInset,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: colors.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        endpointsTooClose
                                            ? Icons.directions_walk_rounded
                                            : Icons.wrong_location_outlined,
                                        size: 28,
                                        color: colors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.md),
                                    Text(
                                      _emptyBody,
                                      textAlign: TextAlign.center,
                                      style: context.text.bodyMedium?.copyWith(
                                        color: colors.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpace.lg,
                              AppSpace.lg,
                              AppSpace.lg,
                              AppSpace.xl + bottomInset,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                if (index.isOdd) {
                                  // Tras la mejor opción, más aire: separa la
                                  // recomendación del resto.
                                  return SizedBox(
                                    height: index == 1
                                        ? AppSpace.xl
                                        : AppSpace.md,
                                  );
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
                                  routes: routes,
                                );
                                // La primera opción es la mejor rankeada por
                                // el planificador: lleva un título ENCIMA de
                                // la tarjeta, no una píldora dentro. Las demás
                                // se agrupan bajo «Otras opciones».
                                if (itemIndex > 1) return card;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (itemIndex == 0)
                                      const _BestOptionHeading()
                                    else
                                      const _SectionLabel('Otras opciones'),
                                    const SizedBox(height: AppSpace.sm),
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

/// Cabecera fija: asa + resumen de la opción dibujada en el mapa. Con la
/// hoja recogida (0.18) es lo único que se ve, así que dice lo esencial en
/// dos líneas: duración y tipo, y el horario.
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
    final muted = colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg + 4,
        AppSpace.sm,
        AppSpace.sm,
        AppSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: bare
                    ? Text(
                        emptyTitle,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : Reveal(
                        // Cambiar de opción re-entra el resumen: el número y
                        // los horarios que se leen acaban de cambiar.
                        key: ValueKey('sheet-summary-$selectedIndex'),
                        slide: 4,
                        duration: Motion.quick,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              options.length > 1
                                  ? 'Opción ${selectedIndex + 1} de '
                                        '${options.length} · en el mapa'
                                  : 'Tu viaje · en el mapa',
                              style: text.labelSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Un solo `Text.rich`: «38 min · Directo» no debe
                            // competir con el «38 min» de la tarjeta.
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: Fmt.duration(
                                      selectedOption.durationMinutes,
                                    ),
                                    style: text.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  ·  ${selectedOption.type.label}',
                                    style: text.titleSmall?.copyWith(
                                      color: muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                style: text.bodySmall?.copyWith(color: muted),
                                children: [
                                  const TextSpan(text: 'Sale '),
                                  _strong(
                                    GtfsTime.toHm(selectedOption.departAt),
                                    text,
                                    colors.onSurface,
                                  ),
                                  const TextSpan(text: '  ·  Llega '),
                                  _strong(
                                    GtfsTime.toHm(selectedOption.arriveAt),
                                    text,
                                    colors.onSurface,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
              ),
              _ClearButton(onClear: onClear),
            ],
          ),
        ],
      ),
    );
  }

  TextSpan _strong(String value, TextTheme text, Color ink) => TextSpan(
    text: value,
    style: text.bodySmall?.copyWith(fontWeight: FontWeight.w800, color: ink),
  );
}

/// Acción «quitar resultados» como ícono con tooltip: el botón con rótulo
/// ocupaba una fila entera y empujaba la lista.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Quitar resultados',
      onPressed: onClear,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.close_rounded, size: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 6),
          // `titleSmall` en negrita: presenta la tarjeta, no compite con el
          // resumen fijo de arriba (sigue siendo mayor que el chip de tipo).
          Text(
            'Mejor opción de viaje',
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rótulo discreto de grupo («Otras opciones»).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      child: Text(
        label,
        style: context.text.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
