import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animation/motion.dart';
import '../config/env.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import '../utils/extensions.dart';
import 'urbano_logo.dart';

/// Portada de arranque: pinta la identidad de Urbano sobre la app mientras esta
/// termina de montar (el mapa y las ramas del shell) y se levanta sola.
///
/// No es un `Timer` ni una espera de red: la portada es una **línea de tiempo**
/// de [_SplashCover.span] llevada por un `TweenAnimationBuilder`, así que bajo
/// `flutter test` la avanza un `pump(duration)` cualquiera y `pumpAndSettle`
/// converge en cuanto se levanta (nada queda montado ni con ticker abierto).
/// Tampoco bloquea el diálogo nativo de ubicación: ese corre detrás, en la
/// puerta de arranque, y la portada se quita igual a su ritmo.
///
/// La coreografía es la marca, en este orden: los anillos de Santa Cruz se
/// trazan desde la esquina inferior izquierda, una micro recorre su corredor
/// y sale de pantalla, el logo llega andando (gesto propio de [UrbanoLogo]),
/// el nombre sube desde abajo, la barra de carga se llena y la portada se
/// desvanece con un empujón corto. Con «reducir animaciones» no hay portada: la
/// app aparece directo, sin fundidos.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _covering = true;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      // Sin «reducir animaciones» no hay portada ni fundido: el gesto completo
      // es movimiento, no información.
      // Fuera del árbol al terminar: sin opacidad 0 ni ticker esperando.
      if (_covering && !Motion.reduced(context))
        Positioned.fill(
          child: _SplashCover(
            onLifted: () => setState(() => _covering = false),
          ),
        ),
    ],
  );
}

/// La portada en sí: un solo `TweenAnimationBuilder` (t = 0..1 del total) del
/// que salen TODAS las ventanas de la coreografía, para que no haya un
/// controller por efecto.
class _SplashCover extends StatelessWidget {
  const _SplashCover({required this.onLifted});

  /// Se llama al terminar el último frame de la salida.
  final VoidCallback onLifted;

  /// Duración total: lo que tarda la micro en cruzar su anillo.
  static const Duration span = Duration(milliseconds: 1500);

  // Ventanas, en fracción del total.
  static const double _ringsBegin = 0;
  static const double _ringsEnd = 0.68;
  static const double _busBegin = 0.06;
  static const double _busEnd = 0.96;
  static const double _typeBegin = 0.3;
  static const double _typeEnd = 0.6;
  static const double _pingBegin = 0.44;
  static const double _pingEnd = 0.92;
  static const double _barBegin = 0.34;
  static const double _barEnd = 0.86;
  static const double _footBegin = 0.5;
  static const double _footEnd = 0.78;
  static const double _exitBegin = 0.86;

