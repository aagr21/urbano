import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/motion.dart';
import '../../../core/identity/passenger_identity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../home/presentation/widgets/home_route_lattice.dart';
import '../../routes/data/route_models.dart';
import '../application/complaints_feed_controller.dart';
import '../application/passenger_controller.dart';
import '../data/complaint_repository.dart';
import 'create_complaint_screen.dart';
import 'widgets/complaint_chips.dart';
import 'widgets/complaint_post_card.dart';
import 'widgets/passenger_avatar.dart';
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
            child: _CoverHeader(
              stats: ref.watch(complaintsStatsProvider),
              loading: visible.isLoading,
              identity: identity,
              onCreate: () => _openForm(context, ref, routes),
              onIdentity: () => showPassengerNameSheet(context),
            ),
          ),
          // Las pastillas se miden contra el fondo REALMENTE pintado de la
          // pantalla (el lienzo del tema), no contra `surface`.
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: _CategoryFilterBar(
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
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primary, AppColors.aqua],
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
                // Compacto y sin área táctil de 48: esta fila NO es contenido,
                // es el encabezado del listado y cada píxel que ocupa se lo
                // quita a la primera queja.
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: notifier.reload,
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.xs,
                  AppSpace.lg,
                  AppSpace.xxl,
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

/// Fila de filtros por motivo: solo los motivos que tienen reportes.
///
/// Se oculta con un solo motivo en juego (no hay nada que elegir) y con el feed
/// sin cargar, para que la fila no aparezca y desaparezca bajo el dedo.
class _CategoryFilterBar extends ConsumerWidget {
  const _CategoryFilterBar({required this.on});

  /// Fondo real sobre el que se pintan las pastillas (mide el contraste).
  final Color on;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reported = ref.watch(reportedCategoriesProvider);
    if (reported.length < 2) return const SizedBox.shrink();
    final colors = context.colors;
    final filter = ref.watch(complaintCategoryFilterProvider);
    final notifier = ref.read(complaintCategoryFilterProvider.notifier);

