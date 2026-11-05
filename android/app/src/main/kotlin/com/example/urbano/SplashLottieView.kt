package com.example.urbano

import android.content.Context
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.util.Log
import android.view.View
import com.airbnb.lottie.FontAssetDelegate
import com.airbnb.lottie.LottieComposition
import com.airbnb.lottie.LottieDrawable
import kotlin.math.min

/**
 * La vista que pinta el Lottie de la [SplashActivity].
 *
 * NO es un `LottieAnimationView`, y esa es exactamente la razón de existir de
 * esta clase de cuarenta líneas. `LottieAnimationView` hereda de
 * `AppCompatImageView` y exige que el theme de la Activity descienda de
 * `Theme.AppCompat`; la solución obvia —ponerle ese parent a `SplashTheme`—
 * resulta ser una trampa: los atributos `android:windowSplashScreen*` de API 12+
 * solo los lee el sistema si el theme desciende de `Theme.DeviceDefault`, así
 * que con AppCompat el bloque se ignora y Android VUELVE A PINTAR SU PANTALLA
 * PROPIA CON EL ÍCONO DEL LAUNCHER. Eso es «se ve el logo al arrancar», el
 * defecto que esta pantalla existe para curar.
 *
 * `LottieDrawable` es la otra mitad pública de la librería: hace todo el trabajo
 * real (parseo ya resuelto por `LottieCompositionFactory`, timing, invalidación)
 * y no mira el theme ni por asomo. Aquí se monta sobre un `View` pelado, se le
 * pasa la propia vista como `Callback` (así el drawable programa sus frames con
 * `postOnAnimation` en lugar de un `Handler` propio) y se escala con una
 * [Matrix] en el `onDraw`.
 *
 * El lienzo del JSON es cuadrado (360x360) y la pantalla no, así que se dibuja
 * CENTER_INSIDE: el lado es el mínimo de ancho/alto y va subido un 11 % para
 * caer donde vive la portada de Dart.
 */
class SplashLottieView(context: Context) : View(context), Drawable.Callback {

    init {
        // TRAMPA mortal de `View`: una vista sin fondo (no pone `setWillNotDraw`
        // en el constructor) hereda `FLAG_SKIP_DRAW` y el framework NUNCA llama a
        // `onDraw`. `LottieAnimationView` no lo sufría porque es un `ImageView`,
        // que siempre dibuja; aquí, sobre un `View` pelado, el resultado era un
        // `windowBackground` verde sólido con el Lottie parseado y `playAnimation`
        // corriendo, pero sin un solo fotograma pintado. Este flag es lo único que
        // obliga a pasar por `onDraw`.
        setWillNotDraw(false)
    }

    private val drawable = LottieDrawable().also {
        it.callback = this
        // Una sola pasada: con INFINITE `onAnimationEnd` no llega jamás y la
        // actividad quedaría colgada hasta su techo de guardias.
        it.repeatCount = 0
        // El JSON hornea la palabra «Cargando» como capa de TEXTO (`ty:5`,
        // `fFamily: "sans-serif"`). Sin este delegate, `FontAssetManager` resuelve
        // la fuente buscando un asset `fonts/sans-serif.ttf` que NO se empaqueta y
        // revienta en el PRIMER `onDraw` con `RuntimeException: Font asset not
        // found` (medido en el REA NX9: mateaba la splash entera). Devolver la
        // `Typeface` del sistema corta la búsqueda antes de tocar assets; es
        // justamente la «sans-serif» que el JSON pide, así que el rótulo se ve
        // igual, solo que en la fuente del SO y no en Inter — acceptable porque
        // la portada real de `SplashGate` (Inter) pisa encima en cuanto Flutter
        // monta.
        it.setFontAssetDelegate(
            object : FontAssetDelegate() {
                override fun fetchFont(fontFamily: String?): Typeface =
                    Typeface.SANS_SERIF
            },
        )
    }
    private val scaleMatrix = Matrix()

    // El arranque en frío se audita en el logcat: saber si `onDraw` llegó a
    // correr (y con qué tamaño) es lo único que distingue «el drawable no tiene
    // capa» de «la ventana nunca se inválidó».
    private var paintedLogged = false

