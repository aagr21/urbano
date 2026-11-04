import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/animation/motion.dart';
import '../../../core/identity/passenger_identity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../home/presentation/widgets/home_route_lattice.dart';
import '../../routes/data/route_models.dart';
import '../../routes/presentation/widgets/route_list_tile.dart';
import '../application/complaints_feed_controller.dart';
import '../application/passenger_controller.dart';
import '../data/complaint_repository.dart';
import 'widgets/complaint_chips.dart';
import 'widgets/complaint_post_card.dart';
import 'widgets/passenger_avatar.dart';
import 'widgets/passenger_name_sheet.dart';

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

class CreateComplaintScreen extends ConsumerStatefulWidget {
  const CreateComplaintScreen({
    super.key,
    required this.routes,
    this.initialRoute,
  });

  final List<RouteSummary> routes;
  final RouteSummary? initialRoute;

  @override
  ConsumerState<CreateComplaintScreen> createState() =>
      _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends ConsumerState<CreateComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  late RouteSummary? _route;
  String _category = 'vehicle';
  List<XFile> _photos = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _route = widget.initialRoute;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos(ImageSource source) async {
    if (_photos.length >= 5) {
      _showMessage('Puedes adjuntar hasta 5 fotos.');
      return;
    }
    try {
      final List<XFile> selected;
      if (source == ImageSource.gallery) {
        selected = await _picker.pickMultiImage(
          imageQuality: 82,
          maxWidth: 1600,
        );
      } else {
        final photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 82,
          maxWidth: 1600,
        );
        selected = photo == null ? const [] : [photo];
      }
      if (!mounted) return;
      setState(() => _photos = [..._photos, ...selected].take(5).toList());
    } on Exception catch (error) {
      if (mounted) {
        _showMessage(
          'No se pudo acceder a las fotos o la cámara: ${error.toString()}',
        );
      }
    }
  }

  Future<void> _showPhotoOptions() async {
    if (_photos.length >= 5) {
      _showMessage('Puedes adjuntar hasta 5 fotos.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Elegir de la galería'),
                subtitle: const Text('Puedes seleccionar varias fotos'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhotos(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Tomar una foto'),
                subtitle: const Text('Usar la cámara del dispositivo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhotos(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectRoute() async {
    final selected = await showModalBottomSheet<RouteSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _RouteSelectorSheet(routes: widget.routes, selected: _route),
    );
    if (selected != null && mounted) {
      setState(() => _route = selected);
    }
  }

  Future<void> _submit() async {
    if (_sending || !(_formKey.currentState?.validate() ?? false)) return;
    final route = _route;
    if (route == null) {
      _showMessage('Selecciona el micro relacionado.');
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(complaintRepositoryProvider)
          .create(
            routeId: route.id,
            category: _category,
            description: _description.text.trim(),
            photos: _photos,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage('No se pudo enviar la queja: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tinta medida contra el degradado de marca (nunca un blanco escrito a mano).
    final onGradient = AppColors.onColor(AppColors.primaryDark);
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva queja')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.sm,
            AppSpace.lg,
            AppSpace.xl,
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.card,
                boxShadow: AppTheme.softShadow(
                  color: AppColors.primaryDark,
                  opacity: 0.16,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.card,
                child: DecoratedBox(
                  decoration: const BoxDecoration(gradient: urbanoGradient),
                  child: Stack(
                    children: [
                      // La misma trama de anillos del feed y del home: el
                      // formulario también es parte de la marca.
                      const Positioned.fill(child: HomeRouteLattice()),
                      Padding(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: Row(
                          children: [
                            Icon(
                              Icons.campaign_rounded,
                              color: onGradient,
                              size: 32,
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cuéntanos qué ocurrió',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: onGradient,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                    'Tu reporte es anónimo y nos ayuda a '
                                    'mejorar.',
                                    style: TextStyle(
                                      color: onGradient.withValues(alpha: 0.88),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            _FormSection(
              step: 1,
              title: '¿Qué micro está involucrado?',
              icon: Icons.directions_bus_rounded,
              child: FormField<RouteSummary>(
                initialValue: _route,
                validator: (value) =>
                    value == null ? 'Selecciona el micro relacionado' : null,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () async {
                        await _selectRoute();
                        field.didChange(_route);
                      },
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 64,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.md,
                            ),
                            decoration: BoxDecoration(
                              color: _route == null
                                  ? context.colors.surfaceContainerLow
                                  : context.colors.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppRadius.input,
                              ),
                              border: Border.all(
                                color: field.errorText != null
                                    ? context.colors.error
                                    : _route == null
                                    ? context.colors.outlineVariant
                                    : context.colors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_route == null)
                                  Icon(
                                    Icons.search_rounded,
                                    color: context.colors.onSurfaceVariant,
                                  )
                                else
                                  _RouteImage(route: _route!),
                                const SizedBox(width: AppSpace.md),
                                Expanded(
                                  child: _route == null
                                      ? Text(
                                          'Buscar y seleccionar una línea',
                                          style: TextStyle(
                                            color:
                                                context.colors.onSurfaceVariant,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _route!.longName.isEmpty
                                                  ? 'Micro ${_route!.shortName}'
                                                  : _route!.longName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                          if (field.errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpace.md,
                                top: AppSpace.xs,
                              ),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: context.colors.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            _FormSection(
              step: 2,
              title: '¿Cuál es el motivo?',
              icon: Icons.category_rounded,
              subtitle: 'Su color es el mismo con el que se lista en el feed.',
              child: Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  // Mismas pastillas del filtro y de la tarjeta: elegir motivo
                  // y reconocerlo en la lista son el mismo gesto visual.
                  for (final category in complaintCategoryOrder)
                    CategoryChip(
                      category: category,
                      on: context.colors.surface,
                      selected: _category == category,
                      onTap: () => setState(() => _category = category),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            _FormSection(
              step: 3,
              title: 'Describe lo ocurrido',
              icon: Icons.edit_note_rounded,
              child: TextFormField(
                controller: _description,
                minLines: 5,
                maxLines: 7,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'Cuéntanos brevemente qué pasó (opcional).',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            _FormSection(
              step: 4,
              title: 'Añade pruebas (opcional)',
              icon: Icons.photo_library_rounded,
              subtitle: 'Hasta 5 fotos para ayudarnos a revisar el reporte.',
              child: _PhotoPicker(
                photos: _photos,
                onAdd: _sending ? null : _showPhotoOptions,
                onRemove: (index) => setState(() => _photos.removeAt(index)),
              ),
            ),
          ],
        ),
      ),
      // El envío vive fuera del scroll: la acción principal queda siempre a la
      // vista (y a un pulgar de distancia) en vez de al final de un formulario
      // largo.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.sm,
            AppSpace.lg,
            AppSpace.sm,
          ),
          child: FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_sending ? 'Enviando…' : 'Enviar queja'),
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.step,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  /// Número del paso: convierte una pila de cajas en un formulario que se
  /// entiende de un vistazo.
  final int step;
  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final badgeFill = AppColors.tint(colors.primary, colors.surface, 0.14);
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeFill,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '$step',
                  style: TextStyle(
                    color: AppColors.legible(colors.primary, badgeFill),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Icon(icon, size: 18, color: colors.onSurfaceVariant),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpace.md),
          child,
        ],
      ),
    );
  }
}

class _RouteImage extends StatelessWidget {
  const _RouteImage({required this.route});

  final RouteSummary route;

  @override
  Widget build(BuildContext context) {
    final imageUrl = route.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _fallback(context);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.network(
        imageUrl,
        width: 68,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) => Container(
    width: 68,
    height: 48,
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Icon(Icons.directions_bus_rounded, color: context.colors.primary),
  );
}

class _RouteSelectorSheet extends StatefulWidget {
  const _RouteSelectorSheet({required this.routes, required this.selected});

  final List<RouteSummary> routes;
  final RouteSummary? selected;

  @override
  State<_RouteSelectorSheet> createState() => _RouteSelectorSheetState();
}

class _RouteSelectorSheetState extends State<_RouteSelectorSheet> {
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

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> photos;

  /// `null` mientras se envía: el mosaico se apaga pero no desaparece.
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canAdd = photos.length < 5;
    // Sin fotos, el botón es una zona ancha de «añadir»; con fotos, se vuelve
    // la última pieza del mosaico. El gesto de añadir no cambia de sitio.
    final wide = photos.isEmpty;
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (var index = 0; index < photos.length; index++)
          SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.file(
                      File(photos[index].path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpace.xs,
                  right: AppSpace.xs,
                  child: IconButton(
                    onPressed: () => onRemove(index),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Quitar foto',
                    style: IconButton.styleFrom(
                      // Pastilla sobre la foto: `inverseSurface` se invierte con
                      // el tema en vez de fijar negro/blanco.
                      backgroundColor: colors.inverseSurface.withValues(
                        alpha: 0.72,
                      ),
                      foregroundColor: colors.onInverseSurface,
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (canAdd)
          SizedBox(
            width: wide ? double.infinity : 86,
            height: wide ? 92 : 86,
            child: Material(
              color: AppColors.tint(colors.primary, colors.surface, 0.07),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.tint(
                        colors.primary,
                        colors.outlineVariant,
                        0.55,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 24,
                        color: colors.primary,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        wide
                            ? 'Añadir fotos · ${photos.length} de 5'
                            : 'Añadir',
                        textAlign: TextAlign.center,
                        style: context.text.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
