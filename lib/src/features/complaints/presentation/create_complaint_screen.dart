import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/urbano_back_button.dart';
import '../../home/presentation/widgets/home_route_lattice.dart';
import '../../routes/data/route_models.dart';
import '../application/complaints_feed_controller.dart';
import '../data/complaint_repository.dart';
import 'widgets/complaint_chips.dart';
import 'widgets/complaint_form_section.dart';
import 'widgets/complaint_photo_picker.dart';
import 'widgets/complaint_route_image.dart';
import 'widgets/complaint_route_selector_sheet.dart';

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
          ComplaintRouteSelectorSheet(routes: widget.routes, selected: _route),
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
      if (mounted) _showMessage('No se pudo enviar la denuncia: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tinta medida contra el degradado de marca (nunca un blanco escrito a mano).
    final onGradient = AppColors.onColor(AppColors.primaryDark);
    return Scaffold(
      appBar: AppBar(
        leading: const UrbanoBackButton(),
        title: const Text('Nueva denuncia'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.sm,
            AppSpace.lg,
            AppSpace.xl + MediaQuery.viewPaddingOf(context).bottom,
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
            ComplaintFormSection(
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
                                  ComplaintRouteImage(route: _route!),
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
            ComplaintFormSection(
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
            ComplaintFormSection(
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
            ComplaintFormSection(
              step: 4,
              title: 'Añade pruebas (opcional)',
              icon: Icons.photo_library_rounded,
              subtitle: 'Hasta 5 fotos para ayudarnos a revisar el reporte.',
              child: ComplaintPhotoPicker(
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
            label: Text(_sending ? 'Enviando…' : 'Enviar denuncia'),
          ),
        ),
      ),
    );
  }
}