  /// Chrome del sistema sobre el degradado de marca: la portada es siempre
  /// superficie oscura, así que letra y íconos de la barra van en claro.
  static const SystemUiOverlayStyle _chrome = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.primaryDark,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  /// Progreso de una ventana `[begin, end]` de la línea de tiempo, en reposo en
  /// 1 antes de abrir y después de cerrar.
  static double _win(
    double t,
    double begin,
    double end, [
    Curve curve = Motion.standard,
  ]) => curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final screen = MediaQuery.sizeOf(context);
    // El logo manda: 24 % del lado menor, acotado para que ni un reloj ni una
    // tablet lo estiren.
    final logoSize = (math.min(screen.width, screen.height) * 0.24).clamp(
      76.0,
      112.0,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      // La puerta ya decide no montar la portada con «reducir animaciones», así
      // que aquí la duración siempre es real: `Duration.zero` completaría la
      // animación dentro de `initState` y `onEnd` caería como un `setState`
      // durante el build del padre.
      duration: span,
      onEnd: onLifted,
      builder: (context, t, _) {
        final exit = _win(t, _exitBegin, 1.0, Curves.easeInCubic);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _chrome,
          child: Opacity(
            opacity: 1 - exit,
            child: Transform.scale(
              scale: 1 + 0.06 * exit,
              child: DecoratedBox(
                decoration: const BoxDecoration(gradient: urbanoGradient),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _RingsPainter(
                        draw: _win(t, _ringsBegin, _ringsEnd),
                        // Crucero constante: con una curva salida-antes la
                        // micro se salía del lienzo a mitad de la portada.
                        travel: _win(t, _busBegin, _busEnd, Curves.linear),
                      ),
                    ),
                    SafeArea(
                      // Un poco más arriba del centro: el tercio inferior es de
                      // los anillos y de la micro que los recorre.
                      child: Align(
                        alignment: const Alignment(0, -0.22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Badge(
                              size: logoSize,
                              ping: _win(t, _pingBegin, _pingEnd),
                            ),
                            const SizedBox(height: AppSpace.xl),
                            _Wordmark(
                              rise: _win(t, _typeBegin, _typeEnd),
                              style: text,
                            ),
                            const SizedBox(height: AppSpace.xl),
                            _Loader(fill: _win(t, _barBegin, _barEnd)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpace.lg,
                      right: AppSpace.lg,
                      bottom:
                          AppSpace.lg + MediaQuery.paddingOf(context).bottom,
                      child: Opacity(
                        opacity: _win(t, _footBegin, _footEnd),
                        child: Text(
                          'Santa Cruz de la Sierra · datos GTFS',
                          textAlign: TextAlign.center,
                          style: text.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontWeight: AppTypography.semiBold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Logo + sonar: un anillo que se expande una sola vez cuando la micro aterriza
/// (es el gesto de "llegó", no un pulso eterno).
class _Badge extends StatelessWidget {
  const _Badge({required this.size, required this.ping});

  final double size;

  /// 0..1 del anillo que sale.
  final double ping;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Transform.scale(
        scale: 0.78 + 1.5 * ping,
        child: Opacity(
          opacity: (1 - ping) * 0.55,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.4,
              ),
            ),
          ),
        ),
      ),
      UrbanoLogo(size: size),
    ],
  );
}

/// Nombre y bajada, que suben desde abajo con su propio `Reveal` de ventana.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.rise, required this.style});

  /// 0..1 de la entrada.
  final double rise;
  final TextTheme style;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(0, (1 - rise) * AppSpace.lg),
    child: Opacity(
      opacity: rise,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Env.appName.toUpperCase(),
            style: AppTypography.wordmark(
              style.displaySmall?.copyWith(
                color: Colors.white,
                letterSpacing: 3.2,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            Env.tagline,
            style: style.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Barra de arranque: una cápsula que se llena de coral hasta el borde mismo de
/// la portada (se completa justo cuando se levanta).
class _Loader extends StatelessWidget {
  const _Loader({required this.fill});

  /// 0..1 del relleno.
  final double fill;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    height: 4,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fill,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Los anillos de la ciudad trazándose desde la esquina inferior izquierda, con
/// una unidad que recorre su corredor y sale de pantalla.
///
/// Mismo lenguaje que la trama del header (los anillos pintados de la
/// cabecera del inicio) pero a escala pantalla y **sin bucle**: la portada vive
/// [_SplashCover.span], así que todo se resuelve en un solo paso y en reposo no
/// queda nada flotando.
class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.draw, required this.travel});

  /// 0..1 del trazado de los anillos.
  final double draw;

  /// 0..1 del recorrido de la unidad.
  final double travel;

  /// Origen medio fuera del lienzo: los arcos entran de lado a lado.
  static const Offset _origin = Offset(0.06, 1.04);

  /// Radios como fracción del lado mayor.
  static const List<double> _radii = [0.3, 0.44, 0.6, 0.78, 0.98];

  /// De «arriba del origen» (−90°) al borde derecho (0°): el cuadrante visible.
  static const double _fromAngle = -math.pi / 2;
  static const double _sweepAngle = math.pi / 2;

  /// El corredor por el que rueda la unidad: con radio 0.44 del lado mayor, el
  /// arco entra libre por el borde izquierdo y sale por la esquina inferior
  /// derecha justo al final de la línea de tiempo (nada queda flotando).
  static const int _lane = 1;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final side = size.longestSide;
    final center = Offset(size.width * _origin.dx, size.height * _origin.dy);
    // Grosores y puntos en proporción a la pantalla: la portada se ve igual de
    // bien en un teléfono compacto y en una tablet.
    final unit = side * 0.0035;

    // 1 · Avenidas radiales: trama apenas insinuada, para que el fondo se lea
    //    mapa y no degradado vacío.
    final avenues = Paint()
      ..color = Colors.white.withValues(alpha: 0.08 * draw)
      ..strokeWidth = unit * 0.45
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 5; i++) {
      final angle = _fromAngle + _sweepAngle * (0.08 + 0.22 * i);
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + dir * side * 0.2,
        center + dir * side * 1.15,
        avenues,
      );
    }

    // 2 · Anillos, de adentro hacia afuera, escalonados.
    for (var r = 0; r < _radii.length; r++) {
      final lap = ((draw - r * 0.11) / 0.6).clamp(0.0, 1.0);
      if (lap <= 0) continue;
      final swept = Motion.standard.transform(lap);
      final radius = _radii[r] * side;
      final isLane = r == _lane;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _fromAngle,
        _sweepAngle * swept,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: isLane ? 0.34 : 0.16)
          ..strokeWidth = isLane ? unit * 1.7 : unit
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );

      final stops = 3 + r;
      for (var s = 0; s <= stops; s++) {
        final at = s / stops;
        // El trazo todavía no llegó: la parada no existe aún.
        if (at > swept) break;
        final angle = _fromAngle + _sweepAngle * at;
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        final transfer = isLane && s.isEven;
        final dot = transfer ? unit * 2.1 : unit * 1.4;
        canvas.drawCircle(
          point,
          dot,
          Paint()
            ..color = Colors.white.withValues(alpha: transfer ? 0.55 : 0.3),
        );
        if (transfer) {
          // Transbordo: anillo hueco, como en un diagrama de metro.
          canvas.drawCircle(
            point,
            dot,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = unit * 0.5,
          );
        }
      }
    }

    // 3 · La unidad: arranca FUERA del lienzo (por arriba del borde izquierdo)
    //    y sale por la esquina inferior derecha, así que en t = 0 no hay nada
    //    dibujado y en reposo (travel = 1) no queda ninguna micro flotando.
    final laneRadius = _radii[_lane] * side;
    final angle = _fromAngle - 0.18 + (_sweepAngle + 0.36) * travel;
    final spot = center + Offset(math.cos(angle), math.sin(angle)) * laneRadius;

    for (var k = 7; k >= 1; k--) {
      // Estela: las muestras previas se adelgazan hacia atrás.
      final back = angle - k * 0.06;
      final trail =
          center + Offset(math.cos(back), math.sin(back)) * laneRadius;
      canvas.drawCircle(
        trail,
        unit * (1.7 - k * 0.18),
        Paint()..color = Colors.white.withValues(alpha: 0.34 * (1 - k / 8)),
      );
    }

    canvas.save();
    canvas.translate(spot.dx, spot.dy);
    // Tangente a la circunferencia: derivada de (cos θ, sin θ).
    canvas.rotate(math.atan2(math.cos(angle), -math.sin(angle)));
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: unit * 11,
        height: unit * 5.2,
      ),
      Radius.circular(unit * 1.8),
    );
    canvas.drawRRect(
      body,
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.7,
    );
    // Faro al frente.
    canvas.drawCircle(
      Offset(unit * 4.2, 0),
      unit * 0.9,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) =>
      oldDelegate.draw != draw || oldDelegate.travel != travel;
}
