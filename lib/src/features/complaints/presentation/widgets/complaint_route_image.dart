import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../routes/data/route_models.dart';

/// Imagen de vista previa de una ruta de micro.
///
/// Muestra la foto de la ruta cuando está disponible; de lo contrario,
/// un placeholder con el ícono de autobús.
class ComplaintRouteImage extends StatelessWidget {
  const ComplaintRouteImage({super.key, required this.route});

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
