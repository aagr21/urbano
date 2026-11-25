package com.example.urbano

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.util.Log
import android.util.TypedValue
import android.view.Choreographer
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.WindowInsets
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Vista nativa que pinta la splash de arranque con Canvas puro.
 *
 * Es la MISMA portada que `SplashGate` (`lib/src/core/widgets/splash_gate.dart`)
 * pintada antes de que exista Flutter: degradado de marca, anillos de Santa Cruz
 * con su micro, girófono coral, «Cargando» + etapa, barra y pie. El arte existe
 * dos veces y se sincroniza a mano, así que esta vista copia las medidas de Dart
 * (`_RingsPainter`, `_DialPainter`, `_LoadingBlock`, `_Loader`) en vez de
 * inventar las suyas.
 *
 * Lo que la hace verse bien y no «otra pantalla antes de la app»:
 *  * **Antialias en todo** y la fuente real (Inter, leída de los assets de
 *    Flutter que ya viajan en el APK; si falla, `sans-serif-medium`).
 *  * **Mismo layout que Dart**: bloque centrado en el área segura con
 *    `Alignment(0, -0.22)`, girófono de `min(lado) * 0.15` (58–84 dp), 32 dp
 *    entre piezas, barra de 132 × 4 dp y pie a 16 dp del borde inferior seguro.
 *    La vista ocupa toda la pantalla (edge-to-edge, ver [SplashActivity]) y lee
 *    los insets, igual que el `SafeArea` de Flutter.
 *  * **Termina donde empieza `SplashGate`**: la portada de Dart arranca en
 *    `_startT = 0.14`, con los anillos trazados al ~54 %, la barra al 10 % y la
 *    etapa «Preparando la app». Esta animación llega exactamente ahí, así que el
 *    relevo no retrocede (antes acababa en «Todo listo» con la barra llena y
 *    Flutter la vaciaba).
 *  * Girófono, barrido de la barra y micro giran con la vuelta de 1,4 s de Dart
 *    (`_lap`), alrededor de su propio centro.
 *
 * Se pinta en un `SurfaceView` desde un hilo propio (ver [startRenderThread]).
 * Duración: 1,5 s en una sola pasada, contados desde el primer frame; nada se
 * asigna por frame.
 */
class SplashCanvasView(context: Context) : SurfaceView(context), SurfaceHolder.Callback {

    companion object {
        private const val TAG = "UrbanoSplash"

        /** Duración de la animación (el relevo lo dispara [SplashActivity]). */
        private const val DURATION_MS = 1500L

        /** Vuelta del ambiente de Dart (`_SplashCover._lap`). */
        private const val LAP_MS = 1400f

        /**
         * Trazado de los anillos en el relevo: Dart arranca en `t = 0.14` de una
         * ventana `[0, 0.62]`, o sea en `0.14 / 0.62` de su curva.
         */
        private const val RINGS_HANDOFF = 0.14f / 0.62f

        /** Relleno de la barra en el relevo: `0.5 * (0.14 - 0.02) / 0.6`. */
        private const val BAR_HANDOFF = 0.1f

        /** Primera etapa de `BootStage` (la que muestra Dart al montarse). */
        private const val STAGE = "Preparando la app"
        private const val FOOTER = "Santa Cruz de la Sierra · datos GTFS"

        // Colores de marca (AppColors).
        private const val AQUA = 0xFF2AD8C3.toInt()
        private const val PRIMARY = 0xFF008C7B.toInt()
        private const val PRIMARY_DARK = 0xFF00584F.toInt()
        private const val ACCENT = 0xFFFF5B35.toInt()

        // Geometría de `_RingsPainter`.
        private val RING_RADII = floatArrayOf(0.3f, 0.44f, 0.6f, 0.78f, 0.98f)
        private const val LANE = 1
        private const val FROM_ANGLE = (-PI / 2).toFloat()
        private const val SWEEP_ANGLE = (PI / 2).toFloat()
        private const val DEG = (180.0 / PI).toFloat()

        // Girófono (`_DialPainter`): arco coral de 1,15π y cola aqua de 0,32π.
        private const val HEAD_SWEEP = 207f
        private const val TAIL_SWEEP = 57.6f

        /** Blanco con alfa (0..1). */
        private fun white(alpha: Float): Int =
            Color.argb((alpha.coerceIn(0f, 1f) * 255).toInt(), 255, 255, 255)

        private fun clamp01(v: Float) = v.coerceIn(0f, 1f)

        /** `Curves.easeOutCubic` = `Motion.standard`. */
        private fun easeOutCubic(t: Float): Float {
            val u = 1f - t
            return 1f - u * u * u
        }

        /** Entrada con un pelo de rebote para el girófono. */
        private fun easeOutBack(t: Float): Float {
            val c1 = 1.4f
            val c3 = c1 + 1f
            val u = t - 1f
            return 1f + c3 * u * u * u + c1 * u * u
        }
    }

