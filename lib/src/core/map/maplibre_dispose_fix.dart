import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Corrige un bug de `maplibre_gl` 0.27.1 al desmontar un mapa nativo.
///
/// **Síntoma**: al abandonar una pantalla con mapa antes de que su vista
/// nativa termine de crearse (navegación rápida, back inmediato), Flutter
/// registra:
///
/// ```text
/// Exception caught by widgets library
/// LateInitializationError: Field '_channel@...' has not been initialized.
///   MapLibreMethodChannel.dispose
///   _MapLibreMapState.dispose
///   StatefulElement.unmount
/// ```
///
/// **Causa**: `_MapLibreMapState.dispose()` ve que el controller aún no
/// existe y llama a `_maplibrePlatform.dispose()` para desmontar la vista
/// de plataforma; pero `MapLibreMethodChannel.dispose()` accede al campo
/// `late MethodChannel _channel`, que solo asigna `initPlatform()` (cuando
/// la vista nativa ya está creada). Si el widget muere antes, el campo
/// nunca se inicializa y el `late` lanza.
///
/// **Parche**: instalamos una subclase cuyo `dispose()` traga ese error
/// concreto. Si el canal nunca existió, no había recursos nativos que
/// liberar, así que ignorarlo es seguro y correcto.
///
/// Solo aplica en plataformas IO: en web el plugin registra su propia
/// plataforma (`MapLibreMapController`) y este fix no la toca.
void installMapLibreDisposeFix() {
  if (kIsWeb) return;
  MapLibrePlatform.createInstance = _SafeMapLibreMethodChannel.new;
}

class _SafeMapLibreMethodChannel extends MapLibreMethodChannel {
  @override
  void dispose() {
    try {
      super.dispose();
    } catch (e) {
      // El error real es un `LateError` interno cuyo mensaje empieza por
      // "LateInitializationError: Field '_channel@...'..." (el tipo no es
      // público, vive en dart:_internal). Cualquier otra excepción se
      // propaga con normalidad.
      if (!e.toString().startsWith('LateInitializationError')) rethrow;
      // El mapa se desmontó antes de que `initPlatform` asignara el
      // canal: no hay recursos nativos que limpiar.
    }
  }
}
