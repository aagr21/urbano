import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/animation/motion.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/presentation/widgets/route_list_tile.dart';

/// Guardas del kit de motion.
///
/// No prueban gusto: bloquean las tres propiedades que hacen que el kit sea
/// usable bajo `flutter test`.
///  * que no deje Timers pendientes (la razón de no usar `flutter_animate`),
///  * que el escalonado exista de verdad (si `index` no retardara nada, todas
///    las filas entrarían a la vez y el efecto se vería muerto),
///  * que «reducir animaciones» apague el movimiento.
Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

/// Opacidad del `Reveal` que envuelve a [key].
///
/// Se busca el `Opacity` ANCESOR más cercano (`.first`, no `.last`: `.last`
/// devolvería el contenedor externo de la página y el número no tendría
/// relación con la fila).
double _opacityOf(WidgetTester tester, Key key) {
  final opacity = tester.widget<Opacity>(
    find.ancestor(of: find.byKey(key), matching: find.byType(Opacity)).first,
  );
  return opacity.opacity;
}

/// Child alcanzable por hit test.
///
/// Un `SizedBox` pelado NO entra en el `HitTestResult` (`RenderConstrainedBox`
/// no se auto-hit-testa), así que un `GestureDetector` con `deferToChild` detrás
/// de él nunca recibe el tap y el test daría `taps == 0` sin que el kit tenga
/// ninguna culpa. Un `ColoredBox` con color sí participa.
Widget _box({VoidCallback? onTap, Key? key}) => GestureDetector(
  key: key,
  onTap: onTap,
  child: const ColoredBox(
    color: Color(0xFF00FF00),
    child: SizedBox(width: 80, height: 80),
  ),
);

