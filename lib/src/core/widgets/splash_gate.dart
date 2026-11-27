import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../animation/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import '../utils/extensions.dart';
import 'urbano_logo.dart';

part 'splash_cover.dart';

/// La portada de la app es la misma en todas las plataformas y se pinta aquí
/// (`_RingsPainter`, `_Dial`, `_Loader`), sin ninguna librería de animación
/// Lottie: Android la repite en Kotlin con `SplashCanvasView` (Canvas puro)
/// antes de que Flutter arranque, y iOS muestra un PNG estático del mismo
/// frame 0 en `LaunchScreen.storyboard`. El texto «Cargando» y la barra no se
/// duplican en iOS porque el PNG se genera con el mismo arte (ver
/// `assets/brand/splash-frame0.svg` y `tools/make-ios-splash-frame0.sh`).

/// Etapa real del arranque, que es la que se lee bajo «Cargando».
enum BootStage {
  /// Detrás de la portada todavía no se montó la app.
  warming('Preparando la app'),

  /// La app ya corre; faltan los datos que el inicio va a mostrar.
  fetching('Buscando rutas'),

  /// Los datos respondieron mal o tardaron de más: se abre igual.
  offline('Sin respuesta del servicio'),

  /// Llegó todo: la portada está despidiéndose.
  done('Todo listo');

  const BootStage(this.label);

  /// Texto de la etapa.
  final String label;
}

