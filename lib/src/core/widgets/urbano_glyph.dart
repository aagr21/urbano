import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Los cuatro íconos de la marca (set «Micros, Viajes, Lugares y Denuncias»).
enum UrbanoGlyphKind { micros, journey, places, complaints }

/// Ícono plano de la marca, dibujado (no un PNG): escala sin perder filo y se
/// pinta en dos modos.
///
/// * **A color** ([color] nulo): verdes de la paleta con el naranja de acento,
///   como en la lámina de íconos de la marca. Lo usan los accesos de Inicio.
/// * **Monocromo** ([color] dado): toda la silueta en esa tinta, como la lámina
///   gris. Lo usa la barra inferior (gris en reposo, verde seleccionado).
///
/// Los «blancos» del dibujo (ventanas del micro, ojo de los pines, calles del
/// plano) se **recortan** en vez de pintarse de blanco: así el ícono funciona
/// sobre cualquier placa, clara u oscura, sin un blanco duro encima.
class UrbanoGlyph extends StatelessWidget {
  const UrbanoGlyph(
    this.kind, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final UrbanoGlyphKind kind;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glyph = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: UrbanoGlyphPainter(kind, mono: color)),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: glyph);
    return Semantics(label: semanticLabel, image: true, child: glyph);
  }
}

/// Pintor de [UrbanoGlyph]. Dibuja en una caja de 100 × 100 y escala.
class UrbanoGlyphPainter extends CustomPainter {
  const UrbanoGlyphPainter(this.kind, {this.mono});

  final UrbanoGlyphKind kind;
  final Color? mono;

