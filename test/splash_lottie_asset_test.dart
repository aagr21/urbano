import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

/// Guardias del Lottie de la splash NATIVA de Android (`assets/lottie/splash.json`).
///
/// El mismo archivo lo reproduce la splash nativa (`SplashActivity`, con
/// `com.airbnb.android:lottie`) y sirve de fuente al frame 0 estático del
/// `LaunchScreen` de iOS. No se monta dentro de Flutter (la portada de Dart se
/// pinta con `_RingsPainter`/`_Dial`/`_Loader` en todas las plataformas), así que
/// este test es la única red que decodifica el JSON de verdad: si no parsee, en
/// Android cae al guardia `sin-composicion` (arranque sin animación) y el PNG de
/// iOS sale mal.
void main() {
  // `ensureInitialized` fija el binding que el motor Dart de Lottie puede
  // necesitar al decodificar la composición.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('splash.json parsea con el motor Dart y trae el dial de carga', () async {
    // Se lee desde disco (la cwd de `flutter test` es la raíz del paquete) y no
    // por `rootBundle`: `assets/lottie/` ya NO se empaqueta en la app (la splash
    // real es el JSON copiado en `android/app/src/main/assets/` y el PNG estático
    // de iOS), así que esta guardia es la única que lo consume.
    final bytes = await File('assets/lottie/splash.json').readAsBytes();

    final composition = await LottieComposition.fromBytes(bytes);

    expect(
      composition,
      isNotNull,
      reason: 'el JSON debe parsear en el motor Dart',
    );
    // Lienzo 360x360: el mismo que asumen el CENTER_INSIDE de `SplashLottieView`,
    // el `scaleAspectFit` del storyboard y la constraint 0,40 de `_SplashCover`.
    expect(composition.bounds.width, 360);
    expect(composition.bounds.height, 360);
    // 45 fotogramas a 30 fps = 1,5 s, el tiempo que sostiene `SplashActivity`.
    expect(composition.durationFrames, closeTo(45, 0.5));
    expect(composition.frameRate, closeTo(30, 0.5));
    // El dial de carga enriquecido: pista + cabeza coral + estela aqua + texto
    // "Cargando" + barra + anillos de la ciudad (6 capas), ya no el autobús.
    expect(composition.layers.length, 6);
  });
}
