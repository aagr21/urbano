package com.example.urbano

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.app.Activity
import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.widget.FrameLayout
import com.airbnb.lottie.LottieCompositionFactory
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Splash NATIVA del sistema operativo, en Kotlin y con Lottie.
 *
 * Existe por una sola razón: el usuario quiere MOVIMIENTO durante la fase que
 * pinta el SO, antes de que Flutter exista. Esa fase no se puede animar desde
 * Dart —el proceso todavía no tiene engine—, ni desde `launch_background.xml`
 * (un `windowBackground` solo admite drawables estáticos), ni con la API 31+ de
 * `SplashScreen` (su `SplashScreenViewProvider` está pensado para el ícono, no
 * para una animación a pantalla completa). Lo que sí funciona es una `Activity`
 * propia, puesta como launcher, que dibuja su primer frame ya con el Lottie
 * corriendo.
 *
 * OJO con el theme: `SplashTheme` tiene que descender de
 * `@android:style/Theme.DeviceDefault.NoActionBar`. Si se cambia a
 * `Theme.AppCompat.*` (la tentación de rigor, porque `LottieAnimationView` lo
 * pide) el sistema deja de leer `android:windowSplashScreen*` y vuelve a pintar
 * SU pantalla con el ícono del launcher: el logo que el usuario pidió borrar.
 * Por eso el Lottie se pinta en [SplashLottieView] (un `View` pelado sobre
 * `LottieDrawable`) y no en `LottieAnimationView`.
 *
 * ORDEN REAL DE LAS FASES (para no asustarse con el logcat ni con el ojo):
 *  1. Campo plano del SO: `windowSplashScreenBackground` en API 12+,
 *     `android:windowBackground` en API 11 para abajo. SIN animación: es el
 *     precio de que el proceso nazca. Nadie puede animar esta fase.
 *  2. Esta actividad: el Lottie, 1.5 s en una sola pasada.
 *  3. [MainActivity] → Flutter → `SplashGate`, la portada que espera los datos
 *     reales (`bootReadinessProvider`). El Lottie no sabe nada de la red y no
 *     debe saber: esa separación es la que ya está documentada en AGENTS.md.
 *
 * COSTE HONESTO y cómo se paga: el engine de Flutter arranca EN PARALELO con la
 * animación (`warmFlutterEngine()`), así que el Lottie no le roba tiempo al
 * arranque: lo tapa. Sin eso se medía con `screenrecord` un campo verde SIN
 * movimiento de ~2,2 s entre el final del Lottie y el primer frame de Flutter (el
 * coste real de `startActivity` + cargar `libflutter.so` + `main()`), que es
 * exactamente el «primero se ve solo verde» que este proyecto ya rechazó. Ver
 * [warmFlutterEngine] y `MainActivity.getCachedEngineId`.
 *
 * El JSON vive en `assets/splash.json`. El origen es
 * `assets/lottie/splash.json` (el mismo que usa Dart en iOS) y la copia se
 * regenera con `tools/sync-splash-lottie.sh`, que lo deja MINIFICADO; editar la
 * copia a mano es perderse en el siguiente `sync`. Android no puede leer los
 * assets de Flutter antes de que Flutter exista. Es vectorial y TRANSPARENTE: el fondo lo
 * pone `urbano_primary` desde el theme, nunca el JSON, para que el handoff con
 * Flutter sea del mismo color y no parpadee.
 */
class SplashActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private var animationView: SplashLottieView? = null
    private var launched = false

    // Referencia de tiempo para medir CUÁNTO tarda en aparecer la animación: sin
    // este número, un arranque con el Lottie tardío y uno con el Lottie corto son
    // indistinguibles en el logcat.
    private var startedAt = 0L

    // `playing` separa los DOS techos posibles. Pre-calentar el engine cuesta CPU
    // justo cuando esta actividad necesita descomprimir y parsear el JSON: con un
    // solo `postDelayed` desde `onCreate` se medía un handoff `techo` con la
    // animación AÚN en curso (la micro cortada a medias). Con el reloj armado en
    // el arranque del animator, el techo solo salva lo que de verdad no arrancó.
    private var playing = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startedAt = SystemClock.uptimeMillis()

        // 0 = sin estilo de animación de ventana. Cualquier fundido o slide aquí
        // se leería como un corte entre dos pantallas del mismo verde, que es
        // exactamente el defecto que ya se midió con `screenrecord`.
        window.setWindowAnimations(0)

        val root = FrameLayout(this)
        // Mismo color que el campo del SO y que el primer frame de la portada de
        // Dart: la continuidad es de COLOR, no de layout.
        root.setBackgroundColor(getColor(R.color.urbano_primary))

        // Vista a pantalla completa: el escalado CENTER_INSIDE y la subida del
        // 11 % los decide `SplashLottieView.onDraw`, no un LayoutParams, para que
        // el centro del dibujo no dependa del alto visible de la ventana.
        val view = SplashLottieView(this)
        root.addView(
            view,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        setContentView(root)

        view.addAnimatorListener(
            object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) = goToFlutter("anim")
            },
        )
        animationView = view

        // Techo de carga: si la composición no llegó (JSON corrupto, asset que no
        // existe, executor atascado) la app abre igual. Es GUARDIA, no reloj de la
        // animación: si ya está sonando, quien manda es `onAnimationEnd`.
        handler.postDelayed(
            { if (!playing) goToFlutter("sin-composicion") },
            LOAD_GUARD_MS,
        )

        loadComposition(view)

        // DESPUÉS de despachar el JSON, no antes. El orden no es cosmético:
        // `FlutterEngine(...)` carga `libflutter.so` en el hilo principal y el
        // warm-up satura la CPU justo cuando el parser de Lottie necesita sus
        // ~100 ms. Midiendo con `screenrecord`, con el warm-up primero la animación
        // no aparecía hasta ~3 s después de `onCreate` (campo verde quieto y de
        // pronto el giro), que es exactamente el defecto que esta actividad existe
        // para curar. El parseo es barato y visible; el engine es caro e invisible:
        // se despacha primero lo barato.
        //
        // OJO: en DEBUG ese parseo cuesta ~2,5 s (verificación dex de la librería +
        // JIT), así que cubrirlo SOLO con este orden no alcanza: el arreglo real es
        // [prewarmComposition], que lo dispara desde el `Application` en un hilo
        // secundario y deja la composición en la caché de Lottie. Aquí entonces
        // `fromAsset` pega en caché y la animación arranca en el primer frame.
        warmFlutterEngine()
    }

    /**
     * Pre-calienta el engine de Flutter mientras la splash anima.
     *
     * Es la única manera de que animar el arranque no lo retrase. El coste de
     * levantar el runtime (cargar `libflutter.so`, extraer `kernel_blob.bin` en
     * debug, ejecutar `main()`, montar el árbol hasta que `SplashGate` se pinta)
     * se medía aquí en ~2,2 s DESPUÉS de `startActivity`; si se inicia en este
     * instante, esos 2,2 s ocurren de forma concurrente con los 1,5 s del Lottie y
     * el usuario ve movimiento en vez de un campo verde sin mover.
     *
     * Consecuencia que hay que saber: [MainActivity] recibe este engine por
     * `getCachedEngineId()`, y un engine cacheado NO registra plugins solo —de ahí
     * el `GeneratedPluginRegistrant.registerWith` explícito, sin el cual geolocator,
     * maplibre y shared_preferences simplemente no existirían en la app.
     *
     * El registro tiene que pasar ANTES de `executeDartEntrypoint` y no cuando
     * `FlutterActivity` se enganche: `main()` lee SharedPreferences en cuanto
     * arranca y sin canal ya montado eso es un `MissingPluginException`. El precio
     * es honesto y se ve en el logcat: al engancharse, el delegate vuelve a
     * registrar los 8 plugins y sueltan un
     * `W FlutterEngineCxnRegstry: Attempted to register plugin (…) but it was
     * already registered with this FlutterEngine` por cada uno. Es redundancia
     * inofensiva (mismo engine, mismos objetos), no un fallo.
     *
     * El `FlutterEngine` se crea con `applicationContext` a propósito: con `this`
     * la filtración del Activity sobrevivería al `finish()` (el engine vive hasta
     * que muere el proceso). Tampoco se destruye aquí: es el engine con el que la
     * app sigue corriendo, y `FlutterActivity` NO destruye un engine cacheado al
     * terminarse.
     *
     * Un fallo aquí NO puede tumbar el arranque: se captura todo y se deja que
     * [MainActivity] cree su propio engine como siempre (por eso
     * `getCachedEngineId()` responde `null` cuando la clave no está en la caché).
     */
    private fun warmFlutterEngine() {
        if (FlutterEngineCache.getInstance().get(ENGINE_ID) != null) return
        try {
            val engine = FlutterEngine(applicationContext)
            GeneratedPluginRegistrant.registerWith(engine)
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        } catch (error: Throwable) {
            // Sin pre-calentamiento el arranque es igual que antes de esta
            // actividad: más lento, pero correcto.
            Log.w(TAG, "no se pudo pre-calentar el engine; FlutterActivity creará el suyo", error)
        }
    }

    /**
     * Carga con `LottieCompositionFactory` en vez de `setAnimation("splash.json")`.
     *
     * Dos motivos reales. `setAnimation` delega el parseo y si el asset falta o
     * el JSON está mal el `AnimationView` se queda en blanco y `onAnimationEnd`
     * nunca llega (un `LottieDrawable` sin composición no anima): sin
     * `addFailureListener` eso sería una splash sorda de 2.6 s. Y la factory
     * deja la composición CACHEADA por clave, así que un segundo arranque no
     * vuelve a parsear los 6 KB.
     */
    private fun loadComposition(view: SplashLottieView) {
        LottieCompositionFactory.fromAsset(applicationContext, ASSET)
            .addListener { composition ->
                if (isFinishing || launched) return@addListener
                Log.d(TAG, "lottie compuesto en ${SystemClock.uptimeMillis() - startedAt} ms")
                view.setComposition(composition)
                playing = true
                // Techo de la pasada completa, contado desde aquí y no desde
                // `onCreate`: 1,5 s de animación + margen para un aparato lento.
                // La app abre IGUAL si el callback de fin se pierde; una pantalla
                // de carga no puede atrapar a nadie.
                handler.postDelayed({ goToFlutter("techo") }, MAX_HOLD_MS)
                view.playAnimation()
            }
            .addFailureListener { error ->
                // Sin animación y directo al frente: el arranque no puede fallar
                // por un adorno.
                Log.w(TAG, "lottie '$ASSET' no cargó; se abre sin animación", error)
                goToFlutter("fallo-lottie")
            }
    }

    /** Atrás durante la splash = entrar ya, no cerrar la app a medias. */
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            goToFlutter("atrás")
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    // `LottieDrawable` no observa la ventana por sí solo (eso lo hacía
    // `AnimationView`): sin este par, girar el teléfono o apagar la pantalla deja
    // el ticker animando contra una ventana que nadie ve.
    override fun onPause() {
        super.onPause()
        animationView?.pauseAnimation()
    }

    override fun onResume() {
        super.onResume()
        animationView?.resumeAnimation()
    }

    /**
     * Idempotente: animación, techo, fallo y atrás pueden solaparse, y un doble
     * `startActivity` dejaría dos FlutterActivity en la tarea.
     */
    private fun goToFlutter(motivo: String) {
        if (launched || isFinishing) return
        launched = true
        handler.removeCallbacksAndMessages(null)

        val intent = Intent(this, MainActivity::class.java)
        // `makeCustomAnimation(this, 0, 0)` = transición de duración cero. Es la
        // alternativa viva a `overridePendingTransition`, deprecada en API 34.
        val options = ActivityOptions.makeCustomAnimation(this, 0, 0)
        startActivity(intent, options.toBundle())

        animationView?.cancelAnimation()
        // `finish()` para que la splash NO quede en el back stack: atrás desde
        // la app tiene que salir de la app, no reabrir la animación.
        finish()
        Log.d(TAG, "splash -> flutter ($motivo)")
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        animationView?.cancelAnimation()
        animationView = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "UrbanoSplash"
        private const val ASSET = "splash.json"

        // La misma clave que lee `MainActivity.getCachedEngineId()`.
        const val ENGINE_ID = "urbano-splash-engine"

        // Margen para descomprimir + parsear el JSON con el engine recién cargando
        // el CPU. Si a los 1,4 s no hay composición, no la va a haber.
        private const val LOAD_GUARD_MS = 1400L

        // 1.5 s de animación + margen de primera pasada en gama baja.
        private const val MAX_HOLD_MS = 2600L

        /**
         * Deja la composición Lottie parseada y EN CACHÉ antes de que exista esta
         * actividad. Lo llama [UrbanoSplashApplication] desde su `onCreate`.
         *
         * Por qué hace falta: `LottieCompositionFactory.fromAsset` corre en un
         * executor y en DEBUG su primera pasada cuesta ~2,5 s (ART verifica el dex
         * de la librería y el JIT todavía no existe); medido con `screenrecord`,
         * eso son dos segundos y medio de verde QUIETO antes de que empiece el
         * giro, y verde quieto es indistinguible de «no animaste nada». En release
         * el mismo parseo cuesta ~315 ms.
         *
         * Se dispara en un HILO PROPIO y desde el `Application`, no desde
         * `onCreate` de la Activity: así compite lo menos posible con la inflación
         * de la primera ventana y el resultado queda cacheado por clave
         * (`LottieCompositionFactory` cachea por el nombre del asset), de modo que
         * el `fromAsset` de [loadComposition] responde al instante.
         *
         * Si falla no pasa nada visible: [loadComposition] vuelve a intentar y, si
         * tampoco ahí hay composición, entra el guardia `sin-composicion`.
         */
        fun prewarmComposition(base: Context) {
            Thread(
                {
                    val started = SystemClock.uptimeMillis()
                    LottieCompositionFactory.fromAsset(base.applicationContext, ASSET)
                        .addListener {
                            Log.d(TAG, "prewarm: lottie compuesto en ${SystemClock.uptimeMillis() - started} ms")
                        }
                        .addFailureListener { error ->
                            Log.w(TAG, "prewarm: el parseo anticipado falló; la Activity reintentará", error)
                        }
                },
                "urbano-splash-prewarm",
            ).start()
        }
    }
}