  Color get _green => mono ?? AppColors.brand;
  Color get _greenDark => mono ?? AppColors.primary;
  Color get _lime => mono ?? AppColors.brightGreen;
  Color get _orange => mono ?? AppColors.accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.shortestSide / 100;
    canvas
      ..save()
      ..translate(
        (size.width - 100 * scale) / 2,
        (size.height - 100 * scale) / 2,
      )
      ..scale(scale)
      // Capa propia: los recortes (`BlendMode.clear`) solo agujerean el ícono.
      ..saveLayer(const Rect.fromLTWH(-4, -4, 108, 108), Paint());
    switch (kind) {
      case UrbanoGlyphKind.micros:
        _micro(canvas);
      case UrbanoGlyphKind.journey:
        _journey(canvas);
      case UrbanoGlyphKind.places:
        _places(canvas);
      case UrbanoGlyphKind.complaints:
        _complaints(canvas);
    }
    canvas
      ..restore()
      ..restore();
  }

  static Paint _fill(Color color) => Paint()
    ..color = color
    ..isAntiAlias = true;

  static final Paint _cut = Paint()
    ..blendMode = BlendMode.clear
    ..isAntiAlias = true;

  static Paint _cutStroke(double width) => Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  /// Gota de pin con la punta en [tip] y la cabeza de radio [r].
  static Path _pin(Offset tip, double r) {
    final cy = tip.dy - r * 1.75;
    final cx = tip.dx;
    return Path()
      ..moveTo(cx, tip.dy)
      ..cubicTo(cx - r * 0.35, cy + r * 1.2, cx - r, cy + r * 0.62, cx - r, cy)
      ..arcToPoint(Offset(cx + r, cy), radius: Radius.circular(r))
      ..cubicTo(cx + r, cy + r * 0.62, cx + r * 0.35, cy + r * 1.2, cx, tip.dy)
      ..close();
  }

  static Offset _pinEye(Offset tip, double r) =>
      Offset(tip.dx, tip.dy - r * 1.75);

  void _micro(Canvas canvas) {
    final body = Path()
      ..moveTo(15, 22)
      ..lineTo(76, 22)
      ..quadraticBezierTo(82, 22, 85, 28)
      ..lineTo(93, 44)
      ..quadraticBezierTo(95, 47, 95, 51)
      ..lineTo(95, 66)
      ..quadraticBezierTo(95, 73, 88, 73)
      ..lineTo(12, 73)
      ..quadraticBezierTo(5, 73, 5, 66)
      ..lineTo(5, 32)
      ..quadraticBezierTo(5, 22, 15, 22)
      ..close();
    canvas
      ..drawPath(body, _fill(_green))
      // Franja naranja inferior, recortada por la silueta del micro.
      ..save()
      ..clipPath(body)
      ..drawRect(const Rect.fromLTRB(0, 63, 100, 80), _fill(_orange))
      ..restore();
    // Ventanas.
    const radius = Radius.circular(2.5);
    for (final left in const [11.0, 28.5, 46.0]) {
      canvas.drawRRect(RRect.fromLTRBR(left, 29, left + 14, 45, radius), _cut);
    }
    final front = Path()
      ..moveTo(65.5, 31.5)
      ..quadraticBezierTo(65.5, 29, 68, 29)
      ..lineTo(77, 29)
      ..quadraticBezierTo(79, 29, 80, 31)
      ..lineTo(86, 43)
      ..quadraticBezierTo(87, 45, 84.5, 45)
      ..lineTo(68, 45)
      ..quadraticBezierTo(65.5, 45, 65.5, 42.5)
      ..close();
    canvas
      ..drawPath(front, _cut)
      // Faro.
      ..drawRRect(
        RRect.fromLTRBR(84, 53, 92, 57, const Radius.circular(2)),
        _cut,
      );
    // Ruedas: aro recortado alrededor y cubo hueco.
    for (final x in const [26.0, 72.0]) {
      final center = Offset(x, 74);
      canvas
        ..drawCircle(center, 13, _cut)
        ..drawCircle(center, 9.5, _fill(_green))
        ..drawCircle(center, 3.6, _cut);
    }
  }

  void _journey(Canvas canvas) {
    // Recorrido punteado de un pin al otro.
    final route = Path()
      ..moveTo(34, 86)
      ..quadraticBezierTo(62, 86, 71, 62);
    final dash = Paint()
      ..color = _greenDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (final metric in route.computeMetrics()) {
      var d = 3.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 3), dash);
        d += 12;
      }
    }
    const originTip = Offset(28, 82);
    const destinationTip = Offset(70, 56);
    canvas
      ..drawPath(_pin(originTip, 15), _fill(_orange))
      ..drawCircle(_pinEye(originTip, 15), 6, _cut)
      ..drawPath(_pin(destinationTip, 16), _fill(_green))
      ..drawCircle(_pinEye(destinationTip, 16), 6.5, _cut);
  }

  void _places(Canvas canvas) {
    // Plano plegado (trapecio) con sus calles recortadas.
    final map = Path()
      ..moveTo(22, 50)
      ..lineTo(78, 50)
      ..quadraticBezierTo(81, 50, 82.5, 53)
      ..lineTo(95, 84)
      ..quadraticBezierTo(96.5, 90, 91, 90)
      ..lineTo(9, 90)
      ..quadraticBezierTo(3.5, 90, 5, 84)
      ..lineTo(17.5, 53)
      ..quadraticBezierTo(19, 50, 22, 50)
      ..close();
    canvas
      ..drawPath(map, _fill(_lime))
      ..drawLine(const Offset(2, 69), const Offset(98, 69), _cutStroke(4))
      ..drawLine(const Offset(39, 48), const Offset(31, 92), _cutStroke(4))
      ..drawLine(const Offset(61, 48), const Offset(69, 92), _cutStroke(4));
    const tip = Offset(50, 72);
    // Aro recortado alrededor del pin para despegarlo del plano.
    canvas
      ..drawPath(_pin(tip, 18), _cutStroke(6)..strokeJoin = StrokeJoin.round)
      ..drawPath(_pin(tip, 18), _fill(_orange))
      ..drawCircle(_pinEye(tip, 18), 7, _cut);
  }

  void _complaints(Canvas canvas) {
    // Mango.
    final handle = Path()
      ..moveTo(28, 60)
      ..lineTo(39, 60)
      ..lineTo(45, 84)
      ..quadraticBezierTo(46, 90, 40, 90)
      ..lineTo(38, 90)
      ..quadraticBezierTo(34, 90, 33, 86)
      ..close();
    // Bocina: culata redondeada + cono.
    final bell = Path()
      ..moveTo(30, 38)
      ..lineTo(66, 20)
      ..lineTo(74, 76)
      ..lineTo(30, 62)
      ..close();
    final butt = RRect.fromLTRBR(8, 38, 34, 62, const Radius.circular(10));
    canvas
      ..drawPath(handle, _fill(_green))
      ..drawRRect(butt, _fill(_green))
      ..drawPath(bell, _fill(_green));
    // Boca naranja del cono.
    final rim = Path()
      ..moveTo(64, 19)
      ..quadraticBezierTo(68, 15, 71, 18)
      ..lineTo(80, 76)
      ..quadraticBezierTo(80, 81, 75, 79)
      ..close();
    canvas.drawPath(rim, _fill(_orange));
    // Ondas.
    final wave = Paint()
      ..color = _orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    const center = Offset(80, 46);
    for (final radius in const [8.0, 16.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -0.85,
        1.7,
        false,
        wave,
      );
    }
  }

  @override
  bool shouldRepaint(UrbanoGlyphPainter old) =>
      old.kind != kind || old.mono != mono;
}
