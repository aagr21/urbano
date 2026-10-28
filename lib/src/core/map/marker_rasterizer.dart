import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_colors.dart';
import 'map_types.dart';

/// Rasteriza el `child` de un [MapMarker] a PNG para `addImage` de MapLibre.
///
/// El widget se monta un instante fuera de pantalla en el [Overlay] raíz, se
/// captura con `RepaintBoundary.toImage` y se cachea por
/// [MapMarker.imageCacheKey] (runtimeType + `iconKey` + tamaño) más el brillo
/// con el que se pintó, así varias paradas con el mismo aspecto comparten
/// imagen pero no la comparten un pin del mapa claro y del mapa oscuro.
class MarkerRasterizer {
  MarkerRasterizer._();

  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// Solo para tests: limpia la caché global de iconos.
  static void clearCache() => _cache.clear();

  static bool isCached(MapMarker marker) =>
      _cache.containsKey(marker.imageCacheKey);

  /// PNG del icono o `null` si el widget no pudo capturarse.
  ///
  /// [pixelRatio] es la densidad con la que se rasteriza (Android/iOS usan
  /// `devicePixelRatio`, web `1`: allí MapLibre recibe `pixelRatio: 1` y el
  /// tamaño en CSS sale de los píxeles del PNG).
  static Future<Uint8List?> rasterize(
    BuildContext context,
    MapMarker marker, {
    double pixelRatio = 3,
  }) async {
    // El brillo del llamador es el del MAPA (ver `MapThemeScope`), no el de la
    // app: el mapa puede estar fijado en oscuro con la app clara. Forma parte de
    // la clave porque al cambiar de brillo el motor recarga el estilo y vuelve a
    // pedir el icono; si la clave fuera ciega al brillo devolviera el PNG viejo.
    final theme = Theme.of(context);
    final key =
        '${marker.imageCacheKey}@${theme.brightness.name}'
        '@${pixelRatio.toStringAsFixed(2)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;

    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        // Fuera de pantalla: se pinta (necesario para toImage) sin parpadear.
        left: -8192,
        top: -8192,
        width: marker.width,
        height: marker.height,
        child: IgnorePointer(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: marker.width,
              height: marker.height,
              // El `Overlay` raíz cuelga POR ENCIMA del `MapThemeScope`, así que
              // allí `Theme.of` devuelve el tema de la app. Sin reinstalar el del
              // llamador, cualquier marcador que lea `context.colors` saldría
              // rasterizado con la letra del tema equivocado (cruce de temas).
              child: Theme(data: theme, child: marker.child),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      // Dos frames: montaje + pintado del RepaintBoundary.
      for (var attempt = 0; attempt < 4; attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        final object = boundaryKey.currentContext?.findRenderObject();
        if (object is RenderRepaintBoundary && !object.debugNeedsPaint) break;
      }
      final object = boundaryKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary || object.debugNeedsPaint) {
        return null;
      }
      final image = await object.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return null;
      final bytes = data.buffer.asUint8List();
      _cache[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    } finally {
      entry.remove();
    }
  }

  /// Icono genérico de respaldo si la captura del widget falla: un pin
  /// dibujado directamente con Canvas (siempre funciona, sin widget tree).
  static Future<Uint8List> fallbackMarker({
    double width = 40,
    double height = 40,
    Color color = AppColors.primary,
  }) async {
    const pixelRatio = 3.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width * pixelRatio, height * pixelRatio),
    );
    canvas.scale(pixelRatio);

    final center = Offset(width / 2, height / 2);
    final radius = (width < height ? width : height) / 2 - 3;
    final paint = Paint()..color = color;
    canvas.drawCircle(center + const Offset(0, -2), radius, paint);
    canvas.drawCircle(
      center + const Offset(0, -2),
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Punta del pin.
    final tip = Path()
      ..moveTo(center.dx - radius * 0.55, center.dy + radius * 0.35)
      ..lineTo(center.dx, height - 1)
      ..lineTo(center.dx + radius * 0.55, center.dy + radius * 0.35)
      ..close();
    canvas.drawPath(tip, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pixelRatio).ceil(),
      (height * pixelRatio).ceil(),
    );
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
