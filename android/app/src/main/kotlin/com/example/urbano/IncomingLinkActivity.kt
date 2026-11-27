package com.example.urbano

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Puerta de entrada de las ubicaciones que mandan otras apps.
 *
 * - Tocar una ubicación en WhatsApp dispara un `ACTION_VIEW` con una URI
 *   `geo:lat,lon?q=lat,lon(Nombre)`: Urbano aparece en el selector junto a
 *   Google Maps.
 * - «Compartir» un lugar desde Google Maps (o cualquier texto con un enlace de
 *   mapas) llega como `ACTION_SEND` de `text/plain`.
 * - `urbano://destino?lat=&lon=&nombre=` sirve para enlaces propios.
 *
 * Es un trampolín invisible y no hace nada con el contenido: lo deja en
 * [IncomingLinks] y trae la tarea de la app al frente con el MISMO intent del
 * launcher. Así, con la app viva se reanuda donde estaba (Dart pregunta al
 * volver a primer plano) y en frío arranca por [SplashActivity] como siempre.
 * Abrir [MainActivity] directo desde aquí crearía una segunda FlutterActivity
 * en la tarea de WhatsApp enganchada al engine cacheado de la splash.
 */
class IncomingLinkActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val payload = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.dataString
            Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
            else -> null
        }
        if (!payload.isNullOrBlank()) {
            IncomingLinks.offer(payload)
            Log.d(TAG, "enlace recibido (${intent?.action})")
        }
        packageManager.getLaunchIntentForPackage(packageName)?.let { launch ->
            launch.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED,
            )
            startActivity(launch)
        }
        finish()
    }

    private companion object {
        const val TAG = "UrbanoLink"
    }
}

/**
 * Buzón de un solo enlace, vivo mientras viva el proceso. Dart lo vacía con
 * `takePending` por el canal `urbano/incoming_link`; el último enlace gana.
 */
object IncomingLinks {
    private const val CHANNEL = "urbano/incoming_link"

    @Volatile
    private var pending: String? = null

    @Synchronized
    fun offer(link: String) {
        pending = link
    }

    @Synchronized
    fun take(): String? = pending.also { pending = null }

    /**
     * Registra el canal en un engine. Se llama desde el engine pre-calentado de
     * [SplashActivity] (Dart puede preguntar antes de que [MainActivity] se
     * enganche) y desde [MainActivity.configureFlutterEngine].
     */
    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "takePending") result.success(take()) else result.notImplemented()
            }
    }
}
