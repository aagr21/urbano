package com.example.urbano

import android.app.Activity
import android.app.ActivityOptions
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.widget.FrameLayout
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Splash NATIVA del sistema operativo, en Kotlin puro con Canvas.
 *
 * Existe por una sola razón: el usuario quiere MOVIMIENTO durante la fase que
 * pinta el SO, antes de que Flutter exista. Esa fase no se puede animar desde
 * Dart —el proceso todavía no tiene engine—, ni desde `launch_background.xml`
 * (un `windowBackground` solo admite drawables estáticos), ni con la API 31+ de
 * `SplashScreen` (su `SplashScreenViewProvider` está pensado para el ícono, no
 * para una animación a pantalla completa). Lo que sí funciona es una `Activity`
 * propia, puesta como launcher, que dibuja su primer frame ya con la animación
 * corriendo.
 *
 * OJO con el theme: `SplashTheme` tiene que descender de
 * `@android:style/Theme.DeviceDefault.NoActionBar`. Si se cambia a
 * `Theme.AppCompat.*` el sistema deja de leer `android:windowSplashScreen*` y
 * vuelve a pintar SU pantalla con el ícono del launcher: el logo que el usuario
 * pidió borrar.
 *
 * Ya no usa Lottie: `SplashCanvasView` pinta todo con Canvas puro (degradado,
 * anillos de Santa Cruz, micro recorriéndolos, spinner coral, texto y barra de
 * progreso). Sin dependencia externa, sin parseo JSON, sin prewarm, sin riesgo
 * de crash por fuente faltante.
 *
 * ORDEN REAL DE LAS FASES (para no asustarse con el logcat ni con el ojo):
 *  1. Campo plano del SO: `windowSplashScreenBackground` en API 12+,
 *     `android:windowBackground` en API 11 para abajo. SIN animación: es el
 *     precio de que el proceso nazca. Nadie puede animar esta fase.
 *  2. Esta actividad: Canvas animado en su propio hilo (`SurfaceView`), 1,5 s
 *     en una sola pasada contados desde su primer frame.
 *  3. [MainActivity] → Flutter → `SplashGate`, la portada que espera los datos
 *     reales (`bootReadinessProvider`).
 *
 * COSTE HONESTO y cómo se paga: el engine de Flutter arranca EN PARALELO con la
 * animación (`warmFlutterEngine()`), así que el Canvas no le roba tiempo al
 * arranque: lo tapa. Sin eso se medía con `screenrecord` un campo verde SIN
 * movimiento de ~2,2 s entre el final de la animación y el primer frame de
 * Flutter, que es exactamente el «primero se ve solo verde» que este proyecto
 * ya rechazó.
 */
class SplashActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private var canvasView: SplashCanvasView? = null
    private var launched = false

    // Referencia de tiempo para medir CUÁNTO tarda en aparecer la animación.
    private var startedAt = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startedAt = SystemClock.uptimeMillis()

        // 0 = sin estilo de animación de ventana. Cualquier fundido o slide aquí
        // se leería como un corte entre dos pantallas del mismo verde.
        window.setWindowAnimations(0)
        drawEdgeToEdge()

        val root = FrameLayout(this)
        // Mismo color que el campo del SO y que el primer frame de la portada de
        // Dart: la continuidad es de COLOR, no de layout.
        root.setBackgroundColor(getColor(R.color.urbano_primary))

        // Vista Canvas a pantalla completa.
        val view = SplashCanvasView(this)
        root.addView(
            view,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        setContentView(root)

        view.setOnFinishedListener { goToFlutter("anim") }
        canvasView = view

        // Techo de carga: si la animación no termina (improbable con Canvas) la
        // app abre igual. Es GUARDIA, no reloj de la animación.
        handler.postDelayed(
            { goToFlutter("techo") },
            MAX_HOLD_MS,
        )

        // El engine se levanta en cuanto el primer frame está en pantalla: bloquea
        // el hilo principal ~0,8 s, pero la animación corre en el hilo de render
        // de la vista, así que se ve entera y fluida mientras tanto. Hacerlo antes
        // del primer frame retrasaba la splash hasta que no quedaba nada que ver.
        view.setOnFirstFrameListener { handler.post { warmFlutterEngine() } }
    }

    /**
     * Pinta bajo las barras del sistema, como hace Flutter con la portada de
     * Dart: el degradado cubre la pantalla entera y [SplashCanvasView] acomoda
     * el bloque de carga con los insets (su `SafeArea`). Sin esto, en API < 35 la
     * vista quedaba recortada entre las barras y todo el bloque saltaba unos dp
     * al entrar Flutter. Las barras copian el `_chrome` de `SplashGate`: estado
     * transparente y navegación `primaryDark`.
     */
    @Suppress("DEPRECATION")
    private fun drawEdgeToEdge() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        } else {
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        }
        // En API 35+ (edge-to-edge obligatorio) el sistema ignora estos colores.
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = getColor(R.color.urbano_primary_dark)
    }

    /**
     * Pre-calienta el engine de Flutter mientras la splash anima.
     *
     * Es la única manera de que animar el arranque no lo retrase. El coste de
     * levantar el runtime (cargar `libflutter.so`, extraer `kernel_blob.bin` en
     * debug, ejecutar `main()`, montar el árbol hasta que `SplashGate` se pinta)
     * se medía aquí en ~2,2 s DESPUÉS de `startActivity`; si se inicia en este
     * instante, esos 2,2 s ocurren de forma concurrente con los 1,5 s de la
     * animación y el usuario ve movimiento en vez de un campo verde sin mover.
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
            val t0 = SystemClock.uptimeMillis()
            val engine = FlutterEngine(applicationContext)
            GeneratedPluginRegistrant.registerWith(engine)
            // Antes de `main()`: Dart pregunta por enlaces entrantes al arrancar.
            IncomingLinks.attach(engine)
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
            Log.d(TAG, "engine pre-calentado en ${SystemClock.uptimeMillis() - t0} ms")
        } catch (error: Throwable) {
            // Sin pre-calentamiento el arranque es igual que antes de esta
            // actividad: más lento, pero correcto.
            Log.w(TAG, "no se pudo pre-calentar el engine; FlutterActivity creará el suyo", error)
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

    /**
     * Idempotente: animación, techo y atrás pueden solaparse, y un doble
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

        canvasView?.cancelAnimation()
        // `finish()` para que la splash NO quede en el back stack: atrás desde
        // la app tiene que salir de la app, no reabrir la animación.
        finish()
        Log.d(TAG, "splash -> flutter ($motivo)")
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        canvasView?.cancelAnimation()
        canvasView = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "UrbanoSplash"

        // La misma clave que lee `MainActivity.getCachedEngineId()`.
        const val ENGINE_ID = "urbano-splash-engine"

        // 1.5 s de animación + margen de primera pasada en gama baja.
        private const val MAX_HOLD_MS = 2600L
    }
}
