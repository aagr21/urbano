import 'package:material_ui/material_ui.dart';

/// Tamaño de decodificación (en píxeles físicos) para una imagen de red.
///
/// `Image.network` decodifica a la resolución ORIGINAL cuando no se le indica
/// otra cosa: una foto de móvil (3000-4000 px de lado) se materializa entera en
/// memoria aunque en pantalla ocupe 360 px. Eso es memoria y jank gratuitos en
/// gama baja. Este helper traduce el tamaño lógico que se va a pintar a píxeles
/// físicos y lo acota con [maxSide]; `ResizeImage` mantiene la proporción, así
/// que pasar sólo el lado conocido es suficiente.
///
/// Devuelve `width`/`height` nulos cuando no hay medida (p. ej. dentro de un
/// scroll sin restricciones): en ese caso se deja el comportamiento por defecto.
({int? width, int? height}) imageDecodeSize(
  BuildContext context, {
  double? logicalWidth,
  double? logicalHeight,
  int maxSide = 1600,
}) {
  final ratio = MediaQuery.devicePixelRatioOf(context);
  int? px(double? logical) {
    if (logical == null || logical <= 0 || !logical.isFinite) return null;
    final value = (logical * ratio).round();
    return value > maxSide ? maxSide : value;
  }

  return (width: px(logicalWidth), height: px(logicalHeight));
}
