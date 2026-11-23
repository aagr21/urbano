package com.example.urbano

import android.app.Application

/**
 * `Application` de Urbano. Sustituye al `android.app.Application` que Flutter
 * inyectaba por defecto (el placeholder `${applicationName}` de
 * `BaseApplicationNameHandler`).
 *
 * Antes pre-calentaba el parseo del Lottie de la splash, pero ya no hace falta:
 * `SplashCanvasView` pinta con Canvas puro sin parseo ni caché. Se mantiene la
 * clase para que el manifest siga funcionando y para futuro uso si se necesita
 * inicialización global.
 */
class UrbanoSplashApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // La splash Canvas no necesita prewarm: pinta directo sin parseo.
    }
}
