import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/widgets/splash_gate.dart';
import 'package:urbano/src/core/widgets/urbano_logo.dart';

/// La pantalla de carga de arranque: tapa la app, dice qué está cargando, se
/// queda hasta que la app avisa que está lista y no deja nada montado ni ticking
/// después.
void main() {
  Widget host(Widget child, {bool reduced = false}) => MediaQuery(
    // `disableAnimations` es el mismo interruptor que lee `Motion.reduced`.
    data: MediaQueryData(disableAnimations: reduced),
    child: MaterialApp(home: child),
  );

  Future<void> pumpCover(
    WidgetTester tester, {
    bool reduced = false,
    Future<bool>? ready,
  }) => tester.pumpWidget(
    host(
      SplashGate(
        ready: ready,
        child: const Center(child: Text('app debajo')),
      ),
      reduced: reduced,
    ),
  );

  /// Opacidad **pintada** de un texto: un `Text` bajo `Opacity(0)` se sigue
  /// encontrando con `find.text`, y un primer frame con la letra invisible es
  /// indistinguible de la portada nativa (el «solo verde» que reportó el
  /// usuario). Se mide el `Opacity` más interno del texto.
  double paintedOpacity(WidgetTester tester, String label) => tester
      .widget<Opacity>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Opacity))
            .last,
      )
      .opacity;

  /// 0..1 del relleno de la barra (la key la separa del tramo que barre).
  double barraRellena(WidgetTester tester) => tester
      .widget<FractionallySizedBox>(
        find.byKey(const ValueKey('splash-loader-fill')),
      )
      .widthFactor!;

  testWidgets('lo primero que se ve es carga, no la marca', (tester) async {
    await pumpCover(tester);

    // La portada existe y tapa la app: el primer frame es SOLO portada. Montar
    // el hijo ahí obligaría a pagar en ese mismo frame el mapa y las ramas del
    // shell, y el splash nativo (un campo verde sin animación) seguiría visible
    // todo ese tiempo.
    expect(find.text('Cargando'), findsOneWidget);
    expect(find.text('app debajo'), findsNothing);

    // Y no es el show de la marca: ni el logo animado ni el wordmark que abrían
    // la app. La identidad queda en el degradado, los anillos y el pie.
    expect(find.byType(UrbanoLogo), findsNothing);
    expect(find.text('URBANO'), findsNothing);
    expect(find.text('Muévete por Santa Cruz'), findsNothing);

    // Nada de `CircularProgressIndicator`: el spinner de Material trae su propio
    // ticker eterno y `pumpAndSettle` no converge con él montado. El giro lo
    // presta el `Ambient` de la portada.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // En el frame siguiente la app ya está montada, tapada por la portada.
    await tester.pump();
    expect(find.text('app debajo'), findsOneWidget);
    expect(find.text('Cargando'), findsOneWidget);
  });

  testWidgets('su primer frame ya trae la carga legible', (tester) async {
    await pumpCover(tester);

    expect(paintedOpacity(tester, 'Cargando'), greaterThan(0.9));
    // La etapa también: «Preparando la app» es lo que hay que leer mientras ni
    // siquiera la app está en el árbol.
    expect(paintedOpacity(tester, 'Preparando la app'), greaterThan(0.9));
    expect(
      paintedOpacity(tester, 'Santa Cruz de la Sierra · datos GTFS'),
      greaterThan(0.9),
    );
    // Y la barra ya empezó a rellenarse: hay progreso visible en el frame 1.
    expect(barraRellena(tester), greaterThan(0));
  });

  testWidgets('la etapa cuenta el arranque real', (tester) async {
    final completer = Completer<bool>();
    await pumpCover(tester, ready: completer.future);
    await tester.pump();

    // La app ya está montada detrás y faltan sus datos: eso es lo que se lee.
    expect(find.text('Buscando rutas'), findsOneWidget);

    // Con la entrada terminada pero sin aviso, la etapa sigue en carga.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Buscando rutas'), findsOneWidget);
    completer.complete(true);

    // Dos `pump`: el callback del future corre en el `flushMicrotasks` que el
    // runner hace DESPUÉS del frame, así que el `setState` del aviso pinta hasta
    // el frame siguiente.
    await tester.pump();
    await tester.pump();
    expect(find.text('Todo listo'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('se levanta sola al terminar su línea de tiempo', (tester) async {
    // Sin señal externa (`ready == null`) no hay nada que esperar: la portada
    // cumple su coreografía y se va.
    await pumpCover(tester);
    await tester.pump();

    // A media entrada sigue tapando.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Cargando'), findsOneWidget);

    // Pasada la entrada (900 ms) y la salida (320 ms) la portada ya no está en
    // el árbol: ni opacidad 0 ni ticker esperando.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.text('Cargando'), findsNothing);
    expect(find.byType(SplashGate), findsOneWidget);
    expect(find.text('app debajo'), findsOneWidget);
  });

  testWidgets('la cortina espera el aviso, no el reloj', (tester) async {
    final completer = Completer<bool>();
    await pumpCover(tester, ready: completer.future);
    await tester.pump();

    // Entrada terminada: la portada se queda porque nadie avisó. Un fondo lento
    // no puede abrir la app a medias ni un parpadeo.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Cargando'), findsOneWidget);

    // Y espera todo lo que haga falta (el techo real lo pone `bootCeiling` en el
    // future de arranque, no este widget).
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Cargando'), findsOneWidget);

    // El aviso llega: primero la pata de salida, después fuera del árbol.
    // `pumpAndSettle` y no un `pump(400ms)` suelto: el tween se rearma cuando
    // cambia `end`, y el primer tick de ese rearme vale 0 —levantar la cortina
    // cuesta más de un frame.
    completer.complete(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Cargando'), findsOneWidget);
    expect(find.text('Todo listo'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Cargando'), findsNothing);
    expect(find.text('app debajo'), findsOneWidget);
  });

  testWidgets('un aviso sin datos también levanta la cortina', (tester) async {
    await pumpCover(tester, ready: Future.value(false));
    await tester.pump();

    // Backend caído: se abre igual, pero la portada lo dice en vez de fingir que
    // terminó bien.
    await tester.pump(const Duration(milliseconds: 950));
    expect(find.text('Sin respuesta del servicio'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Cargando'), findsNothing);
    expect(find.text('app debajo'), findsOneWidget);
  });

  testWidgets('con «reducir animaciones» la portada se pinta congelada', (
    tester,
  ) async {
    await pumpCover(tester, reduced: true);

    // El ajuste del sistema quita MOVIMIENTO, no la pantalla de carga: sin
    // portada el usuario se queda solo con el campo verde del splash nativo.
    // En un Honor/Huawei con ahorro de energía `disableAnimations` viene dado,
    // así que omitirla era «no aparece la carga» sin que nadie lo pidiera.
    expect(find.text('Cargando'), findsOneWidget);
    expect(find.text('app debajo'), findsNothing);

    // Estado de reposo: la barra en su media barra de espera (la espera es
    // indeterminada), no a medias de una animación.
    expect(barraRellena(tester), closeTo(0.5, 0.01));

    await tester.pump();
    expect(find.text('app debajo'), findsOneWidget);

    // Congelada: pasa el tiempo y la escena no cambia un píxel.
    final rellenoInicial = barraRellena(tester);
    await tester.pump(const Duration(milliseconds: 120));
    expect(barraRellena(tester), rellenoInicial);

    // Y se levanta sola tras su hold corto, sin fundido ni ticker abierto.
    await tester.pumpAndSettle();
    expect(find.text('Cargando'), findsNothing);
    expect(find.text('app debajo'), findsOneWidget);
  });
}
