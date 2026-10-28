import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/runtime_flags.dart';

/// Kit de motion de la app.
///
/// Todo lo que vive aquí se construye con `AnimationController` y primitivas
/// implícitas (Tickers), **nunca con `flutter_animate` ni `Timer`**: bajo
/// `flutter test`, un `Timer` pendiente al destruir el árbol hace fallar el test
/// («A Timer is still pending») y `flutter_animate` monta uno de 0 ms justo al
/// empezar. Por eso el equipo anima con estas piezas, que además respetan el
/// ajuste del sistema «reducir animaciones» ([Motion.reduced]).
///
/// Tres gestos cubren casi toda la app:
///  * [PressScale] — feedback táctil: la tarjeta se hunde mientras el dedo está.
///  * [Reveal] — entrada con fundido y subida, escalonada por `index`.
///  * [CountUp] — un número que sube contando en vez de aparecer fijo.
///
/// Y una vez conectada en el tema: [UrbanoPageTransitions], para que un push no
/// sea un tijeretazo lateral.
///
/// Todos los textos pintados por el kit siguen la regla de contraste del equipo:
/// el kit mueve geometría y opacidad, nunca el color del contenido.
abstract final class Motion {
  Motion._();

  /// Pulso hacia abajo: casi instantáneo, para que se sienta «ya».
  static const Duration press = Duration(milliseconds: 110);

  /// Soltar: más lento que pulsar; el retorno suave es lo que se ve.
  static const Duration release = Duration(milliseconds: 240);

  static const Duration quick = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);

  /// Recorrido de una fila que entra ([Reveal]).
  static const Duration reveal = Duration(milliseconds: 360);

  /// Conteo de un número (stats): suficiente para verlo subir sin perderlo.
  /// Se deja por debajo del tiempo que los tests del home ya avanzan con
  /// `pump`, para no dejar un `find.text('154')` a media animación.
  static const Duration countUp = Duration(milliseconds: 700);

  /// Curva casa: sale rápido, frena suave.
  static const Curve standard = Curves.easeOutCubic;

  /// Para entradas: recorre casi todo el camino y se asienta. Menos nerviosa
  /// que `easeOutBack`, que en textos con relleno se ve rebotar de más.
  static const Curve entrance = Curves.easeOutQuint;

  /// Tope del escalonado: a partir de la fila 10 la diferencia ya no se lee,
  /// y una lista larga no debe tener contenido invisible segundos enteros.
  static const int maxStaggerIndex = 10;

  /// Periodo de un latido ambiente (micro que circula, halo que late).
  static const Duration ambient = Duration(milliseconds: 2400);

  /// Vueltas que da un ambiente **cuando debe detenerse**: solo bajo
  /// `flutter test` ([isRunningUnderTest]) y en los efectos con llegada (un
  /// riel que se traza una vez).
  ///
  /// El modo normal de [Ambient] es **bucle continuo** (`cycles: null`): la app
  /// tiene que verse moverse mientras está en pantalla, no quedarse congelada a
  /// los cinco segundos. El tope existe solo para los tests: un `repeat()` sin
  /// fin deja un ticker eterno y `pumpAndSettle` nunca llega a SETTLED — y en el
  /// `StatefulShellRoute.indexedStack` las ramas ocultas siguen montadas, así que
  /// el bucle de la otra pestaña consumiría el timeout de la pestaña probada.
  static const int ambientCycles = 2;

  /// Vueltas efectivas de un ambiente: las pedidas, o —si se pidió bucle
  /// continuo— el tope de tests. `null` significa «sin tope».
  static int? ambientCyclesFor(int? requested) {
    if (requested != null) return requested;
    final forever = debugAmbientLoopsForever ?? !isRunningUnderTest;
    return forever ? null : ambientCycles;
  }

  /// Fuerza el modo «bucle continuo» del ambiente dentro de un test.
  ///
  /// Bajo `flutter test` el runner exporta `FLUTTER_TEST` y [ambientCyclesFor]
  /// acota, así que la rama de producción (`repeat()`) sería invisible para los
  /// tests. Con `true` se ejercita esa rama; `null` (por defecto) es «decide el
  /// entorno». Restáuralo en `tearDown`.
  @visibleForTesting
  static bool? debugAmbientLoopsForever;

  /// ¿El usuario pidió menos movimiento? Se anulan entradas, rebotes y conteos.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Fase dentro de la vuelta que le toca a [t] cuando el ambiente da [cycles]
  /// vueltas: `0..1` dentro de cada una.
  ///
  /// Con [cycles] en `null` (bucle continuo) no hay progreso global que mapear:
  /// el propio valor del controller YA es la fase de la vuelta en curso, así que
  /// se devuelve tal cual. Por eso los builders de [Ambient] reciben la fase ya
  /// resuelta y nadie tiene que repetir a mano el número de vueltas.
  static double phase(double t, int? cycles) =>
      cycles == null ? t : (t * cycles) % 1.0;

  /// [length] en cero cuando el sistema pide reducir animaciones.
  static Duration duration(BuildContext context, Duration length) =>
      reduced(context) ? Duration.zero : length;
}

