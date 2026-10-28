import 'package:flutter/material.dart';

import '../animation/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Logo de Urbano: micro frontal plano (dibujado aquí, sin íconos genéricos)
/// sobre un squircle con el degradado de la marca.
///
/// Se pintan, en orden: líneas de "movimiento" a la izquierda, ruedas que
/// asoman bajo la carrocería, carrocería blanca, franja de destino ámbar,
/// parabrisas con brillo y faros. Todo en coordenadas 0–100 escaladas a
/// [size], así que el mismo widget sirve para 40 px en la cabecera y 88 px
/// en "Acerca de".
///
/// Al montar, la micro **llega andando**: entra con un rebote mínimo, las
/// líneas de velocidad se estiran y los faros se encienden al final del
/// recorrido. Un solo gesto, acotado (sin bucles), que se apaga con
/// «reducir animaciones».
class UrbanoLogo extends StatefulWidget {
  const UrbanoLogo({super.key, this.size = 48, this.shadow = true});

  /// Lado del logo (es cuadrado).
  final double size;

  /// Sombra turquesa bajo el squircle.
  final bool shadow;

  @override
  State<UrbanoLogo> createState() => _UrbanoLogoState();
}

class _UrbanoLogoState extends State<UrbanoLogo>
    with SingleTickerProviderStateMixin {
  static const Curve _bounce = Curves.easeOutBack;

  /// 0 = la micro todavía viene en camino; 1 = instalada y con faros.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `MediaQuery` no se lee en `initState`, y el arranque se decide una sola
    // vez para que un re-layout no repita la llegada.
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        return Transform.scale(
          // 0.94 → 1 con rebote: se nota que algo llegó, no que la cabecera
          // se bambea.
          scale: 0.94 + 0.06 * _bounce.transform(progress),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.3),
              gradient: urbanoGradient,
              boxShadow: widget.shadow
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: size * 0.45,
                        offset: Offset(0, size * 0.14),
                      ),
                    ]
                  : null,
            ),
            child: CustomPaint(painter: _BusPainter(progress)),
          ),
        );
      },
    );
  }
}

class _BusPainter extends CustomPainter {
  /// Escala del lienzo de referencia.
  static const double _k = 100;

  const _BusPainter(this.progress);

  /// 0..1 de la llegada (`1` = logo ya instalado).
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _k;
    final arrive = Curves.easeOutCubic.transform(progress);
    // Los faros se encienden en la segunda mitad: es el punto final del gesto.
    final lamps = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);

    // Líneas de movimiento (asimetría a la izquierda: la micro "viene andando").
    // Mientras llega son más cortas y tenues, y se estiran hasta su lugar.
    final dash = Paint()
      ..strokeWidth = 4.5 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset((6 - 2 * arrive) * s, 38 * s),
      Offset(14 * s, 38 * s),
      dash..color = Colors.white.withValues(alpha: 0.75 * arrive),
    );
    canvas.drawLine(
      Offset((3 - 2 * arrive) * s, 49 * s),
      Offset(10 * s, 49 * s),
      dash
        ..color = Colors.white.withValues(
          alpha: 0.4 * ((progress - 0.15) / 0.85).clamp(0.0, 1.0),
        ),
    );

    // Ruedas: círculos oscuros que asoman debajo de la carrocería.
    final wheel = Paint()..color = const Color(0xFF07231F);
    canvas.drawCircle(Offset(33 * s, 66 * s), 6.5 * s, wheel);
    canvas.drawCircle(Offset(67 * s, 66 * s), 6.5 * s, wheel);

    // Carrocería blanca.
    final body = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(24 * s, 24 * s, 76 * s, 66 * s),
        Radius.circular(10 * s),
      ),
      body,
    );

    // Franja de destino (cartel frontal ámbar).
    final sign = Paint()..color = const Color(0xFFFFC53D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(32 * s, 29 * s, 68 * s, 36 * s),
        Radius.circular(3.5 * s),
      ),
      sign,
    );

    // Parabrisas + brillo de vidrio.
    final glass = Paint()..color = const Color(0xFF094A42);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(30 * s, 40 * s, 70 * s, 55 * s),
        Radius.circular(5.5 * s),
      ),
      glass,
    );
    final gleam = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(33 * s, 42.5 * s, 45 * s, 47.5 * s),
        Radius.circular(2.5 * s),
      ),
      gleam,
    );

    // Faros (se encienden al instalarse).
    final lamp = Paint()..color = const Color(0xFFFFC53D);
    final lampRadius = (1.6 + 1.2 * lamps) * s;
    canvas.drawCircle(Offset(35 * s, 61 * s), lampRadius, lamp);
    canvas.drawCircle(Offset(65 * s, 61 * s), lampRadius, lamp);
  }

  @override
  bool shouldRepaint(_BusPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
