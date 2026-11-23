import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'home_action_complaints_painter.dart';
import 'home_action_journey_painter.dart';
import 'home_action_micros_painter.dart';
import 'home_action_places_painter.dart';

/// Ilustración plana de un acceso de la portada.
///
/// La referencia dibuja cada cuadro con una pieza propia (el micro, la ruta,
/// el pin, el megáfono) en vez de un ícono genérico dentro de un disco: el
/// lienzo de la portada se lee como un mapa ilustrado y no como una lista de
/// botones. Todo se pinta aquí, sin imágenes ni red, así el home arranca igual
/// en cualquier teléfono.
///
/// Cada ilustración vive en su propio pintor (`home_action_*_painter.dart`)
/// para mantener responsabilidades únicas y facilitar modificaciones.
enum HomeActionArt { micros, journey, places, complaints }

class HomeActionIllustration extends StatelessWidget {
  const HomeActionIllustration(
    this.art, {
    super.key,
    this.size = const Size(124, 84),
  });

  final HomeActionArt art;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(painter: _ArtPainter(art: art)),
    );
  }
}

/// Dispatcher que escala al lienzo de diseño y delega al pintor correspondiente.
class _ArtPainter extends CustomPainter {
  const _ArtPainter({required this.art});

  final HomeActionArt art;

  /// Lienzo de diseño: todas las coordenadas de los pintores viven aquí y se
  /// escalan al tamaño real conservando la proporción.
  static const Size _design = Size(124, 84);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / _design.width,
      size.height / _design.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - _design.width * scale) / 2,
      (size.height - _design.height * scale) / 2,
    );
    canvas.scale(scale, scale);
    switch (art) {
      case HomeActionArt.micros:
        const HomeActionMicrosPainter().paint(canvas);
      case HomeActionArt.journey:
        const HomeActionJourneyPainter().paint(canvas);
      case HomeActionArt.places:
        const HomeActionPlacesPainter().paint(canvas);
      case HomeActionArt.complaints:
        const HomeActionComplaintsPainter().paint(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art;
}
