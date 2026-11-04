package com.example.urbano

import android.app.Application
import com.example.urbano.SplashActivity.Companion.prewarmComposition

/**
 * `Application` de Urbano. Sustituye al `android.app.Application` que Flutter
 * inyectaba por defecto (el placeholder `${applicationName}` de
 * `BaseApplicationNameHandler`), y lo hace POR UNA sola razón: arrancar el
 * parseo del Lottie de la splash en cuanto nace el proceso, un poco antes de que
 * [SplashActivity] exista.
 *
 * Por qué aquí y no en la Activity: en DEBUG la primera pasada de
 * `LottieCompositionFactory.fromAsset` cuesta ~2,5 s (ART verifica el dex de la
 * librería y el JIT está frío). Si ese coste se paga dentro de `onCreate`, el
 * usuario ve ~2,5 s de verde QUIETO antes de que empiece el giro — y verde
 * quieto es indistinguible de «no animaste nada», que es justo la queja.
 * Disparándolo aquí, el parseo corre en su propio hilo (ver
 * [prewarmComposition]) mientras el sistema todavía está inflando la primera
 * ventana, así que cuando [SplashActivity.loadComposition] llama a `fromAsset`
 * la composición ya está en la caché de Lottie y la animación arranca en el
 * primer frame.
 *
 * No toca nada del engine de Flutter: el warm-up del engine sigue viviendo en
 * [SplashActivity.warmFlutterEngine] a propósito, porque necesita el
 * `applicationContext` ya vivo pero NO debe competir con el parseo del JSON.
 * Aquí solo se encola el parseo; el engine se calienta después, en la Activity.
 */
class UrbanoSplashApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        prewarmComposition(this)
    }
}
