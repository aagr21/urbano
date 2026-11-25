import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/image_decode.dart';
import '../../../routes/data/route_models.dart';

/// Imagen de vista previa de una ruta de micro.
///
/// Muestra la foto de la ruta cuando está disponible; de lo contrario,
/// un placeholder con el ícono de autobús.
class ComplaintRouteImage extends StatelessWidget {
  const ComplaintRouteImage({super.key, required this.route});

  final RouteSummary route;

  /// Tamaño lógico de la miniatura (lo usan la imagen y el placeholder).
  static const double _width = 68;
  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    final imageUrl = route.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _fallback(context);
    }
    // `cacheWidth`/`cacheHeight`: la foto original pesa megapíxeles y aquí se
    // pinta a 68×48 lógicos.
    final decode = imageDecodeSize(
      context,
      logicalWidth: _width,
      logicalHeight: _height,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.network(
        imageUrl,
        width: _width,
        height: _height,
        fit: BoxFit.cover,
        cacheWidth: decode.width,
        cacheHeight: decode.height,
        errorBuilder: (_, _, _) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) => Container(
    width: _width,
    height: _height,
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Icon(Icons.directions_bus_rounded, color: context.colors.primary),
  );
}
