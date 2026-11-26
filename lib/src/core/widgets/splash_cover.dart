part of 'splash_gate.dart';

/// La pantalla de carga en sí: TODAS las ventanas salen de un solo
/// `TweenAnimationBuilder` con dos patas —entrada (hasta [restT]) y salida (de
/// [restT] a 1)—, y lo que se mueve mientras la app tarda lo mueve un único
/// [Ambient] (el del girófono, el de la barra y el de la micro sobre los
/// anillos), para que no haya un controller por efecto.
class _SplashCover extends StatelessWidget {
  const _SplashCover({
    required this.stage,
    required this.exiting,
    required this.reduced,
    required this.onLegEnd,
  });

  /// Etapa que se lee bajo «Cargando».
  final BootStage stage;

  /// `true` en cuanto la entrada terminó y la app avisó: la pata que viene es la
  /// salida, y su fin es el levantado de la cortina.
  final bool exiting;

  /// «Reducir animaciones» del sistema: se ignora el valor animado y se pinta
  /// [restT] congelado (la cortina se levanta igual, con su reloj).
  final bool reduced;

  /// Se llama al terminar el último frame de cada pata.
  final VoidCallback onLegEnd;

  /// Una vuelta del ambiente: lo que tarda el girófono en dar la vuelta —y la
  /// micro en cruzar los anillos, porque comparten reloj.
  static const Duration _lap = Duration(milliseconds: 1400);

  /// Duración de la pata de salida.
  static const Duration _outSpan = Motion.transition;

  /// Piso de la portada: lo que tarda la entrada en pintarse. Nunca es tiempo de
  /// espera añadido a la red —la red trabaja desde el frame 1, detrás de la
  /// cortina—, es el mínimo para que la pantalla de carga no sea un parpadeo.
  static const Duration _introSpan = Duration(milliseconds: 900);

  /// La portada **entra ya pintada**: la línea de tiempo arranca en [_startT]
  /// y no en 0.
  ///
  /// Antes de que Flutter pueda dibujar hay ~0.7 s de portada nativa (el SO la
  /// mantiene hasta el primer frame) y su fondo es la misma laguna del degradado.
  /// Si los primeros 300 ms de la coreografía fueran campo vacío —letra en
  /// opacidad 0, barra sin rellenar, anillos sin trazar— el ojo no registra
  /// ningún corte y sigue viendo «solo verde». Empezando en [_startT], el frame
  /// 1 ya trae girófono, «Cargando», etapa y barra en curso: lo primero que se ve
  /// es la carga.
  static const double _startT = 0.14;

  /// Meseta de la línea de tiempo: donde la entrada termina y empieza la espera.
  /// De aquí a 1 no hay nada más que la salida, así que [stage] y el reposo
  /// pintado son siempre coherentes.
  static const double restT = 0.62;

  // Ventanas, en fracción del total. Las de texto cierran muy pronto para que el
  // frame 1 ya sea legible; lo que se toma su tiempo son los anillos y la barra.
  static const double _blockBegin = 0;
  static const double _blockEnd = 0.26;
  static const double _barBegin = 0.02;
  static const double _footBegin = 0.02;
  static const double _footEnd = 0.14;

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
    final screen = MediaQuery.sizeOf(context);
    // Girófono: la mitad del logo que había antes. Es la pieza que dice
    // «cargando», pero no es el protagonista de la pantalla ni de la marca.
    final dial = (math.min(screen.width, screen.height) * 0.15).clamp(
      58.0,
      84.0,
    );

