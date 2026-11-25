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
///
/// El valor se **redondea hacia arriba en escalones de [decodeStep] px**, con
/// [decodeStep] como mínimo. Dos razones:
///  * nunca puede salir 0: una caja que se anima desde casi nada (abrir una
///    foto del resultado de viaje) medía 0,1 dp en algún frame, `round()` daba
///    0 y `Image` fallaba con `cacheWidth == null || cacheWidth > 0`;
///  * los tamaños intermedios de una animación caen en el mismo escalón, así
///    que comparten la imagen ya decodificada en vez de decodificar de nuevo
///    en cada frame.
({int? width, int? height}) imageDecodeSize(
  BuildContext context, {
  double? logicalWidth,
  double? logicalHeight,
  int maxSide = 1600,
}) {
  final ratio = MediaQuery.devicePixelRatioOf(context);
  int? px(double? logical) {
    if (logical == null || logical <= 0 || !logical.isFinite) return null;
    final steps = (logical * ratio / decodeStep).ceil().clamp(1, 1 << 20);
    final value = steps * decodeStep;
    return value > maxSide ? maxSide : value;
  }

  return (width: px(logicalWidth), height: px(logicalHeight));
}

/// Escalón (y mínimo) del tamaño de decodificación, en píxeles físicos.
const int decodeStep = 128;
