import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/urbano_back_button.dart';
import '../../routes/data/route_models.dart';
import '../application/complaints_feed_controller.dart';
import '../application/passenger_controller.dart';
import '../domain/complaint_models.dart';
import 'complaints_cover_header.dart';
import 'complaints_toolbar.dart';
import 'create_complaint_screen.dart';
import 'widgets/complaint_post_card.dart';
import 'widgets/passenger_name_sheet.dart';

/// El formulario de creación vive en su propio archivo; se re-exporta aquí para
/// que quien ya importa el feed (router, tests) siga resolviendo
/// [CreateComplaintScreen] sin cambiar su import.
export 'create_complaint_screen.dart';

class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    List<RouteSummary> routes,
  ) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateComplaintScreen(routes: routes),
      ),
    );
    if (sent == true && context.mounted) {
      await ref.read(complaintsFeedProvider.notifier).reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Queja enviada. Será revisada antes de publicarse.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(visibleComplaintsProvider);
    final routes =
        ref.watch(complaintRoutesProvider).valueOrNull ??
        const <RouteSummary>[];
    final identity = ref.watch(passengerControllerProvider).valueOrNull;
    final notifier = ref.read(complaintsFeedProvider.notifier);
    final filter = ref.watch(complaintCategoryFilterProvider);
    final total = visible.valueOrNull?.length ?? 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // El riel de marca usa el aqua vivo en claro y el secundario apagado del
    // tema en oscuro (el neón sobre grafito era lo que se veía feo).
    final railAccent = dark ? context.colors.secondary : AppColors.aqua;

    return Scaffold(
      // Sin AppBar: la sección abre con su propia portada de marca a sangre. La
      // barra plana de una sola palabra era justo lo que hacía que «Quejas»
      // pareciera un listado más de la app.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El campo de la portada es oscuro: los íconos del sistema van claros
          // mientras se está sobre ella (y el resto de la app sigue su tema).
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: ComplaintsCoverHeader(
              stats: ref.watch(complaintsStatsProvider),
              sort: ref.watch(complaintSortProvider),
              onSort: (sort) =>
                  ref.read(complaintSortProvider.notifier).state = sort,
              loading: visible.isLoading,
              identity: identity,
              onCreate: () => _openForm(context, ref, routes),
              onIdentity: () => showPassengerNameSheet(context),
              // Retroceso: la queja es una pantalla empujada, no una rama de
              // primer nivel. Vive en la fila del título para no sumar alto
              // ni taparlo: la primera tarjeta tiene que seguir entrando.
              leading: const UrbanoBackButton(),
            ),
          ),
          // Las pastillas se miden contra el fondo REALMENTE pintado de la
          // pantalla (el lienzo del tema), no contra `surface`.
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: ComplaintsCategoryFilterBar(
              on: context.colors.surfaceContainerLowest,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.md,
              AppSpace.sm,
              AppSpace.xs,
            ),
            child: Row(
              children: [
                // La misma barra de marca que abre las secciones del home:
                // firma visual, no adorno suelto.
                Container(
                  width: 4,
                  height: 18,
                  margin: const EdgeInsets.only(right: AppSpace.sm),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [context.colors.primary, railAccent],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'La comunidad reporta',
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // El número de la derecha es el de lo visible: si un filtro está
                // puesto, lo que dice el contador es lo que hay abajo.
                if (visible.hasValue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tint(
                        context.colors.primary,
                        context.colors.surfaceContainerLowest,
                        0.14,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$total',
                      style: context.text.labelLarge?.copyWith(
                        color: AppColors.legible(
                          context.colors.primary,
                          AppColors.tint(
                            context.colors.primary,
                            context.colors.surfaceContainerLowest,
                            0.14,
                          ),
                        ),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpace.xs),
                // Orden del feed. Ocupa el lugar del antiguo «Actualizar»: el
                // feed se refresca tirando hacia abajo (y el error trae su
                // propio «Reintentar»), así que la fila gana una acción útil.
                const ComplaintsSortButton(),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.reload,
              child: AsyncListView<ComplaintSummary>(
                value: visible,
                count: 5,
                onRetry: () => notifier.reload(),
                emptyIcon: filter == null
                    ? Icons.forum_outlined
                    : Icons.filter_alt_off_rounded,
                emptyTitle: filter == null
                    ? 'Todavía no hay reportes'
                    : 'Nada reportado de este motivo',
                emptyMessage: 'Sé el primero en ayudar a mejorar el servicio.',
                padding: EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.xs,
                  AppSpace.lg,
                  // La pantalla va edge-to-edge: la última tarjeta tiene que
                  // poder subir por encima del gesto/barra del sistema.
                  AppSpace.xxl + MediaQuery.viewPaddingOf(context).bottom,
                ),
                itemBuilder: (context, complaint, index) => ComplaintPostCard(
                  complaint: complaint,
                  index: index,
                  route: routes
                      .where((route) => route.id == complaint.routeId)
                      .firstOrNull,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
