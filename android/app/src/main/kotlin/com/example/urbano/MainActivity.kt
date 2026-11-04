package com.example.urbano

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * Activity de Flutter. No es launcher: llega desde [SplashActivity] cuando el
 * Lottie termina.
 */
class MainActivity : FlutterActivity() {
    /**
     * Usa el engine que [SplashActivity] pre-calentó durante la animación, si es
     * que existe.
     *
     * Responder `null` cuando la clave no está en la caché es lo que hace seguro
     * este enganche: `flutter run`/`am start -n com.example.urbano/.MainActivity`
     * entran directamente aquí sin pasar por la splash, y sin ese filtro
     * `FlutterActivity` lanzaría
     * `IllegalStateException: Trying to build a FlutterActivity with a cached
     * engine ID that does not exist`. Con `null` se comporta como siempre: crea su
     * propio engine.
     *
     * Ojo con el efecto lateral: un engine cacheado NO lo destruye esta Activity
     * al terminarse (lo destruye el proceso), y los plugins ya quedaron
     * registrados en [SplashActivity.warmFlutterEngine] con
     * `GeneratedPluginRegistrant`.
     */
    override fun getCachedEngineId(): String? =
        if (FlutterEngineCache.getInstance().get(SplashActivity.ENGINE_ID) != null) {
            SplashActivity.ENGINE_ID
        } else {
            null
        }
}