/// Pantalla de carga de arranque: tapa la app mientras esta termina de montar
/// (el mapa y las ramas del shell) y mientras llegan los datos del inicio, y se
/// levanta sola cuando avisó que estaba lista.
///
/// Lo primero que se ve al abrir **es carga, no la marca**: girófono, etapa real
/// y barra. La identidad sigue puesta, pero de fondo —el degradado de la marca,
/// los anillos de Santa Cruz trazándose y el pie con la ciudad—, porque esa
/// pantalla existe para decir «esto está tardando un poco», no para presentar
/// Urbano. El nombre se ve dentro de la app (wordmark de la cabecera del
/// inicio).
///
/// No es un `Timer` ni una espera de red arbitraria: la línea de tiempo es un
/// `TweenAnimationBuilder` de **dos patas** (entrada hasta [_SplashCover.restT] y
/// salida de ahí a 1) y la cortina solo se levanta cuando se cumplen LAS DOS:
/// la entrada terminó **y** [SplashGate.ready] avisó. El orden importa:
///
///  * si el aviso llega en el frame 3, la portada no parpadea —cumple su piso y
///    recién entonces sale;
///  * si el aviso no llega nunca, el techo lo pone `bootCeiling` (el future de
///    arranque se resuelve solo), así que un backend caído no deja al usuario
///    encerrado detrás de una barra de carga.
///
/// El movimiento que dura lo que dure la espera (el giro del girófono, el barrido
/// de la barra, la micro que cruza los anillos) sale de UN solo [Ambient], no de
/// un controller por efecto.
///
/// Arranca en dos tiempos: el primer frame es SOLO portada y el hijo se monta en
/// el siguiente. Si fuera al revés, el frame que despide el splash nativo pagaría
/// todo el árbol (mapa incluido) y en pantalla quedaría el degradado verde
/// estático hasta que la app termine de armarse.
///
/// Con «reducir animaciones» la portada **no desaparece**: se pinta una sola vez
/// en su estado de reposo (anillos trazados, girófono y barra en su sitio) y se
/// levanta en cuanto [ready] avisa, sin mover un píxel. La portada dice «estoy
/// cargando», eso es información; lo que se quita con el ajuste del sistema es el
/// movimiento. Omitirla entera dejaba al usuario solo con el campo verde del
/// splash nativo, y en un Honor/Huawei con ahorro de energía encendido
/// `MediaQuery.disableAnimations` es `true` sin que nadie lo pida: era el caso
/// real.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child, this.ready});

  final Widget child;

  /// Señal de «la app ya tiene lo que hay que mostrar al abrir».
  ///
  /// Mientras no se resuelve, la portada se queda. El valor dice si el arranque
  /// pudo traer algo de datos: `true` levanta la cortina con la etapa
  /// [BootStage.done], `false` con [BootStage.offline] —porque una pantalla de
  /// carga que miente es peor que una que avisa, pero ninguna de las dos deja al
  /// usuario encerrado detrás.
  ///
  /// En `null` —el caso de los tests y de cualquier montaje que no tenga nada que
  /// esperar— la portada cumple solo su coreografía y se levanta sola.
  final Future<bool>? ready;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _covering = true;

  /// La app todavía no está en el árbol: primero pinta la portada, después se
  /// monta el hijo.
  bool _appStarted = false;
  bool _startScheduled = false;

  /// Las dos condiciones del levantado, por separado: `ready` puede llegar antes
  /// de que la entrada termine, y la entrada puede terminar antes de `ready`.
  bool _introDone = false;
  bool _ready = true;
  bool _failed = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _ready = widget.ready == null;
    // Una sola suscripción, y desde aquí: `provider.future` fabrica un future
    // distinto en cada rebuild del composition root, así que escucharlo en
    // `didUpdateWidget` re-armaría la cortina sobre el mismo dato. Vale el
    // primer aviso.
    widget.ready?.then(
      (arrived) => _arrive(failed: !arrived),
      onError: (Object _) => _arrive(failed: true),
    );
  }

  void _arrive({required bool failed}) {
    // El aviso puede llegar cuando la cortina ya se levantó (o cuando el árbol se
    // tiró en un test): no hay ningún `setState` que hacer.
    if (!mounted) return;
    setState(() {
      _ready = true;
      _failed = failed;
    });
    _maybeLift();
  }

  /// Fin de una pata de la línea de tiempo: la entrada o la salida.
  void _onLegEnd() {
    if (_exiting) {
      // Fuera del árbol al terminar: sin opacidad 0 ni ticker esperando, así que
      // ningún `pumpAndSettle` posterior ve la portada.
      setState(() => _covering = false);
      return;
    }
    setState(() => _introDone = true);
    _maybeLift();
  }

  /// La cortina sube con la entrada terminada **y** la app lista.
  ///
  /// El piso de tiempo lo pone la propia entrada (`_introSpan` de la portada): si
  /// [SplashGate.ready] llega en el frame 3 la cortina no parpadea, cumple su
  /// coreografía y recién entonces sale.
  void _maybeLift() {
    if (!shouldLiftCurtain(
      exiting: _exiting,
      introDone: _introDone,
      ready: _ready,
    )) {
      return;
    }
    setState(() => _exiting = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_startScheduled) {
      _startScheduled = true;
      // El primer frame de Flutter es el que despide el splash nativo. Si ahí
      // se construye `widget.child`, ese frame paga el mapa (plataforma nativa)
      // y las ramas del shell, y lo único que se ve durante esa pausa es el
      // campo verde de `launch_background.xml`: la pantalla de carga nunca llega
      // a pantalla. Se difiere el montaje un frame para que la portada quede
      // pintada primero; el mapa se sigue construyendo detrás de ella, que es
      // exactamente lo que esta puerta tapa. Se difiere SIEMPRE, también con
      // «reducir animaciones», porque la portada estática cumple la misma
      // función.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _appStarted = true);
      });
    }

    final mediaQuery =
        MediaQuery.maybeOf(context) ??
        MediaQueryData.fromView(View.of(context));
    final theme = Theme.of(context);
    final reduced = Motion.reduced(context);
    // La etapa no se inventa: sale de lo que el estado del arranque ya sabe.
    final stage = bootStageFor(
      exiting: _exiting,
      failed: _failed,
      appStarted: _appStarted,
    );

    return MediaQuery(
      data: mediaQuery,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: theme,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_appStarted) widget.child,
              // Fuera del árbol al terminar: sin opacidad 0 ni ticker esperando.
              if (_covering)
                Positioned.fill(
                  child: _SplashCover(
                    stage: stage,
                    exiting: _exiting,
                    reduced: reduced,
                    onLegEnd: _onLegEnd,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La cortina sube con la entrada terminada **y** la app lista (y una sola
/// vez: si ya está saliendo, no se re-arma).
bool shouldLiftCurtain({
  required bool exiting,
  required bool introDone,
  required bool ready,
}) => !exiting && introDone && ready;

/// Etapa que lee la portada. No se inventa: sale de lo que el arranque ya
/// sabe (montaje de la app, readiness y si falló).
BootStage bootStageFor({
  required bool exiting,
  required bool failed,
  required bool appStarted,
}) {
  if (exiting) return failed ? BootStage.offline : BootStage.done;
  return appStarted ? BootStage.fetching : BootStage.warming;
}
