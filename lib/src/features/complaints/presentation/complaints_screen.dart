import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/animation/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../routes/data/route_models.dart';
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
      appBar: AppBar(
        title: const Text('Quejas'),
        actions: [
          IconButton(
            tooltip: 'Nueva queja',
            onPressed: () => _openForm(context, ref, routes),
            icon: const Icon(Icons.add_comment_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.sm),
            child: IconButton(
              tooltip: identity == null
                  ? 'Tu apodo'
                  : 'Tu apodo: ${identity.nickname}',
              onPressed: () => showPassengerNameSheet(context),
              icon: identity == null
                  ? Icon(
                      Icons.account_circle_outlined,
                      color: context.colors.onSurfaceVariant,
                    )
                  : PassengerAvatar.from(identity, size: 34),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.sm,
            ),
            child: _CommunityHeader(
              stats: ref.watch(complaintsStatsProvider),
              loading: visible.isLoading,
              onCreate: () => _openForm(context, ref, routes),
            ),
          ),
          _CategoryFilterBar(on: context.colors.surface),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.md,
              0,
            ),
            child: Row(
              children: [
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
                  Text(
                    '$total',
                    style: context.text.titleMedium?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w800,
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
      child: ListView(
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
              // Tocarlo de nuevo lo quita: el filtro es un toggle, no un callejón.
              onTap: () =>
                  notifier.state = filter == category ? null : category,
            ),
          ],
        ],
      ),
    );
  }
}

/// Cabecera de la pantalla: tarjeta CTA de la marca con las cifras de la
/// comunidad (reportes, apoyos, comentarios) rodando con [CountUp].
class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({
    required this.stats,
    required this.loading,
    required this.onCreate,
  });

  final ({int reports, int supports, int comments}) stats;
  final bool loading;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    // Sobre el degradado de marca (siempre oscuro): la tinta se MIDE contra él
    // con `onColor` en vez de escribir blanco a mano, y el velo de las
    // pasadillas es esa misma tinta al 16%.
    final onGradient = AppColors.onColor(AppColors.primaryDark);
    final veil = onGradient.withValues(alpha: 0.16);
    return Container(
      // Compacta por diseño: esta tarjeta NO es contenido, es la cortina del
      // listado, y todo lo que mide se le descuenta a la primera queja.
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        gradient: urbanoGradient,
        borderRadius: AppRadius.card,
        boxShadow: AppTheme.softShadow(
          color: AppColors.primaryDark,
          opacity: 0.22,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: veil,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.campaign_rounded,
                  color: onGradient,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              // `FittedBox` en vez de elipsis: el título es lo primero que se
              // lee de la marca y con la etiqueta larga del CTA se quedaba en
              // «La voz del pasaj…». Si no cabe, se achica, nunca se corta.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'La voz del pasajero',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: onGradient,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              // El CTA va pegado al título, no ocupando una fila de 48 px para
              // él solo abajo (la creación también vive en la AppBar). La
              // etiqueta es corta por lo mismo: el espacio que usa se lo quita
              // al título; el tooltip dice el nombre completo.
              Tooltip(
                message: 'Crear queja',
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_comment_rounded, size: 16),
                  label: const Text('Crear'),
                  style: FilledButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    backgroundColor: onGradient,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                      vertical: AppSpace.xs,
                    ),
                    // Se parte de un estilo del tema (titleSmall ya trae Inter)
                    // en vez de un `TextStyle` desnudo: sin familia el botón
                    // cae en la fuente por defecto y gasta ancho de más, que es
                    // justo el que necesita el título para no cortarse.
                    textStyle: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                  ),
                ),
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
                ink: onGradient,
                loading: loading,
              ),
              const SizedBox(width: AppSpace.sm),
              _StatTile(
                value: stats.supports,
                label: 'apoyos',
                icon: Icons.favorite_rounded,
                veil: veil,
                ink: onGradient,
                loading: loading,
              ),
              const SizedBox(width: AppSpace.sm),
              _StatTile(
                value: stats.comments,
                label: 'comentarios',
                icon: Icons.chat_bubble_rounded,
                veil: veil,
                ink: onGradient,
                loading: loading,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mini-tile de cifra dentro de la cabecera de marca.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.veil,
    required this.ink,
    required this.loading,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color veil;
  final Color ink;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: veil,
          borderRadius: BorderRadius.circular(AppRadius.tile),
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
                color: ink.withValues(alpha: 0.78),
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
            AppSpace.xxl,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                gradient: urbanoGradient,
                borderRadius: AppRadius.card,
                boxShadow: AppTheme.softShadow(
                  color: AppColors.primaryDark,
                  opacity: 0.16,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign_rounded, color: onGradient, size: 32),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuéntanos qué ocurrió',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: onGradient,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          'Tu reporte es anónimo y nos ayuda a mejorar.',
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
            const SizedBox(height: AppSpace.xl),
            _FormSection(
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
            const SizedBox(height: AppSpace.sm),
            _FormSection(
              title: 'Añade pruebas (opcional)',
              icon: Icons.photo_library_rounded,
              subtitle: 'Hasta 5 fotos para ayudarnos a revisar el reporte.',
              child: OutlinedButton.icon(
                onPressed: _sending ? null : _showPhotoOptions,
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: Text('Seleccionar fotos (${_photos.length}/5)'),
              ),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              _PhotoGrid(
                photos: _photos,
                onRemove: (index) => setState(() => _photos.removeAt(index)),
              ),
            ],
            const SizedBox(height: AppSpace.xl),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Enviando…' : 'Enviar queja'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
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

class _RouteListImage extends StatelessWidget {
  const _RouteListImage({required this.route});

  final RouteSummary route;

  @override
  Widget build(BuildContext context) {
    final imageUrl = route.imageUrl;
    final color = AppColors.fromHex(route.color);
    final fallback = Container(
      width: 68,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        route.shortName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.onColor(color),
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Image.network(
        imageUrl,
        width: 68,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
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
                        return Card(
                          margin: EdgeInsets.zero,
                          color: selected
                              ? colors.primaryContainer
                              : colors.surfaceContainerLow,
                          child: ListTile(
                            onTap: () => Navigator.pop(context, route),
                            leading: _RouteListImage(route: route),
                            title: Text(
                              route.longName.isEmpty
                                  ? 'Micro ${route.shortName}'
                                  : route.longName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.onRemove});

  final List<XFile> photos;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
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
                      backgroundColor: context.colors.inverseSurface.withValues(
                        alpha: 0.72,
                      ),
                      foregroundColor: context.colors.onInverseSurface,
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
