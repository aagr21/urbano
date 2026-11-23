package com.example.urbano

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.SystemClock
import android.view.View
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.PI
import kotlin.math.sin

/**
 * Vista nativa que pinta la splash de arranque con Canvas puro.
 *
 * Reemplaza al Lottie anterior: sin dependencia externa, sin parseo JSON,
 * sin prewarm, sin riesgo de crash por fuente faltante. Todo se dibuja
 * aquí con `Paint` + `Canvas`, animado por `postOnAnimationDelayed`
 * sincronizado con el vsync de la ventana.
 *
 * Elementos visuales (de fondo a frente):
 *  1. Degradado de marca: aqua → verde → verde oscuro (diagonal).
 *  2. Anillos de Santa Cruz: 5 arcos concéntricos que se trazan progresivamente.
 *  3. Avenidas radiales: 5 líneas que emergen desde el centro de los anillos.
 *  4. Paradas: puntos en los anillos, algunos con anillo hueco (transbordo).
 *  5. Micro con estela: recorre el segundo anillo en bucle.
 *  6. Spinner coral con estela aqua: gira en el centro superior.
 *  7. Texto "Cargando" + etapa real debajo.
 *  8. Barra de progreso con barrido.
 *  9. Pie: "Santa Cruz de la Sierra · datos GTFS".
 *
 * Duración: 1.5 s (90 frames a 60fps) en una sola pasada, igual que el Lottie.
 */
class SplashCanvasView(context: Context) : View(context) {

    init {
        setWillNotDraw(false)
    }

    // ── Colores de marca (los mismos que Dart / Android resources) ──

    companion object {
        private const val TAG = "UrbanoSplash"

        // Duración de la animación en ms.
        private const val DURATION_MS = 1500L

        // Colores de marca.
        private const val AQUA = 0xFF2AD8C3
        private const val PRIMARY = 0xFF008C7B
        private const val PRIMARY_DARK = 0xFF00584F
        private const val ACCENT = 0xFFFF5B35

        // Blanco con diferentes alfas.
        private const val WHITE_95 = 0xF2FFFFFF
        private const val WHITE_78 = 0xC8FFFFFF
        private const val WHITE_62 = 0x9EFFFFFF
        private const val WHITE_55 = 0x8CFFFFFF
        private const val WHITE_34 = 0x57FFFFFF
        private const val WHITE_30 = 0x4DFFFFFF
        private const val WHITE_28 = 0x46FFFFFF
        private const val WHITE_20 = 0x33FFFFFF
        private const val WHITE_18 = 0x2EFFFFFF
        private const val WHITE_16 = 0x29FFFFFF
        private const val WHITE_08 = 0x14FFFFFF
    }

    // ── Estado de la animación ──

    private var startedAt = 0L
    private var finished = false
    private var listener: (() -> Unit)? = null

    // ── Paints reutilizables (evitan GC durante la animación) ──

    private val paintStroke = Paint().apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    private val paintFill = Paint().apply {
        style = Paint.Style.FILL
    }

    private val paintText = Paint().apply {
        style = Paint.Style.FILL
        isAntiAlias = true
        typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
    }

    // ── Geometría (se calcula en onSizeChanged) ──

    private var widthPx = 0f
    private var heightPx = 0f
    private var longestSide = 0f

    // Centro de los anillos (esquina inferior izquierda, un poco fuera del lienzo).
    private var ringsCenterX = 0f
    private var ringsCenterY = 0f

    // Radios de los 5 anillos como fracción del lado mayor.
    private val ringRadii = floatArrayOf(0.3f, 0.44f, 0.6f, 0.78f, 0.98f)

    // Ancho de unidad para grosores y puntos.
    private var unit = 0f

    // Tamaño del spinner.
    private var dialSize = 0f

    // Posición del bloque de carga (centro superior).
    private var loadingBlockCenterX = 0f
    private var loadingBlockCenterY = 0f

    // ── Shader del degradado ──

    private var gradientShader: Shader? = null

    // ── Tipografía ──

