import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';

/// Hoja «¿de dónde sacamos la foto?»: galería (varias) o cámara. Devuelve la
/// fuente elegida o `null` si se cierra.
Future<ImageSource?> showComplaintPhotoSourceSheet(BuildContext context) =>
    showModalBottomSheet<ImageSource>(
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
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Tomar una foto'),
                subtitle: const Text('Usar la cámara del dispositivo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