    return TweenAnimationBuilder<double>(
      // Dos patas sobre el mismo ticker: cambiar `end` (de la meseta a 1) rearma
      // el tween desde el valor actual, así la salida no salta.
      //
      // El `begin` NO se cambia nunca con «reducir animaciones»: si `begin == end`
      // el `TweenAnimationBuilder` ni arranca, no dispara `onEnd` y la cortina se
      // queda montada para siempre. En modo reducido lo que se congela es lo
      // PINTADO (`t` se fija en [restT] abajo), no el reloj —y el reloj es
      // justamente la única manera que tiene la portada de saber que terminó.
      tween: Tween<double>(begin: _startT, end: exiting ? 1.0 : restT),
      // Con «reducir animaciones» la portada no se mueve: solo corre el reloj que
      // la levanta. `Duration.zero` completaría la animación dentro de
      // `initState` y `onEnd` caería como un `setState` durante el build del
      // padre, así que la duración siempre es real.
      duration: exiting ? _outSpan : (reduced ? Motion.settle : _introSpan),
      onEnd: onLegEnd,
      builder: (context, value, _) {
        // En modo reducido el valor animado se ignora: `t` no cambia jamás, así
        // que ni el girófono, ni el barrido, ni los anillos se mueven.
        final double t = reduced ? restT : value;
        final double exit = _win(t, restT, 1.0, Curves.easeInCubic);
        final double block = _win(t, _blockBegin, _blockEnd);
        final double rings = _win(t, _blockBegin, restT);
        final double foot = _win(t, _footBegin, _footEnd);
        // Media barra mientras se espera (la espera es indeterminada: nadie sabe
        // cuánto falta) y la otra media cuando la carga efectivamente terminó.
        final double fill =
            0.5 * _win(t, _barBegin, restT, Curves.linear) +
            0.5 * _win(t, restT, 1.0);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _chrome,
          child: Opacity(
            opacity: 1 - exit,
            child: Transform.scale(
              scale: 1 + 0.06 * exit,
              child: DecoratedBox(
                decoration: const BoxDecoration(gradient: urbanoGradient),
                child: Ambient(
                  period: _lap,
                  // Un solo reloj para todo lo que espera: `spin` gira el
                  // girófono, barre la barra y lleva la micro por su anillo.
                  builder: (context, _, spin, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      // Los anillos de la ciudad trazándose: el fondo de marca.
                      // Se pintan en TODAS las plataformas; el JSON horneado solo
                      // vive en la fase nativa anterior a Flutter.
                      CustomPaint(
                        painter: _RingsPainter(draw: rings, travel: spin),
                      ),
                      SafeArea(
                        // Un poco más arriba del centro: el tercio inferior es de
                        // los anillos y de la micro que los recorre.
                        child: Align(
                          alignment: const Alignment(0, -0.22),
                          child: _LoadingBlock(
                            stage: stage,
                            rise: block,
                            spin: spin,
                            fill: fill,
                            exit: exit,
                            leader: _Dial(size: dial, turn: spin),
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpace.lg,
                        right: AppSpace.lg,
                        bottom:
                            AppSpace.lg + MediaQuery.paddingOf(context).bottom,
                        child: Opacity(
                          opacity: foot,
                          child: Text(
                            'Santa Cruz de la Sierra · datos GTFS',
                            textAlign: TextAlign.center,
                            style: context.text.labelSmall?.copyWith(
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
          ),
        );
      },
    );
  }
}

/// Bloque de carga: girófono, «Cargando», la etapa real y la barra.
class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({
    required this.stage,
    required this.rise,
    required this.spin,
    required this.fill,
    required this.exit,
    required this.leader,
  });

  final BootStage stage;

  /// 0..1 de la entrada del bloque (opacidad + subida corta).
  final double rise;

  /// Fase del ambiente en curso (`0..1` de la vuelta): gira el girófono y barre
  /// la barra con un solo reloj.
  final double spin;

  /// 0..1 del relleno de la barra.
  final double fill;

  /// 0..1 de la salida: apaga el barrido para que la barra llena se lea limpia.
  final double exit;

  /// La pieza que dice «esto se está moviendo»: el girófono pintado (`_Dial`),
  /// igual en todas las plataformas. Es un `Widget` y no un `bool` para que el
  /// tamaño y el reloj se decidan fuera, en la portada.
  final Widget leader;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        leader,
        const SizedBox(height: AppSpace.xxl),
        Transform.translate(
          offset: Offset(0, (1 - rise) * AppSpace.md),
          child: Opacity(
            opacity: rise,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cargando',
                  style: text.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: AppTypography.semiBold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  stage.label,
                  // La etapa es la que cambia con el arranque real: su key fija
                  // permite medirla en los tests sin adivinar por el estilo.
                  key: const ValueKey('splash-stage'),
                  style: text.titleSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
        _Loader(fill: fill, sweep: spin, sweepFade: 1 - exit),
      ],
    );
  }
}

/// Girófono de carga: un arco de coral dando vueltas sobre una pista tenue.
///
/// A propósito NO es un `CircularProgressIndicator`: ese trae su propio ticker
/// eterno y `pumpAndSettle` no converge con él montado (y un spinner clavado en
/// reposo no sirve). Aquí el giro lo presta el [Ambient] de la portada y el
/// pintor es `const`, así que cada frame cuesta una rotación de matriz y nada de
/// re-pintado.
class _Dial extends StatelessWidget {
  const _Dial({required this.size, required this.turn});

  final double size;

  /// 0..1 de la vuelta en curso.
  final double turn;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: turn * 2 * math.pi,
    child: CustomPaint(size: Size.square(size), painter: const _DialPainter()),
  );
}

class _DialPainter extends CustomPainter {
  const _DialPainter();

  /// Barrido del arco principal (coral): un poco menos de media vuelta, para que
  /// la punta y la cola se distingan.
  static const double _headSweep = math.pi * 1.15;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.085;
    final ring = Rect.fromLTWH(
      stroke,
      stroke,
      size.width - 2 * stroke,
      size.height - 2 * stroke,
    );

    // Pista: el círculo completo, apenas insinuado.
    canvas.drawArc(
      ring,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(ring, 0, _headSweep, false, arc..color = AppColors.accent);
    // Rastro aqua, más corto y tenue: el giro se lee incluso congelado (bajo
    // «reducir animaciones» el girófono no gira, pero sigue diciendo «carga»).
    canvas.drawArc(
      ring,
      _headSweep,
      math.pi * 0.32,
      false,
      arc..color = AppColors.aqua.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) => false;
}

/// Barra de arranque: una cápsula que se llena al levantarse la cortina, con un
/// tramo claro barriendo de izquierda a derecha mientras la espera dura.
class _Loader extends StatelessWidget {
  const _Loader({
    required this.fill,
    required this.sweep,
    required this.sweepFade,
  });

  /// 0..1 del relleno de coral.
  final double fill;

  /// Fase del ambiente: de dónde sale y a dónde entra el barrido.
  final double sweep;

  /// 0 = barrido apagado (la salida ya empezó: la barra se llena sola).
  final double sweepFade;

  /// Ancho del tramo que barre, en fracción de la barra.
  static const double _glider = 0.34;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    height: 4,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              // La barra es la única prueba de progreso que leen los tests: su
              // key la separa del barrido (otro `FractionallySizedBox`).
              key: const ValueKey('splash-loader-fill'),
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
          if (sweepFade > 0)
            Align(
              alignment: Alignment(-1 + 2 * sweep, 0),
              child: FractionallySizedBox(
                widthFactor: _glider,
                heightFactor: 1,
                child: Opacity(
                  opacity: sweepFade,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white70,
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Los anillos de la ciudad trazándose desde la esquina inferior izquierda, con
/// una unidad que recorre su corredor y sale de pantalla.
///
/// Mismo lenguaje que la trama del header (los anillos pintados de la
/// cabecera del inicio) pero a escala pantalla. El trazado (`draw`) es de una
/// sola vez —es la portada presentando el mapa de la ciudad—, mientras que la
/// unidad (`travel`) rueda **en bucle** mientras la carga dura: el [Ambient] de
/// la portada le presta su fase, así que no hay un segundo ticker ni un reloj
/// paralelo. Como el corredor entra y sale por fuera del lienzo, al empezar y al
/// terminar cada vuelta no queda ninguna micro flotando.
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
  /// derecha, así que en los extremos de la vuelta no hay nada dibujado.
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
    //    y sale por la esquina inferior derecha, así que en los extremos de la
    //    vuelta no hay nada dibujado y nunca queda una micro flotando.
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
