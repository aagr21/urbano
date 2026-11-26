import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Tope de fotos adjuntas a una denuncia.
const int maxComplaintPhotos = 5;

/// ¿Cabe otra foto?
bool canAddComplaintPhoto(int current) => current < maxComplaintPhotos;

/// Suma las fotos nuevas respetando el tope (las que sobran se descartan).
List<T> appendComplaintPhotos<T>(List<T> current, List<T> added) =>
    [...current, ...added].take(maxComplaintPhotos).toList();

/// Acceso a cámara y galería para adjuntar fotos. Interfaz propia para que
/// el formulario no dependa del plugin (y los tests no necesiten canal).
abstract interface class ComplaintPhotoSource {
  /// Fotos elegidas (vacío si el usuario cancela). Puede lanzar si el
  /// sistema niega el acceso.
  Future<List<XFile>> pick(ImageSource source);
}

/// Implementación real sobre `image_picker`: fotos a 1600 px y calidad 82
/// (legibles para revisar el reporte sin subir megas por la red móvil).
class ImagePickerPhotoSource implements ComplaintPhotoSource {
  ImagePickerPhotoSource([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const _quality = 82;
  static const double _maxWidth = 1600;

  @override
  Future<List<XFile>> pick(ImageSource source) async {
    if (source == ImageSource.gallery) {
      return _picker.pickMultiImage(
        imageQuality: _quality,
        maxWidth: _maxWidth,
      );
    }
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: _quality,
      maxWidth: _maxWidth,
    );
    return photo == null ? const [] : [photo];
  }
}

final complaintPhotoSourceProvider = Provider<ComplaintPhotoSource>(
  (_) => ImagePickerPhotoSource(),
);