/// Hundido sutil de [child] mientras el dedo está sobre él.
///
/// Envuelve widgets que ya tienen su propio `onTap` (InkWell, Gesture Detector,
/// botones): usa [Listener], que no compite por los gestos, así que el tap
/// sigue llegando a quien tenía que llegar y ningún test cambia de
/// comportamiento.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.965,
    this.enabled = true,
  });

  final Widget child;

  /// Cuánto se encoge al pulsar (1.0 = nada).
  final double scale;

  /// Para desactivarlo en elementos que no se tocan o en listas enormes.
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value || !widget.enabled) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final pressed = _down && !Motion.reduced(context);
    return Listener(
      // Translucent: deja pasar el tap hacia el InkWell de dentro.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: pressed ? widget.scale : 1.0,
        // Bajar es inmediato; soltar se disfruta (la curva de retorno es la
        // que hace que el app se sienta física).
        duration: pressed ? Motion.press : Motion.release,
        curve: pressed ? Curves.easeOut : Motion.standard,
        child: widget.child,
      ),
    );
  }
}

/// Entrada con fundido y subida corta.
///
/// Cada [Reveal] dirige su propia animación desde que se monta, así que el
/// escalonado se logra con `index` (fila n) y `stagger` sin depender de un
/// padre que agrupe: sirve igual para las secciones del home, para una fila de
/// `SliverList` que entra al hacer scroll o para el contenido que reemplaza a un
/// skeleton. El retardo se implementa con un `Interval` dentro del mismo
/// ticker — no con `Future.delayed`, que dejaría un Timer pendiente en tests.
///
/// Si se necesita que algo vuelva a entrar con los mismos parámetros, basta con
/// cambiar su `Key` (forzar el remount), que es justo lo que pasa al volver del
/// modo búsqueda.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = Motion.reveal,
    this.stagger = const Duration(milliseconds: 80),
    this.slide = 14,
    this.slideX = 0,
    this.curve = Motion.entrance,
  });

  final Widget child;

  /// Orden de entrada: 0 es la primera fila en aparecer.
  final int index;

  /// Duración del recorrido de esta fila.
  final Duration duration;

  /// Retardo acumulado por fila.
  final Duration stagger;

  /// Cuántos píxeles sube al entrar.
  final double slide;

  /// Desplazamiento horizontal de entrada (para tiras que se leen en ese eje).
  final double slideX;
  final Curve curve;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _view;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final wait = widget.stagger * widget.index.clamp(0, Motion.maxStaggerIndex);
    final total = widget.duration + wait;
    _controller = AnimationController(vsync: this, duration: total);
    // `Duration / Duration` no existe: la fracción se saca en microsegundos.
    final begin = total.inMicroseconds == 0
        ? 0.0
        : wait.inMicroseconds / total.inMicroseconds;
    _view = CurvedAnimation(
      parent: _controller,
      // `Interval` ES un `Curve`: mapea el progreso del ticker a la ventana de
      // esta fila y aplica `curve` dentro de ella. Así el retardo sigue siendo
      // un solo ticker, sin `Future.delayed` (que dejaría un Timer pendiente).
      curve: Interval(
        begin.clamp(0.0, 1.0).toDouble(),
        1.0,
        curve: widget.curve,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Se arranca aquí y no en `initState`: preguntar por `MediaQuery` antes de
    // que `initState` termine está prohibido por el framework.
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
    if (Motion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _view,
      child: widget.child,
      builder: (context, inner) {
        final t = _view.value;
        // `Opacity` no bloquea los hit test (a diferencia de `Offstage`), así
        // que un test que toque después de un `pump()` sigue alcanzando la
        // fila aunque todavía esté transparente.
        return Transform.translate(
          offset: Offset((1 - t) * widget.slideX, (1 - t) * widget.slide),
          child: Opacity(opacity: t.clamp(0.0, 1.0).toDouble(), child: inner),
        );
      },
    );
  }
}