    /**
     * El drawable reprograma sus propios frames a través de este callback; hay
     * que delegarlos al ticker de la ventana, no a un `postDelayed`, o la
     * animación se desconecta del vsync.
     */
    override fun invalidateDrawable(who: Drawable) {
        invalidate()
    }

    override fun scheduleDrawable(who: Drawable, what: Runnable, delay: Long) {
        postOnAnimationDelayed(what, delay)
    }

    override fun unscheduleDrawable(who: Drawable, what: Runnable) {
        removeCallbacks(what)
    }

    /**
     * Montar la composición cuesta dos cosas, y la segunda es la razón de existir
     * de este método.
     *
     * `LottieDrawable` tiene un protocolo de auto-invalidación con un flag
     * privado `isDirty`: `invalidateSelf()` sale inmediatamente SI EL FLAG YA ESTA
     * ARMADO (es la deduplicación que evita inválidar dos veces por frame), y el
     * flag SOLO se desarma al final de `draw()`. Pero `draw()` tiene una salida
     * anticipada cuando todavía no hay `compositionLayer`, y esa salida NO desarma
     * el flag. Como la ventana se dibuja en cuanto se mide —y en DEBUG el parseo
     * del JSON tarda ~3,4 s más que esa primera pasada—, el orden real era:
     * `onDraw` sin composición → `isDirty` queda armado para siempre → cada
     * `invalidateSelf()` del animator se ignora → ni un píxel de la pantalla
     * cambia durante los 1,5 s de animación, aunque `onAnimationEnd` llegue
     * puntual. Medido dos veces con `screenrecord` + `logcat` sobre el mismo
     * arranque.
     *
     * `invalidate()` acá corta el ciclo por fuera del drawable: el dibujo que
     * provoca ya encuentra composición, llega al final de `draw()`, desarma
     * `isDirty` y deja que el protocolo propio de Lottie funcione el resto de la
     * pasada. `LottieAnimationView` nunca sufre esto porque es `ImageView` y pide
     * el dibujo por su cuenta al recibir la imagen.
     */
    fun setComposition(composition: LottieComposition) {
        drawable.setComposition(composition)
        invalidate()
    }

    fun playAnimation() {
        drawable.playAnimation()
    }

    fun cancelAnimation() {
        drawable.cancelAnimation()
    }

    /**
     * El drawable NO expone `setVisible` (eso es de `AnimationView`), así que el
     * ciclo de la ventana se le comunica aquí: sin esto, girar el teléfono o
     * apagar la pantalla deja el ticker corriendo contra una ventana invisible.
     */
    fun pauseAnimation() {
        drawable.pauseAnimation()
    }

    fun resumeAnimation() {
        if (!drawable.isAnimating) {
            drawable.resumeAnimation()
        }
    }

    fun addAnimatorListener(listener: android.animation.AnimatorListenerAdapter) {
        drawable.addAnimatorListener(listener)
    }

    /**
     * Los bounds son geometría, así que viven en el layout y no en el trazado. Se
     * pone el cuadrado del JSON (`min(ancho, alto)`) y no el rect completo: el
     * drawable escala el lienzo 360x360 a los bounds, y estirarlo a 1100x2442
     * deformaría la micro.
     */
    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        val side = min(w, h)
        drawable.setBounds(0, 0, side, side)
    }

    /**
     * Dibuja el lienzo del JSON CENTER_INSIDE y subido un 11 % del alto. Solo la
     * geometría del trazado: el tamaño del drawable vive en [onSizeChanged].
     */
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val side = min(width, height).toFloat()
        val left = (width - side) / 2f
        // -11 % del alto: el mismo desplazamiento que tenía la vista con
        // `translationY`, para que el handoff con `SplashGate` no mueva el centro.
        val top = (height - side) / 2f - height * 0.11f
        scaleMatrix.reset()
        scaleMatrix.setTranslate(left, top)
        drawable.draw(canvas, scaleMatrix)
        if (!paintedLogged) {
            paintedLogged = true
            Log.d(TAG, "primer onDraw: ${width}x$height lado=${side.toInt()} animando=${drawable.isAnimating}")
        }
    }

    private companion object {
        // Mismo tag que `SplashActivity`: en el logcat del arranque las dos mitades
        // (reloj de la animación y trazado) tienen que leerse juntas.
        private const val TAG = "UrbanoSplash"
    }
}