void main() {
  group('PressScale', () {
    testWidgets('hunde el child mientras el dedo está y lo suelta al irse', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PressScale(
            child: _box(onTap: () => taps++, key: const Key('caja')),
          ),
        ),
      );
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('caja'))),
      );
      await tester.pump(Motion.press);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        0.965,
      );

      await gesture.up();
      // El tap sigue llegando: `Listener` no se queda con el gesto (la arena
      // resuelve al asentar la animación de retorno).
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    });

    testWidgets('con «reducir animaciones» no se mueve', (tester) async {
      await tester.pumpWidget(
        _host(
          PressScale(child: _box(key: const Key('caja'))),
          reduceMotion: true,
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('caja'))),
      );
      await tester.pump(Motion.press);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('Reveal', () {
    testWidgets('entra de transparente a opaco y el index retrasa la fila', (
      tester,
    ) async {
      const firstKey = Key('first');
      const fifthKey = Key('fifth');
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              Reveal(child: SizedBox(key: firstKey, height: 10)),
              Reveal(index: 4, child: SizedBox(key: fifthKey, height: 10)),
            ],
          ),
        ),
      );
      // Primer frame: ninguna fila pintada todavía, pero ambas siguen
      // alcanzables por hit test — por eso los tests que tocan tras un `pump()`
      // simple no se rompen con esta animación.
      await tester.pump();
      expect(_opacityOf(tester, firstKey), 0);
      expect(_opacityOf(tester, fifthKey), 0);

      // A mitad de camino la primera ya casi entró y la quinta sigue esperando
      // su ventana: eso ES el escalonado.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_opacityOf(tester, firstKey), greaterThan(0.5));
      expect(_opacityOf(tester, fifthKey), 0);

      await tester.pumpAndSettle();
      expect(_opacityOf(tester, firstKey), 1);
      expect(_opacityOf(tester, fifthKey), 1);
    });

    testWidgets('con «reducir animaciones» muestra el child sin fundido', (
      tester,
    ) async {
      const bodyKey = Key('body');
      await tester.pumpWidget(
        _host(
          const Reveal(index: 3, child: SizedBox(key: bodyKey, height: 10)),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      expect(find.byKey(bodyKey), findsOneWidget);
      // Sin capa de `Opacity`: el contenido aparece tal cual.
      expect(
        find.ancestor(of: find.byKey(bodyKey), matching: find.byType(Opacity)),
        findsNothing,
      );
    });

    testWidgets('desmontarlo a media animación no deja timers pendientes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Reveal(index: 2, child: Text('hola', key: Key('txt')))),
      );
      await tester.pump();
      expect(find.text('hola'), findsOneWidget);
      // Este es el paso que revienta con `flutter_animate`: disposal con la
      // animación en vuelo. El kit usa un solo ticker, que se cancela aquí.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('CountUp', () {
    testWidgets('sube desde 0 hasta el valor final formateado', (tester) async {
      await tester.pumpWidget(_host(CountUp(value: 154, format: (v) => '$v')));
      await tester.pump();
      expect(find.text('0'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      final mid = int.parse(tester.widget<Text>(find.byType(Text)).data!);
      expect(mid, inInclusiveRange(1, 153));

      await tester.pumpAndSettle();
      expect(find.text('154'), findsOneWidget);
    });

    testWidgets('con «reducir animaciones» pinta el valor directo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(CountUp(value: 31461, format: (v) => '$v'), reduceMotion: true),
      );
      await tester.pump();
      expect(find.text('31461'), findsOneWidget);
    });
  });

  group('AppTheme.pageTransitionsTheme', () {
    test('Android conserva el atrás predictivo y el resto usa la nuestra', () {
      final builders = AppTheme.light().pageTransitionsTheme.builders;
      expect(
        builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
      );
      expect(builders[TargetPlatform.linux], isA<UrbanoPageTransitions>());
      expect(builders[TargetPlatform.iOS], isA<UrbanoPageTransitions>());
    });
  });

  group('Motion', () {
    test('los tokens de la casa caben en el presupuesto de la app', () {
      // El tope del escalonado evita que una fila 40 espere segundos.
      expect(Motion.maxStaggerIndex, 10);
      expect(Motion.reveal, const Duration(milliseconds: 360));
      expect(Motion.countUp.inMilliseconds, lessThanOrEqualTo(700));
    });
  });

  group('Hero del badge de ruta', () {
    // El badge vuela de la lista a la AppBar del detalle solo si la tag que
    // arma el tile coincide con la que arma la pantalla de detalle. Antes el
    // detalle traía siempre `routes`, así que el vuelo nunca ocurría.
    const route = RouteSummary(
      id: '75',
      shortName: '75',
      longName: '75 CORONEL',
      description: 'Linea 75',
      color: 'D35400',
      textColor: 'FFFFFF',
      type: 3,
      directionsCount: 2,
      stopCount: 20,
      tripCount: 2,
    );

    testWidgets('la fila de lista pone el prefijo en la tag del Hero', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const RouteListTile(route: route, heroPrefix: 'home')),
      );
      expect(tester.widget<Hero>(find.byType(Hero)).tag, 'route-badge-home-75');
    });

    test('el prefijo sobrevive el viaje por la URL hasta el detalle', () {
      final target = Uri.parse(UrbanoRoutes.routeDetail('75', from: 'home'));
      expect(target.queryParameters['from'], 'home');
      // `RouteDetailScreen` usa ese valor como `heroPrefix`, y la tag se arma
      // con la misma plantilla que el tile.
      expect(
        'route-badge-${target.queryParameters['from']}-75',
        'route-badge-home-75',
      );
    });
  });

  group('Movimiento ambiente', () {
    // El planeador usa `pumpAndSettle(timeout: 6 s)`. Un `repeat()` sin tope en
    // cualquier rama montada del shell (el home sigue vivo debajo) colgaría
    // esos tests, así que esta guarda es la que sostiene la regla de bucles
    // acotados.
    const settle = Duration(seconds: 6);

    double bobOffsetY(WidgetTester tester, Key key) {
      final transform = tester.widget<Transform>(
        find
            .ancestor(of: find.byKey(key), matching: find.byType(Transform))
            .first,
      );
      return transform.transform.getTranslation().y;
    }

    testWidgets('Bob se detiene solo: el árbol llega a SETTLED', (
      tester,
    ) async {
      const child = SizedBox(key: Key('bobbed'), width: 24, height: 24);
      await tester.pumpWidget(_host(const Bob(amplitude: 6, child: child)));
      await tester.pump(const Duration(milliseconds: 600));
      // A media vuelta el child ya está flotando (no es un reposo disfrazado
      // de animación).
      expect(bobOffsetY(tester, const Key('bobbed')), isNot(closeTo(0, 0.01)));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        settle,
      );
      // Reposo = vuelve exactamente a su sitio, así que ninguna medida de
      // layout posterior sale desplazada.
      expect(bobOffsetY(tester, const Key('bobbed')), closeTo(0, 0.01));
    });

    // La otra cara de la moneda: el tope es SOLO para los tests. En la app el
    // ambiente tiene que seguir moviéndose mucho después de `ambientCycles *
    // ambient` (4,8 s), que es lo que hace que la pantalla se vea viva.
    testWidgets(
      'en produccion el ambiente no se apaga nunca (bucle continuo)',
      (tester) async {
        // Sin este hook la rama de `repeat()` sería invisible: bajo `flutter test`
        // el entorno fuerza el modo acotado.
        Motion.debugAmbientLoopsForever = true;
        addTearDown(() => Motion.debugAmbientLoopsForever = null);

        const child = SizedBox(key: Key('bobbed'), width: 24, height: 24);
        await tester.pumpWidget(_host(const Bob(amplitude: 6, child: child)));
        // 5 s: ya pasaron con creces las 4,8 s en las que el modo acotado se
        // quedaría quieto. Dentro de la vuelta la fase cae en 0,083 → -3 px.
        await tester.pump(const Duration(seconds: 5));
        expect(
          bobOffsetY(tester, const Key('bobbed')),
          closeTo(-3, 0.2),
          reason: 'el bucle continuo debe seguir dentro de una vuelta, no en reposo',
        );

        // Y no está congelado: medio segundo después pinta otra fase.
        final before = bobOffsetY(tester, const Key('bobbed'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          bobOffsetY(tester, const Key('bobbed')),
          isNot(closeTo(before, 0.2)),
        );
      },
    );

    testWidgets('con «reducir animaciones» nace en reposo, sin ticker', (
      tester,
    ) async {
      const child = SizedBox(key: Key('bobbed'), width: 24, height: 24);
      await tester.pumpWidget(
        _host(const Bob(amplitude: 6, child: child), reduceMotion: true),
      );
      // Un solo `pump`: si quedara un ticker reproduceándose, el offset aún no
      // sería 0.
      await tester.pump();
      expect(bobOffsetY(tester, const Key('bobbed')), closeTo(0, 0.01));
    });

    testWidgets('el halo del LiveDot se apaga al terminar (no deja fantasma)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const LiveDot(color: Colors.red, size: 6)));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        settle,
      );
      final opacities = tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(LiveDot),
              matching: find.byType(Opacity),
            ),
          )
          .map((widget) => widget.opacity)
          .toList();
      expect(opacities, contains(0.0));
      // El núcleo sigue visible: lo que se apaga es el halo, no el dato.
      expect(find.byType(LiveDot), findsOneWidget);
    });
  });
}