/// Número que aparece contando desde 0 hasta [value].
///
/// Se usa en stats: un dato que sube se lee como «esto está vivo y recién
/// calculado». La curva [Motion.entrance] concentra los últimos dígitos al
/// final, que es cuando el ojo ya puede leerlos.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = Motion.countUp,
    this.maxLines,
    this.overflow,
  });

  final int value;

  /// Cómo se pinta cada paso (`154` → `154`, `31461` → `31.461`).
  final String Function(int) format;
  final TextStyle? style;
  final Duration duration;

  /// Para que un número contando no desborde la píldora que lo contiene.
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      return _text(format(value));
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Motion.entrance,
      builder: (context, current, _) => _text(format(current)),
    );
  }

  Widget _text(String label) =>
      Text(label, style: style, maxLines: maxLines, overflow: overflow);
}

/// Motor de **movimiento ambiente**: un solo ticker que, por defecto, da vueltas
/// de `period` **sin parar** mientras el widget esté en pantalla. Con
/// `cycles:` finito son `period * cycles` y se detiene en 1 (reposo = «ya
/// terminó»). Lo cíclico se ve con la fase que entrega el builder.
///
/// Es la pieza que falta para que la app no parezca congelada cuando el usuario
/// no la toca: un micro que recorre los anillos del header, un halo que late
/// sobre un punto vivo, una barra de trabajo que sigue rodando.
///
/// Deliberadamente NO usa `AnimationController.repeat(count:)` en el modo
/// acotado: al agotar las vueltas ese método deja el valor de vuelta a `min`, y
/// un reposo en 0 borra el riel recién trazado y re-opaca el halo. Un
/// `forward()` sobre un ticker más largo da el mismo bucle con reposo garantizado
/// en 1.
///
/// El builder recibe dos números para que no haya que adivinar en qué modo se
/// está:
///  * `t` — progreso **global** (`0..1` de toda la animación). En bucle continuo
///    no existe un final, así que vale lo mismo que la fase.
///  * `phase` — fase dentro de la vuelta en curso (`0..1`), ya resuelta: sirve
///    para lo que pulsa, flota o rueda.
///
/// Regla: lo que debe desvanecerse al terminar (`1 - t`) usa `t`; lo que debe
/// repetirse usa `phase`.
///
/// Con «reducir animaciones» el controller se deja en 1: los hijos pintan su
/// estado final, no su estado inicial.
typedef AmbientBuilder = Widget Function(
  BuildContext context,
  double t,
  double phase,
  Widget? child,
);

class Ambient extends StatefulWidget {
  const Ambient({
    super.key,
    required this.builder,
    this.child,
    this.period = Motion.ambient,
    this.cycles,
  });

  /// Ve [AmbientBuilder].
  final AmbientBuilder builder;

  /// Subtree que no cambia entre frames: entregarlo aquí evita reconstruirlo en
  /// cada tick (importante cuando el `Ambient` envuelve una lista).
  final Widget? child;

  /// Duración de UNA vuelta.
  final Duration period;

