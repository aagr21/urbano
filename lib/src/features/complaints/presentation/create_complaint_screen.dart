import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/empty_state.dart';
import '../../home/presentation/widgets/home_route_lattice.dart';
import '../../routes/data/route_models.dart';
import '../../routes/presentation/widgets/route_list_tile.dart';
import '../application/complaints_feed_controller.dart';
import '../data/complaint_repository.dart';
import 'widgets/complaint_chips.dart';

/// Formulario de creación de queja. Vive separado del feed
/// (`complaints_screen.dart`): son dos pantallas con motivos de cambio
/// distintos — la portada/listado por un lado, la captura del reporte por otro.
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