    private var textCargandoSize = 0f
    private var textStageSize = 0f
    private var textFooterSize = 0f

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        // Iniciar la animación antes del primer draw para que el primer frame
        // ya pinte contenido. Si se llama a startAnimation() después, es idempotente.
        if (startedAt == 0L) {
            startedAt = SystemClock.uptimeMillis()
            postFrame()
        }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        widthPx = w.toFloat()
        heightPx = h.toFloat()
        longestSide = max(widthPx, heightPx)

        // Centro de los anillos: esquina inferior izquierda, un poco fuera.
        ringsCenterX = widthPx * 0.06f
        ringsCenterY = heightPx * 1.04f

        // Unidad para grosores.
        unit = longestSide * 0.0035f

        // Spinner: mitad del logo anterior, clamp 58-84 dp.
        val dp = resources.displayMetrics.density
        dialSize = (min(widthPx, heightPx) * 0.15f).coerceIn(58f * dp, 84f * dp)

        // Bloque de carga: centrado, un poco arriba.
        loadingBlockCenterX = widthPx / 2f
        loadingBlockCenterY = heightPx * 0.38f

        // Tipografía escalada.
        textCargandoSize = 22f * dp
        textStageSize = 15f * dp
        textFooterSize = 11f * dp

        // Degradado diagonal: aqua → primary → primaryDark.
        gradientShader = LinearGradient(
            0f, 0f, widthPx, heightPx,
            intArrayOf(AQUA.toInt(), PRIMARY.toInt(), PRIMARY_DARK.toInt()),
            floatArrayOf(0f, 0.58f, 1f),
            Shader.TileMode.CLAMP,
        )
    }

    // ── Control de animación ──

    fun startAnimation() {
        if (startedAt != 0L) return
        startedAt = SystemClock.uptimeMillis()
        postFrame()
    }

    fun setOnFinishedListener(listener: () -> Unit) {
        this.listener = listener
    }

    fun cancelAnimation() {
        finished = true
        removeCallbacks(postFrameRunnable)
    }

    private val postFrameRunnable = Runnable {
        if (!finished) {
            invalidate()
            postFrame()
        }
    }

    private fun postFrame() {
        if (!finished && startedAt > 0) {
            postOnAnimation(postFrameRunnable)
        }
    }

    // ── Easing ──

    private fun easeOutCubic(t: Float): Float {
        return 1f - (1f - t) * (1f - t) * (1f - t)
    }

    private fun easeInOutCubic(t: Float): Float {
        return if (t < 0.5f) {
            4f * t * t * t
        } else {
            1f - (-2f * t + 2f).let { it * it * it } * -0.5f
        }
    }

    // ── Dibujo principal ──

    override fun onDraw(canvas: Canvas) {
        // Si la geometría aún no está lista (onSizeChanged no llegó), pintar el
        // color de marca para que no se vea transparente.
        if (widthPx == 0f || heightPx == 0f) {
            paintFill.color = PRIMARY.toInt()
            canvas.drawRect(0f, 0f, widthPx, heightPx, paintFill)
            return
        }

        // Si la animación aún no arrancó, pintar el degradado (o el color si
        // el shader no está listo).
        if (startedAt == 0L) {
            paintFill.shader = gradientShader
            canvas.drawRect(0f, 0f, widthPx, heightPx, paintFill)
            paintFill.shader = null
            return
        }

        val elapsed = SystemClock.uptimeMillis() - startedAt
        val progress = (elapsed.toFloat() / DURATION_MS).coerceIn(0f, 1f)

        // Verificar si la animación terminó.
        if (elapsed >= DURATION_MS && !finished) {
            finished = true
            removeCallbacks(postFrameRunnable)
            listener?.invoke()
            return
        }

        // ── 1. Degradado de fondo ──
        paintFill.shader = gradientShader
        canvas.drawRect(0f, 0f, widthPx, heightPx, paintFill)
        paintFill.shader = null

        // ── 2. Avenidas radiales ──
        drawAvenues(canvas, progress)

        // ── 3. Anillos de Santa Cruz ──
        drawRings(canvas, progress)

        // ── 4. Paradas en los anillos ──
        drawStops(canvas, progress)

        // ── 5. Micro con estela ──
        drawBus(canvas, progress)

        // ── 6. Spinner coral/aqua ──
        drawDial(canvas, progress)

        // ── 7. Texto "Cargando" + etapa ──
        drawLoadingText(canvas, progress)

        // ── 8. Barra de progreso ──
        drawProgressBar(canvas, progress)

        // ── 9. Pie de ciudad ──
        drawFooter(canvas, progress)
    }

    // ── Avenidas radiales ──

    private fun drawAvenues(canvas: Canvas, progress: Float) {
        // Aparecen entre 0 y 0.25.
        val alpha = easeOutCubic((progress / 0.25f).coerceIn(0f, 1f))
        if (alpha <= 0f) return

        paintStroke.apply {
            color = (WHITE_08.toInt() and 0x00FFFFFF) or ((alpha * 255).toInt() shl 24)
            strokeWidth = unit * 0.45f
        }

        val fromAngle = -PI.toFloat() / 2f
        val sweepAngle = PI.toFloat() / 2f

        for (i in 0 until 5) {
            val angle = fromAngle + sweepAngle * (0.08f + 0.22f * i)
            val dirX = cos(angle)
            val dirY = sin(angle)
            val startX = ringsCenterX + dirX * longestSide * 0.2f
            val startY = ringsCenterY + dirY * longestSide * 0.2f
            val endX = ringsCenterX + dirX * longestSide * 1.15f
            val endY = ringsCenterY + dirY * longestSide * 1.15f
            canvas.drawLine(startX.toFloat(), startY.toFloat(), endX.toFloat(), endY.toFloat(), paintStroke)
        }
    }

    // ── Anillos concéntricos ──

    private fun drawRings(canvas: Canvas, progress: Float) {
        // Los anillos se trazan entre 0.1 y 0.7, escalonados.
        val fromAngle = -PI.toFloat() / 2f
        val sweepAngle = PI.toFloat() / 2f
        val deg = 180f / PI.toFloat()

        for (r in ringRadii.indices) {
            // Cada anillo empieza 0.11 después del anterior.
            val ringProgress = ((progress - r * 0.11f) / 0.6f).coerceIn(0f, 1f)
            if (ringProgress <= 0f) continue

            val swept = easeOutCubic(ringProgress)
            val radius = ringRadii[r] * longestSide
            val isLane = r == 1 // El segundo anillo es el "corredor" de la micro.

            val alpha = if (isLane) 0x57 else 0x29 // 0.34 vs 0.16
            paintStroke.apply {
                color = (alpha shl 24) or 0xFFFFFF
                strokeWidth = if (isLane) unit * 1.7f else unit
            }

            // Dibujar arco desde -90° hasta 0° (cuadrante inferior derecho).
            canvas.drawArc(
                RectF(
                    ringsCenterX - radius,
                    ringsCenterY - radius,
                    ringsCenterX + radius,
                    ringsCenterY + radius,
                ),
                (fromAngle * deg).toFloat(),
                (sweepAngle * deg * swept).toFloat(),
                false,
                paintStroke,
            )
        }
    }

    // ── Paradas en los anillos ──

    private fun drawStops(canvas: Canvas, progress: Float) {
        val fromAngle = -PI.toFloat() / 2f
        val sweepAngle = PI.toFloat() / 2f

        for (r in ringRadii.indices) {
            val ringProgress = ((progress - r * 0.11f) / 0.6f).coerceIn(0f, 1f)
            if (ringProgress <= 0f) continue

            val swept = easeOutCubic(ringProgress)
            val radius = ringRadii[r] * longestSide
            val isLane = r == 1
            val stops = 3 + r

            for (s in 0..stops) {
                val at = s.toFloat() / stops
                if (at > swept) break

                val angle = fromAngle + sweepAngle * at
                val pointX = (ringsCenterX + cos(angle) * radius).toFloat()
                val pointY = (ringsCenterY + sin(angle) * radius).toFloat()
                val transfer = isLane && s % 2 == 0

                val dotRadius = if (transfer) unit * 2.1f else unit * 1.4f

                // Punto sólido.
                paintFill.color = if (transfer) WHITE_55.toInt() else WHITE_30.toInt()
                canvas.drawCircle(pointX, pointY, dotRadius, paintFill)

                // Anillo hueco para transbordos.
                if (transfer) {
                    paintStroke.apply {
                        color = WHITE_78.toInt()
                        strokeWidth = unit * 0.5f
                    }
                    canvas.drawCircle(pointX, pointY, dotRadius, paintStroke)
                }
            }
        }
    }

    // ── Micro con estela ──

    private fun drawBus(canvas: Canvas, progress: Float) {
        // La micro recorre el segundo anillo (índice 1) en bucle.
        // Empieza a aparecer en 0.2 y se mueve hasta el final.
        val busProgress = ((progress - 0.2f) / 0.8f).coerceIn(0f, 1f)

        val laneRadius = ringRadii[1] * longestSide
        val fromAngle = -PI.toFloat() / 2f - 0.18f
        val totalSweep = PI.toFloat() / 2f + 0.36f
        val angle = fromAngle + totalSweep * busProgress

        val spotX = (ringsCenterX + cos(angle) * laneRadius).toFloat()
        val spotY = (ringsCenterY + sin(angle) * laneRadius).toFloat()

        // Estela: 7 puntos que se desvanecen hacia atrás.
        for (k in 1..7) {
            val backAngle = angle - k * 0.06f
            val trailX = (ringsCenterX + cos(backAngle) * laneRadius).toFloat()
            val trailY = (ringsCenterY + sin(backAngle) * laneRadius).toFloat()
            val trailRadius = unit * (1.7f - k * 0.18f)
            val alpha = (0.34f * (1f - k / 8f)).coerceIn(0f, 1f)
            paintFill.color = ((alpha * 255).toInt() shl 24) or 0xFFFFFF
            canvas.drawCircle(trailX, trailY, trailRadius, paintFill)
        }

        // Cuerpo de la micro.
        canvas.save()
        canvas.translate(spotX, spotY)
        // Tangente a la circunferencia.
        val tangentAngle = atan2(cos(angle), -sin(angle))
        canvas.rotate((tangentAngle * 180f / PI.toFloat()).toFloat())

        val bodyWidth = unit * 11f
        val bodyHeight = unit * 5.2f
        val cornerRadius = unit * 1.8f

        // Relleno semitransparente.
        paintFill.color = WHITE_28.toInt()
        canvas.drawRoundRect(
            -bodyWidth / 2f, -bodyHeight / 2f, bodyWidth / 2f, bodyHeight / 2f,
            cornerRadius, cornerRadius,
            paintFill,
        )

        // Borde blanco.
        paintStroke.apply {
            color = WHITE_95.toInt()
            strokeWidth = unit * 0.7f
        }
        canvas.drawRoundRect(
            -bodyWidth / 2f, -bodyHeight / 2f, bodyWidth / 2f, bodyHeight / 2f,
            cornerRadius, cornerRadius,
            paintStroke,
        )

        // Faro al frente.
        paintFill.color = WHITE_95.toInt()
        canvas.drawCircle(unit * 4.2f, 0f, unit * 0.9f, paintFill)

        canvas.restore()
    }

    // ── Spinner coral con estela aqua ──

    private fun drawDial(canvas: Canvas, progress: Float) {
        // El spinner aparece entre 0 y 0.2.
        val appear = easeOutCubic((progress / 0.2f).coerceIn(0f, 1f))
        if (appear <= 0f) return

        val cx = loadingBlockCenterX
        val cy = loadingBlockCenterY - dialSize * 0.5f - 40f * resources.displayMetrics.density

        // Rotación: una vuelta completa durante la animación.
        val rotation = progress * 360f

        canvas.save()
        canvas.translate(cx, cy)
        canvas.rotate(rotation)
        canvas.scale(appear, appear)

        val stroke = dialSize * 0.085f
        val ring = RectF(
            stroke, stroke,
            dialSize - stroke, dialSize - stroke,
        )

        // Pista: círculo completo tenue.
        paintStroke.apply {
            color = WHITE_18.toInt()
            strokeWidth = stroke
        }
        canvas.drawArc(ring, 0f, 360f, false, paintStroke)

        // Arco principal (coral): ~1.15π radianes = ~207°.
        paintStroke.apply {
            color = ACCENT.toInt()
            strokeWidth = stroke
        }
        canvas.drawArc(ring, 0f, 207f, false, paintStroke)

        // Estela aqua: ~0.32π radianes = ~58°.
        paintStroke.apply {
            color = 0x992AD8C3.toInt()
            strokeWidth = stroke
        }
        canvas.drawArc(ring, 207f, 58f, false, paintStroke)

        canvas.restore()
    }

    // ── Texto "Cargando" + etapa ──

    private fun drawLoadingText(canvas: Canvas, progress: Float) {
        // Aparece entre 0 y 0.2.
        val appear = easeOutCubic((progress / 0.2f).coerceIn(0f, 1f))
        if (appear <= 0f) return

        val cx = loadingBlockCenterX
        val cy = loadingBlockCenterY

        // "Cargando"
        paintText.apply {
            textSize = textCargandoSize
            color = WHITE_95.toInt()
            textAlign = android.graphics.Paint.Align.CENTER
        }
        canvas.drawText("Cargando", cx, cy, paintText)

        // Etapa de carga (cambia según el progreso).
        val stage = when {
            progress < 0.3f -> "Preparando la app"
            progress < 0.7f -> "Buscando rutas"
            else -> "Todo listo"
        }

        paintText.apply {
            textSize = textStageSize
            color = WHITE_78.toInt()
            alpha = (appear * 255).toInt()
            textAlign = android.graphics.Paint.Align.CENTER
        }
        canvas.drawText(stage, cx, cy + textCargandoSize * 1.4f, paintText)
    }

    // ── Barra de progreso ──

    private fun drawProgressBar(canvas: Canvas, progress: Float) {
        // La barra aparece entre 0.02 y 0.3.
        val appear = easeOutCubic(((progress - 0.02f) / 0.28f).coerceIn(0f, 1f))
        if (appear <= 0f) return

        val cx = loadingBlockCenterX
        val cy = loadingBlockCenterY + textCargandoSize * 2.8f

        val barWidth = 132f * resources.displayMetrics.density
        val barHeight = 4f * resources.displayMetrics.density
        val cornerRadius = barHeight / 2f

        val left = cx - barWidth / 2f
        val top = cy - barHeight / 2f

        // Fondo tenue.
        paintFill.color = WHITE_20.toInt()
        canvas.drawRoundRect(left, top, left + barWidth, top + barHeight, cornerRadius, cornerRadius, paintFill)

        // Relleno coral (progreso).
        val fillWidth = barWidth * progress * appear
        if (fillWidth > 0) {
            paintFill.color = ACCENT.toInt()
            canvas.drawRoundRect(left, top, left + fillWidth, top + barHeight, cornerRadius, cornerRadius, paintFill)
        }

        // Barrido (glider): tramo blanco que se mueve de izquierda a derecha.
        val gliderWidth = barWidth * 0.34f
        val gliderX = left + progress * (barWidth - gliderWidth)
        paintFill.color = 0x99FFFFFF.toInt()
        canvas.drawRoundRect(gliderX, top, gliderX + gliderWidth, top + barHeight, cornerRadius, cornerRadius, paintFill)
    }

    // ── Pie de ciudad ──

    private fun drawFooter(canvas: Canvas, progress: Float) {
        // Aparece entre 0.02 y 0.14.
        val appear = easeOutCubic(((progress - 0.02f) / 0.12f).coerceIn(0f, 1f))
        if (appear <= 0f) return

        paintText.apply {
            textSize = textFooterSize
            color = WHITE_62.toInt()
            alpha = (appear * 255).toInt()
            textAlign = android.graphics.Paint.Align.CENTER
        }

        val footerY = heightPx - 48f * resources.displayMetrics.density
        canvas.drawText("Santa Cruz de la Sierra · datos GTFS", widthPx / 2f, footerY, paintText)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        cancelAnimation()
    }
}
