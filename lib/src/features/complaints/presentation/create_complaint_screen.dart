import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/urbano_back_button.dart';
import '../../routes/data/route_models.dart';
import '../application/complaint_photos.dart';
import '../application/complaints_feed_controller.dart';
import '../data/complaint_repository.dart';
import 'widgets/complaint_chips.dart';
import 'widgets/complaint_form_parts.dart';
import 'widgets/complaint_form_section.dart';
import 'widgets/complaint_photo_picker.dart';
import 'widgets/complaint_photo_source_sheet.dart';
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
  late RouteSummary? _route = widget.initialRoute;
  String _category = 'vehicle';
  List<XFile> _photos = [];
  bool _sending = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Pregunta la fuente (galería o cámara) y suma las fotos hasta el tope.
  Future<void> _addPhotos() async {
    if (!canAddComplaintPhoto(_photos.length)) {
      _showMessage('Puedes adjuntar hasta $maxComplaintPhotos fotos.');
      return;
    }
    final source = await showComplaintPhotoSourceSheet(context);
    if (source == null || !mounted) return;
    try {
      final picked = await ref.read(complaintPhotoSourceProvider).pick(source);
      if (!mounted) return;
      setState(() => _photos = appendComplaintPhotos(_photos, picked));
    } on Exception catch (error) {
      if (mounted) {
        _showMessage('No se pudo acceder a las fotos o la cámara: $error');
      }
    }
  }

  Future<RouteSummary?> _selectRoute() async {
    final selected = await showModalBottomSheet<RouteSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // La hoja trae su propia asa dentro de su superficie: la del tema
      // flotaba aparte, sobre el formulario.
      showDragHandle: false,
      builder: (_) =>
          ComplaintRouteSelectorSheet(routes: widget.routes, selected: _route),
    );
    if (selected != null && mounted) setState(() => _route = selected);
    return selected;
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
            const ComplaintFormHero(),
            const SizedBox(height: AppSpace.lg),
            ComplaintFormSection(
              step: 1,
              title: '¿Qué micro está involucrado?',
              icon: Icons.directions_bus_rounded,
              child: ComplaintRouteField(route: _route, onPick: _selectRoute),
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
              child: ComplaintDescriptionField(controller: _description),
            ),
            const SizedBox(height: AppSpace.md),
            ComplaintFormSection(
              step: 4,
              title: 'Añade pruebas (opcional)',
              icon: Icons.photo_library_rounded,
              subtitle: 'Hasta 5 fotos para ayudarnos a revisar el reporte.',
              child: ComplaintPhotoPicker(
                photos: _photos,
                onAdd: _sending ? null : _addPhotos,
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