    init {
        holder.addCallback(this)
    }

    // ── Estado de la animación (se lee desde el hilo de render) ──

    /** Guarda geometría y superficie: el hilo principal la escribe, el de render la lee. */
    private val lock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var startedAt = 0L
    @Volatile private var finished = false
    private var lastElapsed = 0L
    private var surfaceReady = false
    private var renderThread: HandlerThread? = null
    private var listener: (() -> Unit)? = null
    private var firstFrameListener: (() -> Unit)? = null

    // ── Paints reutilizables (antialias SIEMPRE: sin él los arcos salen dentados) ──

    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val background = Paint().apply { style = Paint.Style.FILL }
    private val glider = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }

    private val titlePaint = textPaint("Inter-SemiBold.ttf", Typeface.BOLD)
    private val stagePaint = textPaint("Inter-Bold.ttf", Typeface.BOLD)
    private val footerPaint = textPaint("Inter-SemiBold.ttf", Typeface.BOLD)

    /**
     * Inter viaja en el APK como asset de Flutter (`flutter_assets/assets/fonts`).
     * Leerla de ahí evita duplicar la fuente en `res/font`; si no está (un build
     * raro, un rename) la splash sigue con la del sistema, nunca se cae.
     */
    private fun textPaint(file: String, fallbackStyle: Int): Paint =
        Paint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            textAlign = Paint.Align.CENTER
            typeface = try {
                Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/$file")
            } catch (error: RuntimeException) {
                Log.w(TAG, "sin $file en los assets; uso sans-serif-medium", error)
                Typeface.create("sans-serif-medium", fallbackStyle)
            }
        }

    // ── Geometría (se calcula en [layoutScene]) ──

    private var widthPx = 0f
    private var heightPx = 0f
    private var longestSide = 0f
    private var unit = 0f
    private var dp = 1f
    private var insetTop = 0f
    private var insetBottom = 0f

    private var ringsCx = 0f
    private var ringsCy = 0f
    private val ringRects = Array(RING_RADII.size) { RectF() }

    private var dialSize = 0f
    private var dialCx = 0f
    private var dialCy = 0f
    private val dialRect = RectF()

    private var titleBaseline = 0f
    private var stageBaseline = 0f
    private var footerBaseline = 0f
    private val barRect = RectF()

    // ── Ciclo de vida (hilo principal) ──

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        cancelAnimation()
    }

    override fun onApplyWindowInsets(insets: WindowInsets): WindowInsets {
        val top: Float
        val bottom: Float
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            top = bars.top.toFloat()
            bottom = bars.bottom.toFloat()
        } else {
            @Suppress("DEPRECATION")
            top = insets.systemWindowInsetTop.toFloat()
            @Suppress("DEPRECATION")
            bottom = insets.systemWindowInsetBottom.toFloat()
        }
        synchronized(lock) {
            insetTop = top
            insetBottom = bottom
            layoutScene()
        }
        return super.onApplyWindowInsets(insets)
    }

    override fun surfaceCreated(holder: SurfaceHolder) = Unit

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        synchronized(lock) {
            widthPx = width.toFloat()
            heightPx = height.toFloat()
            surfaceReady = true
            layoutScene()
            // Primer frame SÍNCRONO: la superficie nunca asoma vacía (negra).
            renderFrame(lastElapsed)
        }
        startRenderThread()
        firstFrameListener?.let {
            firstFrameListener = null
            it()
        }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        synchronized(lock) { surfaceReady = false }
        stopRenderThread()
    }

    private fun sp(value: Float): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, value, resources.displayMetrics)

    /**
     * Baseline de un texto dentro de una caja de alto `height * size`, con el
     * interlineado repartido arriba y abajo como lo hace Flutter.
     */
    private fun baselineIn(paint: Paint, top: Float, heightMultiplier: Float): Float {
        val m = paint.fontMetrics
        val box = paint.textSize * heightMultiplier
        return top + (box - (m.descent - m.ascent)) / 2f - m.ascent
    }

    private fun layoutScene() {
        if (widthPx == 0f || heightPx == 0f) return
        dp = resources.displayMetrics.density
        longestSide = max(widthPx, heightPx)
        unit = longestSide * 0.0035f

        // Degradado de marca (`urbanoGradient`): arriba-izquierda → abajo-derecha.
        background.shader = LinearGradient(
            0f, 0f, widthPx, heightPx,
            intArrayOf(AQUA, PRIMARY, PRIMARY_DARK),
            floatArrayOf(0f, 0.58f, 1f),
            Shader.TileMode.CLAMP,
        )

        // Anillos: origen medio fuera del lienzo, abajo a la izquierda.
        ringsCx = widthPx * 0.06f
        ringsCy = heightPx * 1.04f
        RING_RADII.forEachIndexed { i, r ->
            val radius = r * longestSide
            ringRects[i].set(ringsCx - radius, ringsCy - radius, ringsCx + radius, ringsCy + radius)
        }

        // Tipografía: titleMedium (16, alto 1.5), titleSmall (14, alto 20/14) y
        // labelSmall (11, alto 1.3), con el espaciado de Dart pasado a em.
        titlePaint.textSize = sp(16f)
        titlePaint.letterSpacing = 1.2f / 16f
        stagePaint.textSize = sp(14f)
        stagePaint.letterSpacing = 0.1f / 14f
        footerPaint.textSize = sp(11f)
        footerPaint.letterSpacing = 0.6f / 11f
        val titleBox = titlePaint.textSize * 1.5f
        val stageBox = stagePaint.textSize * (20f / 14f)

        // Bloque de carga: girófono · 32 · Cargando · 8 · etapa · 32 · barra.
        dialSize = (min(widthPx, heightPx) * 0.15f).coerceIn(58f * dp, 84f * dp)
        val gap = 32f * dp
        val barHeight = 4f * dp
        val blockHeight = dialSize + gap + titleBox + 8f * dp + stageBox + gap + barHeight
        val safeHeight = heightPx - insetTop - insetBottom
        // `Alignment(0, -0.22)`: (libre / 2) * (1 + y).
        var y = insetTop + (safeHeight - blockHeight) / 2f * (1f - 0.22f)

        dialCx = widthPx / 2f
        dialCy = y + dialSize / 2f
        val dialStroke = dialSize * 0.085f
        val half = dialSize / 2f - dialStroke
        dialRect.set(-half, -half, half, half)
        y += dialSize + gap

        titleBaseline = baselineIn(titlePaint, y, 1.5f)
        y += titleBox + 8f * dp
        stageBaseline = baselineIn(stagePaint, y, 20f / 14f)
        y += stageBox + gap

        val barWidth = 132f * dp
        barRect.set(widthPx / 2f - barWidth / 2f, y, widthPx / 2f + barWidth / 2f, y + barHeight)

        // Barrido: un tramo del 34 % que se aclara al centro, como en `_Loader`.
        val gliderWidth = barWidth * 0.34f
        glider.shader = LinearGradient(
            0f, 0f, gliderWidth, 0f,
            intArrayOf(Color.TRANSPARENT, 0xB3FFFFFF.toInt(), Color.TRANSPARENT),
            null,
            Shader.TileMode.CLAMP,
        )

        // Pie: a 16 dp del borde inferior seguro.
        val footerBox = footerPaint.textSize * 1.3f
        footerBaseline = baselineIn(footerPaint, heightPx - insetBottom - 16f * dp - footerBox, 1.3f)
    }

    // ── Control de animación ──

    fun setOnFinishedListener(listener: () -> Unit) {
        this.listener = listener
    }

    /**
     * Se llama (en el hilo principal) cuando el primer frame ya está en la
     * superficie: es el momento de cargar trabajo pesado en el hilo principal,
     * porque la animación ya no depende de él.
     */
    fun setOnFirstFrameListener(listener: () -> Unit) {
        firstFrameListener = listener
    }

    fun cancelAnimation() {
        finished = true
        stopRenderThread()
    }

    /**
     * La animación corre en SU hilo, con su propio `Choreographer` (vsync), y
     * no en el principal: mientras la splash anima, [SplashActivity] levanta el
     * engine de Flutter en el hilo principal (~0,8 s bloqueado en un release, más
     * de 1,5 s en debug). Con una `View` común ese bloqueo congelaba la
     * animación y el reloj seguía corriendo: el primer frame llegaba cuando la
     * animación ya había terminado y solo se veía el campo verde del sistema.
     */
    private fun startRenderThread() {
        if (renderThread != null || finished) return
        val thread = HandlerThread("UrbanoSplashRender", Process.THREAD_PRIORITY_DISPLAY)
        thread.start()
        renderThread = thread
        Handler(thread.looper).post { Choreographer.getInstance().postFrameCallback(frame) }
    }

    private fun stopRenderThread() {
        val thread = renderThread ?: return
        renderThread = null
        thread.quitSafely()
    }

    private val frame = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (finished) return
            val now = SystemClock.uptimeMillis()
            // El reloj arranca en el primer frame del hilo de render, no en
            // `onCreate`: la animación se ve ENTERA aunque el arranque se demore.
            if (startedAt == 0L) startedAt = now
            val elapsed = now - startedAt
            synchronized(lock) {
                lastElapsed = elapsed
                if (surfaceReady) renderFrame(elapsed)
            }
            if (elapsed >= DURATION_MS) {
                // Último frame: queda pintado hasta que entra Flutter.
                finished = true
                mainHandler.post { listener?.invoke() }
            } else {
                Choreographer.getInstance().postFrameCallback(this)
            }
        }
    }

    // ── Dibujo (con `lock` tomado) ──

    private fun renderFrame(elapsed: Long) {
        if (widthPx == 0f || heightPx == 0f) return
        val canvas = (
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) holder.lockHardwareCanvas() else holder.lockCanvas()
            ) ?: return
        try {
            drawScene(canvas, elapsed)
        } finally {
            holder.unlockCanvasAndPost(canvas)
        }
    }

    private fun drawScene(canvas: Canvas, elapsed: Long) {
        canvas.drawPaint(background)
        val ms = min(elapsed, DURATION_MS).toFloat()
        val progress = ms / DURATION_MS
        val lap = (ms % LAP_MS) / LAP_MS

        val draw = easeOutCubic(RINGS_HANDOFF * progress)
        drawCity(canvas, draw, lap)
        drawDial(canvas, ms, lap)
        drawLoadingText(canvas, ms)
        drawBar(canvas, ms, progress, lap)
        drawFooter(canvas, ms)
    }

    /** Avenidas, anillos con paradas y la micro (`_RingsPainter`). */
    private fun drawCity(canvas: Canvas, draw: Float, travel: Float) {
        // 1 · Avenidas radiales, apenas insinuadas.
        stroke.color = white(0.08f * draw)
        stroke.strokeWidth = unit * 0.45f
        for (i in 0 until 5) {
            val angle = FROM_ANGLE + SWEEP_ANGLE * (0.08f + 0.22f * i)
            val dx = cos(angle)
            val dy = sin(angle)
            canvas.drawLine(
                ringsCx + dx * longestSide * 0.2f, ringsCy + dy * longestSide * 0.2f,
                ringsCx + dx * longestSide * 1.15f, ringsCy + dy * longestSide * 1.15f,
                stroke,
            )
        }

        // 2 · Anillos escalonados, de adentro hacia afuera, con sus paradas.
        for (r in RING_RADII.indices) {
            val ringLap = clamp01((draw - r * 0.11f) / 0.6f)
            if (ringLap <= 0f) continue
            val swept = easeOutCubic(ringLap)
            val radius = RING_RADII[r] * longestSide
            val isLane = r == LANE

            stroke.color = white(if (isLane) 0.34f else 0.16f)
            stroke.strokeWidth = if (isLane) unit * 1.7f else unit
            canvas.drawArc(ringRects[r], FROM_ANGLE * DEG, SWEEP_ANGLE * DEG * swept, false, stroke)

            val stops = 3 + r
            for (s in 0..stops) {
                val at = s.toFloat() / stops
                if (at > swept) break
                val angle = FROM_ANGLE + SWEEP_ANGLE * at
                val px = ringsCx + cos(angle) * radius
                val py = ringsCy + sin(angle) * radius
                val transfer = isLane && s % 2 == 0
                val dot = if (transfer) unit * 2.1f else unit * 1.4f
                fill.color = white(if (transfer) 0.55f else 0.3f)
                canvas.drawCircle(px, py, dot, fill)
                if (transfer) {
                    // Transbordo: anillo hueco, como en un diagrama de metro.
                    stroke.color = white(0.7f)
                    stroke.strokeWidth = unit * 0.5f
                    canvas.drawCircle(px, py, dot, stroke)
                }
            }
        }

        // 3 · La micro: entra por fuera del lienzo y sale por la esquina, así que
        //    al cerrar cada vuelta no queda ninguna flotando.
        val laneRadius = RING_RADII[LANE] * longestSide
        val angle = FROM_ANGLE - 0.18f + (SWEEP_ANGLE + 0.36f) * travel
        for (k in 7 downTo 1) {
            val back = angle - k * 0.06f
            fill.color = white(0.34f * (1f - k / 8f))
            canvas.drawCircle(
                ringsCx + cos(back) * laneRadius,
                ringsCy + sin(back) * laneRadius,
                unit * (1.7f - k * 0.18f),
                fill,
            )
        }

        canvas.save()
        canvas.translate(ringsCx + cos(angle) * laneRadius, ringsCy + sin(angle) * laneRadius)
        canvas.rotate(atan2(cos(angle), -sin(angle)) * DEG)
        val w = unit * 11f / 2f
        val h = unit * 5.2f / 2f
        val corner = unit * 1.8f
        fill.color = white(0.28f)
        canvas.drawRoundRect(-w, -h, w, h, corner, corner, fill)
        stroke.color = white(0.95f)
        stroke.strokeWidth = unit * 0.7f
        canvas.drawRoundRect(-w, -h, w, h, corner, corner, stroke)
        fill.color = white(0.95f)
        canvas.drawCircle(unit * 4.2f, 0f, unit * 0.9f, fill)
        canvas.restore()
    }

    /** Girófono: pista tenue, arco coral y cola aqua, girando sobre su centro. */
    private fun drawDial(canvas: Canvas, ms: Float, turn: Float) {
        val t = clamp01(ms / 420f)
        val alpha = easeOutCubic(t)
        val scale = 0.82f + 0.18f * easeOutBack(t)

        canvas.save()
        canvas.translate(dialCx, dialCy)
        canvas.scale(scale, scale)
        canvas.rotate(turn * 360f)

        stroke.strokeWidth = dialSize * 0.085f
        stroke.color = white(0.18f * alpha)
        canvas.drawOval(dialRect, stroke)
        stroke.color = ACCENT
        stroke.alpha = (255 * alpha).toInt()
        canvas.drawArc(dialRect, 0f, HEAD_SWEEP, false, stroke)
        stroke.color = AQUA
        stroke.alpha = (255 * 0.6f * alpha).toInt()
        canvas.drawArc(dialRect, HEAD_SWEEP, TAIL_SWEEP, false, stroke)
        canvas.restore()
    }

    /** «Cargando» y la etapa: suben 12 dp mientras aparecen (`_LoadingBlock`). */
    private fun drawLoadingText(canvas: Canvas, ms: Float) {
        val rise = easeOutCubic(clamp01((ms - 60f) / 420f))
        if (rise <= 0f) return
        val dy = (1f - rise) * 12f * dp

        titlePaint.color = white(rise)
        canvas.drawText("Cargando", widthPx / 2f, titleBaseline + dy, titlePaint)
        stagePaint.color = white(0.78f * rise)
        canvas.drawText(STAGE, widthPx / 2f, stageBaseline + dy, stagePaint)
    }

    /** Barra: pista, relleno coral hasta el 10 % del relevo y el barrido. */
    private fun drawBar(canvas: Canvas, ms: Float, progress: Float, sweep: Float) {
        val appear = easeOutCubic(clamp01((ms - 30f) / 360f))
        if (appear <= 0f) return
        val r = barRect.height() / 2f

        fill.color = white(0.2f * appear)
        canvas.drawRoundRect(barRect, r, r, fill)

        val fillWidth = barRect.width() * BAR_HANDOFF * progress
        if (fillWidth > 0f) {
            fill.color = ACCENT
            fill.alpha = (255 * appear).toInt()
            canvas.drawRoundRect(barRect.left, barRect.top, barRect.left + fillWidth, barRect.bottom, r, r, fill)
        }

        val gliderWidth = barRect.width() * 0.34f
        canvas.save()
        canvas.translate(barRect.left + sweep * (barRect.width() - gliderWidth), barRect.top)
        glider.alpha = (255 * appear).toInt()
        canvas.drawRoundRect(0f, 0f, gliderWidth, barRect.height(), r, r, glider)
        canvas.restore()
    }

    private fun drawFooter(canvas: Canvas, ms: Float) {
        val appear = easeOutCubic(clamp01((ms - 30f) / 240f))
        if (appear <= 0f) return
        footerPaint.color = white(0.62f * appear)
        canvas.drawText(FOOTER, widthPx / 2f, footerBaseline, footerPaint)
    }
}