  /// Vueltas antes del reposo. `null` (por defecto) = **bucle continuo** en la
  /// app; bajo `flutter test` se acota a [Motion.ambientCycles] para que
  /// `pumpAndSettle` converja. Pon un número explícito (`1`) en gestos de una
  /// sola vez, como una llegada o un riel que se traza.
  final int? cycles;

  @override
  State<Ambient> createState() => _AmbientState();
}

class _AmbientState extends State<Ambient> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Resuelto una sola vez: el builder y el controller tienen que ver el mismo
  /// modo (si se recalcula, fase y progreso global se desalinean).
  late final int? _cycles = Motion.ambientCyclesFor(widget.cycles);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.period * (_cycles ?? 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    final cycles = _cycles;
    if (cycles == null) {
      _controller.repeat();
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => widget.builder(
      context,
      _controller.value,
      Motion.phase(_controller.value, _cycles),
      child,
    ),
  );
}

/// Flotación suave: el [child] sube y baja `amplitude` píxeles en un ciclo
/// senoidal. Al cerrar cada vuelta vuelve exactamente a su sitio, así que
/// ninguna medida de layout queda desplazada después de la animación.
class Bob extends StatelessWidget {
  const Bob({
    super.key,
    required this.child,
    this.amplitude = 3,
    this.period = Motion.ambient,
    this.cycles,
  });

  final Widget child;
  final double amplitude;
  final Duration period;

  /// `null` = flota sin parar (lo normal); un número para que pare al terminar.
  final int? cycles;

  @override
  Widget build(BuildContext context) => Ambient(
    period: period,
    cycles: cycles,
    child: child,
    builder: (context, t, phase, inner) => Transform.translate(
      offset: Offset(0, -math.sin(phase * 2 * math.pi) * amplitude),
      child: inner,
    ),
  );
}

/// Punto vivo con halo que se expande y se apaga: «esto es dato de ahora».
///
/// El halo se dibuja con `Transform.scale` + `Opacity` sobre un `Border` circular
/// (sin `ShaderMask` ni blur: es barato y no re-rasteriza nada).
class LiveDot extends StatelessWidget {
  const LiveDot({
    super.key,
    required this.color,
    this.size = 8,
    this.period = const Duration(milliseconds: 1700),
    this.cycles,
  });

  final Color color;

  /// Diámetro del núcleo.
  final double size;
  final Duration period;

  /// `null` = el halo late sin parar (lo normal: «dato de ahora»); finito hace
  /// que el pulso se apague al entrar en reposo.
  final int? cycles;

  @override
  Widget build(BuildContext context) => Ambient(
    period: period,
    cycles: cycles,
    builder: (context, t, phase, _) => SizedBox(
      // El halo llega a ~2.6x el núcleo: se reserva su propio cuadro para que
      // el Stack no lo recorte.
      width: size * 3,
      height: size * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            // La expansión es la fase de la vuelta; el desvanecido sigue el
            // progreso global, así que con vueltas contadas el halo se apaga
            // para siempre al entrar en reposo (y con bucle continuo late).
            scale: 1 + 1.6 * phase,
            child: Opacity(opacity: (1 - t) * 0.5, child: _ring()),
          ),
          _ring(),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    ),
  );

  Widget _ring() => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1.6),
    ),
  );
}

/// Transición de página: la pantalla nueva **sube** entrando por la ventana
/// (fundido + desplazamiento corto + un pelín de zoom) en vez del deslizamiento
/// lateral de Material, que es lo que hace que un push se sienta brusco.
///
/// Se conecta en `AppTheme` vía `pageTransitionsTheme`, así que aplica a todos
/// los `MaterialPage` de go_router (detalle de ruta, Info) sin tocar los
/// `GoRoute`. Con «reducir animaciones» devuelve el child sin transitar.
class UrbanoPageTransitions extends PageTransitionsBuilder {
  const UrbanoPageTransitions();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 240);

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    if (context != null && Motion.reduced(context)) return child!;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.entrance,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.055),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.975, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
