import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/presentation/home_providers.dart';
import '../../features/routes/presentation/route_providers.dart';

/// Techo de espera de la pantalla de carga.
///
/// La portada se levanta cuando [bootReadinessProvider] termina, pero ese future
/// depende de la red y dio es paciente (12 s de conexión, 20 s de recepción, más
/// sus reintentos): sin techo, un arranque frío de Vercel o una WiFi mala
/// dejarían al usuario mirando una barra de carga casi un minuto. Pasado este
/// tiempo la app abre **con lo que haya**; lo que falte ya tiene su propio estado
/// de error en pantalla.
const Duration bootCeiling = Duration(seconds: 6);

/// Señal de «la app ya tiene en pantalla lo que tiene que enseñar al abrir».
///
/// No es una espera decorativa ni un `Future.delayed` inventado: son las dos
/// llamadas que el inicio dispara de verdad —la página del catálogo que pintan la
/// tirilla «Tus micros» y el mini mapa destacado ([homeCatalogQuery]), y las
/// stats del feed ([statsProvider])— escuchadas **desde antes** de que el home se
/// monte. Eso es justo lo que la portada tapa: mientras ella anima, la red ya
/// trabajó, y cuando el home llega el catálogo ya está servido (misma consulta,
/// mismo provider: un solo `/routes`, no uno por pantalla).
///
/// Se completa con `true` si **al menos una** llamada trajo datos y con `false`
/// si no llegó nada (servicio caído) o si se pasó de [bootCeiling]. Nunca lanza:
/// el error se queda en su propio provider, donde la UI lo muestra, y un future
/// rechazado sin dueño sería además un `Unhandled Exception` en la consola del
/// arranque. Levantar la cortina es la única decisión que toma esta señal, y la
/// toma en los dos casos —una pantalla de carga no puede atrapar a nadie.
final bootReadinessProvider = FutureProvider<bool>((ref) async {
  // `watch` antes de cualquier `await`: es lo que fija la suscripción y hace que
  // el home reutilice ESTE pedido en vez de disparar un segundo `/routes`.
  final arrived = await Future.wait<bool>([
    _track(ref.watch(statsProvider.future)),
    _track(ref.watch(routesListProvider(homeCatalogQuery).future)),
  ]).timeout(bootCeiling, onTimeout: () => const <bool>[]);

  // «Sin respuesta» solo cuando no llegó NADA: con una llamada buena ya hay
  // contenido que enseñar, y la que faltó tiene su propio estado de error en el
  // home.
  return arrived.contains(true);
});

/// `true` si la llamada trajo datos.
Future<bool> _track(Future<Object?> call) async {
  try {
    await call;
    return true;
  } catch (error) {
    // El error sigue vivo en su provider (donde `AsyncValueView` lo pinta); aquí
    // solo se cuenta cuántas llamadas sirvieron para algo.
    debugPrint('Urbano · arranque: $error');
    return false;
  }
}
