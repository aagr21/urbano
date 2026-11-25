import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../../core/widgets/route_photo.dart';
import '../../../routes/data/route_models.dart';
import '../../application/route_picker.dart';

/// Hoja modal para elegir el micro de una queja.
///
/// Lo que la hace usable con 154 líneas:
///  * **sin teclado al abrir**: la mayoría recorre la lista o ya sabe el
///    número; abrir con el teclado tapaba media hoja;
///  * se busca por **número o por calle** ([searchRoutes], sin tildes) y un
///    número trae primero la línea exacta;
///  * cada fila dice **por dónde pasa** la línea ([routeStopsSummary]) junto a
///    su insignia GTFS y la foto real del micro;
///  * la línea ya elegida queda **fija arriba** mientras no se busca.
///
/// Devuelve la ruta elegida con `Navigator.pop`.
class ComplaintRouteSelectorSheet extends StatefulWidget {
  const ComplaintRouteSelectorSheet({
    super.key,
    required this.routes,
    required this.selected,
  });

  final List<RouteSummary> routes;
  final RouteSummary? selected;

  @override
  State<ComplaintRouteSelectorSheet> createState() =>
      _ComplaintRouteSelectorSheetState();
}

class _ComplaintRouteSelectorSheetState
    extends State<ComplaintRouteSelectorSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _pick(RouteSummary route) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, route);
  }

  void _clear() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = widget.selected;
    final searching = _query.isNotEmpty;
    final results = searchRoutes(widget.routes, _query);
    // Sin búsqueda, la elegida sube a su propia sección y no se repite abajo.
    final pinned = !searching && selected != null;
    final list = pinned
        ? results.where((route) => route.id != selected.id).toList()
        : results;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.86,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.md,
                AppSpace.sm,
                AppSpace.md,
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  _SheetHeader(total: widget.routes.length),
                  const SizedBox(height: AppSpace.md),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.sm),
                    child: _SearchField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      onClear: _query.isEmpty ? null : _clear,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Ninguna línea coincide',
                      message:
                          'No encontramos «$_query». Prueba con el número del '
                          'micro o el nombre de una calle.',
                      actionLabel: 'Ver todas',
                      onAction: _clear,
                      compact: true,
                    )
                  : CustomScrollView(
                      // Arrastrar la lista cierra el teclado: buscar y luego
                      // recorrer resultados es el gesto natural.
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (pinned) ...[
                          const _SectionLabel(
                            key: ValueKey('route-picker-pinned'),
                            text: 'Elegido',
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.lg,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _RouteRow(
                                route: selected,
                                selected: true,
                                onTap: () => _pick(selected),
                              ),
                            ),
                          ),
                        ],
                        _SectionLabel(
                          text: searching
                              ? '${results.length} '
                                    '${results.length == 1 ? 'resultado' : 'resultados'}'
                              : 'Todas las líneas',
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpace.lg,
                            0,
                            AppSpace.lg,
                            AppSpace.xl + keyboard,
                          ),
                          sliver: SliverList.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpace.sm),
                            itemBuilder: (context, index) {
                              final route = list[index];
                              return Reveal(
                                key: ValueKey('route-pick-${route.id}'),
                                index: index,
                                slide: 6,
                                child: _RouteRow(
                                  route: route,
                                  selected: route.id == selected?.id,
                                  onTap: () => _pick(route),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabecera: disco con el micro, la pregunta y cuántas líneas hay.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final disc = AppColors.tint(colors.primary, colors.surface, 0.14);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
          child: Icon(
            Icons.directions_bus_rounded,
            size: 22,
            color: AppColors.legible(colors.primary, disc),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿En qué micro pasó?',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '$total líneas · por número o calle',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.input);
    final clear = onClear;
    return TextField(
      key: const ValueKey('route-picker-search'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Número de línea o calle…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: clear == null
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                onPressed: clear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.primary, width: 1.6),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg + AppSpace.xs,
        AppSpace.md,
        AppSpace.lg,
        AppSpace.sm,
      ),
      sliver: SliverToBoxAdapter(
        child: Text(
          text.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Fila de una línea: insignia GTFS, «Micro N», por dónde pasa y la foto real.
/// La elegida se tiñe de primario y lleva el check.
class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final RouteSummary route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final base = colors.surfaceContainerLow;
    final fill = selected ? AppColors.tint(colors.primary, base, 0.12) : base;
    final stops = routeStopsSummary(route);
    final meta = [
      if (route.stopCount > 0) '${route.stopCount} paradas',
      if (route.directionsCount > 1) 'ida y vuelta',
    ].join(' · ');
    final radius = BorderRadius.circular(AppRadius.md);
    final photo = route.imageUrl;

    return PressScale(
      scale: 0.98,
      child: Material(
        color: fill,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                // Columna fija para la insignia: con números de 1 a 3 cifras,
                // sin ella el texto de cada fila arrancaba en otro lugar.
                SizedBox(
                  width: 58,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RouteBadge(
                      label: route.shortName,
                      colorHex: route.color,
                      textColorHex: route.textColor,
                      size: RouteBadgeSize.large,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.longName.isNotEmpty
                            ? route.longName
                            : 'Micro ${route.shortName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (stops != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          stops,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                if (photo != null)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      RoutePhoto(
                        url: photo,
                        width: 64,
                        height: 46,
                        radius: BorderRadius.circular(AppRadius.tile),
                      ),
                      if (selected)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: _Check(color: colors.primary),
                        ),
                    ],
                  )
                else if (selected)
                  _Check(color: colors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surface,
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.check_circle_rounded, size: 22, color: color),
  );
}
