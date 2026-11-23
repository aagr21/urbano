import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../routes/data/route_models.dart';
import '../../../routes/presentation/widgets/route_list_tile.dart';

/// Hoja modal para seleccionar un micro de la lista de rutas.
///
/// Permite buscar por número o nombre y muestra la ruta ya seleccionada
/// con un check. Reutiliza [RouteListTile] para mantener consistencia
/// visual con el catálogo de micros.
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query = _query.toLowerCase();
    final routes = widget.routes.where((route) {
      final text = '${route.shortName} ${route.longName}'.toLowerCase();
      return text.contains(query);
    }).toList();

    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.82,
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
                AppSpace.lg,
                AppSpace.sm,
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
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Selecciona un micro',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${routes.length}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: InputDecoration(
                      hintText: 'Buscar por número o nombre…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: routes.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Sin coincidencias',
                      message: 'Prueba con otro número o nombre.',
                      compact: true,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg,
                        AppSpace.sm,
                        AppSpace.lg,
                        AppSpace.xl,
                      ),
                      itemCount: routes.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpace.sm),
                      itemBuilder: (context, index) {
                        final route = routes[index];
                        final selected = route.id == widget.selected?.id;
                        // La misma fila que el catálogo de micros: foto, insignia
                        // del color GTFS y conteos. Elegir aquí no debería verse
                        // distinto que reconocerlo en cualquier otro listado.
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.card,
                            // Anillo de selección, no fondo: la fila del
                            // catálogo ya trae su propia superficie.
                            border: Border.all(
                              color: selected
                                  ? colors.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: RouteListTile(
                            route: route,
                            index: index,
                            onTap: () => Navigator.pop(context, route),
                            trailing: selected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: colors.primary,
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