    return SizedBox(
      // Barra delgada: cada píxel entre la cabecera y el listado es una línea
      // menos de la primera queja (las pastillas miden ~30).
      height: 42,
      child: Stack(
        children: [
          ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            children: [
              ComplaintPill(
                label: 'Todas',
                icon: Icons.apps_rounded,
                accent: colors.primary,
                on: on,
                emphasized: filter == null,
                onTap: () => notifier.state = null,
              ),
              for (final category in reported) ...[
                const SizedBox(width: AppSpace.sm),
                CategoryChip(
                  category: category,
                  on: on,
                  selected: filter == category,
                  // Tocarlo de nuevo lo quita: el filtro es un toggle, no un
                  // callejón.
                  onTap: () =>
                      notifier.state = filter == category ? null : category,
                ),
              ],
            ],
          ),
          // El contenido se desvanece en el borde: así se entiende que la fila
          // sigue y que la pastilla cortada se puede arrastrar.
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: AppSpace.xl,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [on, on.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Portada de la sección: un campo de marca **a sangre** (sin AppBar) con los
/// anillos de la ciudad, el título, el CTA de crear, el apodo y las cifras de la
/// comunidad rodando con [CountUp].
///
/// Sustituye a la tarjeta CTA flotante de la iteración anterior: una tarjeta
/// dentro de una pantalla con AppBar seguía leyéndose como «un listado más».
/// Aquí la pantalla arranca en la marca y el contenido entra debajo.
class _CoverHeader extends StatelessWidget {
  const _CoverHeader({
    required this.stats,
    required this.loading,
    required this.identity,
    required this.onCreate,
    required this.onIdentity,
  });

  final ({int reports, int supports, int comments}) stats;
  final bool loading;
  final PassengerIdentity? identity;
  final VoidCallback onCreate;
  final VoidCallback onIdentity;

  @override
  Widget build(BuildContext context) {
    // El campo es la laguna profunda, no el `urbanoGradient` completo: aquí va
    // texto pequeño encima, así que la tinta clara se mide contra el extremo
    // MÁS CLARO del degradado ([AppColors.fieldMid]) y no contra `primaryDark`,
    // que es el extremo oscuro. El verde agua de la marca entra como riel al
    // pie. Es el mismo campo que abre Inicio: una sola marca, no dos verdes.
    const deep = AppColors.primaryDark;
    const field = AppColors.fieldMid;
    final ink = AppColors.onColor(field);
    final softInk = ink.withValues(alpha: 0.86);
    // Vidrio de las cifras: la misma tinta al 10 %, con filo del 18 %.
    final veil = ink.withValues(alpha: 0.10);
    final edge = ink.withValues(alpha: 0.18);

    return ClipRRect(
      // Esquinas inferiores: la portada es una hoja de marca, no una banda que
      // corta la pantalla en dos.
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.xl),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.fieldMid,
              AppColors.primary,
            ],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            // Los anillos de la ciudad que ya pinta el home: la misma textura de
            // marca, con la unidad circulando. No ocupa layout (va de fondo) y es
            // `IgnorePointer`, así que no roba toques al CTA.
            const Positioned.fill(child: HomeRouteLattice()),
            // Orilla de la laguna: el riel verde agua → laguna de las secciones,
            // ahora al pie de la portada.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.aqua,
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.sm,
                  AppSpace.md,
                  AppSpace.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quejas',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleLarge?.copyWith(
                                  color: ink,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  // Punto de la orilla: la marca en el lugar más
                                  // pequeño de la portada.
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.aqua,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpace.sm),
                                  // `FittedBox` en vez de elipsis: el lema es lo
                                  // primero que se lee de la sección y con la
                                  // etiqueta del CTA se quedaba en «La voz del
                                  // pasaj…». Si no cabe, se achica, nunca se
                                  // corta.
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'La voz del pasajero',
                                        maxLines: 1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: softInk,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        // El CTA va pegado al título, no ocupando una fila de
                        // 48 px para él solo. La etiqueta es corta por lo mismo:
                        // el espacio que usa se lo quita al título; el tooltip
                        // dice el nombre completo.
                        Tooltip(
                          message: 'Crear queja',
                          child: FilledButton.icon(
                            onPressed: onCreate,
                            icon: const Icon(
                              Icons.add_comment_rounded,
                              size: 16,
                            ),
                            label: const Text('Crear'),
                            style: FilledButton.styleFrom(
                              foregroundColor: deep,
                              backgroundColor: ink,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.md,
                                vertical: AppSpace.sm,
                              ),
                              // Se parte de un estilo del tema (titleSmall ya
                              // trae Inter) en vez de un `TextStyle` desnudo:
                              // sin familia el botón cae en la fuente por
                              // defecto y gasta ancho de más, que es justo el
                              // que necesita el título para no cortarse.
                              textStyle: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: identity == null
                              ? 'Tu apodo'
                              : 'Tu apodo: ${identity!.nickname}',
                          onPressed: onIdentity,
                          visualDensity: VisualDensity.compact,
                          icon: identity == null
                              ? Icon(
                                  Icons.account_circle_outlined,
                                  color: ink,
                                  size: 26,
                                )
                              : PassengerAvatar.from(identity!, size: 32),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        _StatTile(
                          value: stats.reports,
                          label: 'reportes',
                          icon: Icons.forum_rounded,
                          veil: veil,
                          ink: ink,
                          edge: edge,
                          loading: loading,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        _StatTile(
                          value: stats.supports,
                          label: 'apoyos',
                          icon: Icons.favorite_rounded,
                          veil: veil,
                          ink: ink,
                          edge: edge,
                          loading: loading,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        _StatTile(
                          value: stats.comments,
                          label: 'comentarios',
                          icon: Icons.chat_bubble_rounded,
                          veil: veil,
                          ink: ink,
                          edge: edge,
                          loading: loading,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini-tile de cifra dentro de la portada de marca.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.veil,
    required this.ink,
    required this.edge,
    required this.loading,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color veil;
  final Color ink;
  final Color edge;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs + 2,
        ),
        decoration: BoxDecoration(
          color: veil,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: edge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: ink.withValues(alpha: 0.8)),
                const SizedBox(width: AppSpace.xs),
                if (loading)
                  const LoadingShimmer(width: 24, height: 18)
                else
                  CountUp(
                    value: value,
                    format: (count) => '$count',
                    style: TextStyle(
                      color: ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink.withValues(alpha: 0.82),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
