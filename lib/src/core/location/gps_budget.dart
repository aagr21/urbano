/// Presupuesto de GPS: lo que puede costarle al teléfono saber dónde estamos.
///
/// Todo este archivo es **puro** (sin plugin y sin Riverpod) para poder probarlo
/// con un reloj inyectado. Es la mitad "barato" de la política de ubicación; la
/// otra mitad —CUÁNDO se abre el sensor— vive en la demanda de
/// `location_controller.dart`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, immutable;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../utils/geo.dart';

/// Metros de desplazamiento real para que la **CÁMARA** se mueva.
///
/// Está en el rango 5–10 m que pide el seguimiento a nivel de calle: por debajo
/// de ~5 m el ruido del GNSS con el móvil quieto sobre la mesa ya genera puntos
/// "nuevos" y cada uno re-anima la cámara nativa (CPU, GPU y calor para correr
/// el centro medio metro), y por encima de 10 m una caminata lenta dejaría de
/// contarse.
///
/// OJO: este umbral es SOLO de la cámara. El punto de «mi ubicación» se mueve
/// con [gpsMinDrawMeters] (mucho más fino): si el punto esperara a los 5 m, en
/// una caminata quedaba congelado 3–4 s por vez y parecía que la ubicación «no
/// se actualizaba» aunque el GPS sí estuviera entregando.
const int gpsMinMovementMeters = 5;

/// Metros por debajo de los cuales un punto es una **repetición** del anterior.
///
/// Es el umbral del PUNTO («estás aquí»), no el de la cámara: 1 m está por
/// debajo del ruido de un GNSS quieto, así que solo descarta fijaciones
/// idénticas. Con esto el punto propio avanza con cada fijación mientras el
/// usuario camina, que es exactamente lo que el ojo espera ver.
const int gpsMinDrawMeters = 1;

/// Latido mínimo entre actualizaciones cuando NO hay desplazamiento real.
///
/// Un dispositivo quieto no debe quedar "sin noticias" para siempre: pasado este
/// rato se deja pasar un punto (para refrescar la posición, saber que el GPS
/// sigue vivo y que el punto propio no se congela) en vez de un punto por cada
/// sacudida de 3 m. Sin este latido el filtro sería absoluto y la app parecería
/// muerta después de un rato quieta.
const Duration gpsQuietHeartbeat = Duration(seconds: 30);

/// Tiempo máximo de una lectura puntual antes de darse por vencida.
///
/// Es ahorro directo: sin límite el receptor queda buscando fix (típico en
/// interiores) mientras el usuario mira, consumiendo, para nada. Con él la app
/// falla rápido y muestra su mensaje amigable. NO se pone en el stream continuo:
/// allí "no haber novedades" es el estado normal de un móvil quieto.
const Duration gpsOneShotTimeLimit = Duration(seconds: 15);

/// Ritmo declarado de la escucha continua en Android.
///
/// Un segundo limita el retraso visible mientras el usuario camina. El
/// proveedor ya NO filtra por distancia ([gpsTrackingSettings] pide
/// `distanceFilter: 0`): el ruido lo descarta Dart, donde el punto propio y la
/// cámara tienen umbrales distintos.
const Duration gpsReportInterval = Duration(seconds: 1);

/// Ajustes de una lectura **puntual** («cerca de mí», centro inicial, elegir un
/// extremo con «usar mi ubicación»).
///
/// `medium` = balanceado: nivel calle sobra, la fijación llega antes y el radio
/// trabaja menos por punto. Es lo que se paga al tocar un botón, no lo que se
/// mantiene encendido.
const LocationSettings gpsOneShotSettings = LocationSettings(
  accuracy: LocationAccuracy.medium,
  timeLimit: gpsOneShotTimeLimit,
);

/// Ajustes de la **escucha continua** (seguimiento del mapa).
///
/// Va a `high` porque el seguimiento es el único caso donde la precisión es
/// imprescindible (hay que ver si el micro pasa o no), pero con las llaves de
/// ahorro por plataforma:
/// - **Android** (FusedLocationProvider): [gpsReportInterval] y
///   `distanceFilter: 0`, y se queda en el proveedor fundido de Play (nunca
///   `forceLocationManager`, que enciende el GNSS sin la fusión de sensores que
///   reparte el costo).
/// - **Apple** (iOS/macOS): `pauseLocationUpdatesAutomatically` deja que el
///   sistema **apague el sensor** cuando detecta que el dispositivo está quieto
///   —el ahorro de energía pasiva, sin temporizadores nuestros— y
///   `allowBackgroundLocationUpdates: false` lo suelta al pasar a segundo plano
///   (coherente con el manifiesto: sin permiso de fondo en Android y sin
///   `UIBackgroundModes` de ubicación).
/// - Resto (web/escritorio): [LocationSettings] peladas.
///
/// **[distanceFilter] es 0 a propósito.** El filtro del proveedor es
/// todo-o-nada (además de frenar el `animateCamera`, congela el PUNTO propio) y
/// algunos equipos lo aplican de forma agresiva: el mapa se quedaba quieto con
/// el usuario avanzando. El presupuesto se decide aguas arriba en Dart
/// ([trackedFixes]): el punto se mueve con [gpsMinDrawMeters] y la cámara con
/// [gpsMinMovementMeters]. El sensor solo está encendido mientras hay
/// seguimiento, así que recibir una fijación por segundo es el costo normal de
/// una app de navegación.
LocationSettings gpsTrackingSettings({
  LocationAccuracy accuracy = LocationAccuracy.high,
  int distanceFilter = 0,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: gpsReportInterval,
      );
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: true,
        allowBackgroundLocationUpdates: false,
      );
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
  }
}

/// Una fijación con la política de movimiento **ya decidida**.
///
/// Existe porque el punto propio y la cámara tienen umbrales distintos: el
/// punto tiene que avanzar en cada fijación (si no, el usuario camina y no ve
/// nada moverse) y la cámara solo cuando hay desplazamiento real (si no, el
/// ruido del GNSS re-anima el mapa sin parar).
@immutable
class TrackedFix {
  const TrackedFix(this.point, {required this.moved});

  final LatLng point;

  /// `true` si este punto marca desplazamiento real ([gpsMinMovementMeters])
  /// desde el último que movió la cámara, o si toca el latido lento. Solo
  /// estos recentran el mapa; **todos** mueven el punto propio.
  final bool moved;
}

/// Deja pasar el **avance del punto** y marca cuáles puntos mueven la cámara.
///
/// Es el ahorro que se nota en el uso: cada punto que mueve la cámara
/// reconstruye la capa del mapa y la re-anima sobre una vista nativa. Con 2 m de
/// umbral un bus detenido en un semáforo generaba un `animateCamera` por cada
/// sacudida del GNSS — CPU, GPU y calor para correr el centro medio metro.
///
/// El ancla de la cámara es el último punto **despachado como movimiento** (no
/// el último recibido), así que la deriva acumulada no la despierta: 10
/// fijaciones de 1 m no re-animan el mapa, pero sí mueven el punto propio, que
/// se descarta solo con [gpsMinDrawMeters] (repeticiones) o el latido lento de
/// [gpsQuietHeartbeat] (quietud prolongada).
///
/// Se cancela aguas arriba de verdad: cuando el dueño de este stream se
/// desuscribe, [StreamController.onCancel] cancela la suscripción de [fixes] y
/// con ella el listener nativo del GPS. Esto **no** se implementa con un
/// generador `async*` + `await for` porque ese patrón NO propaga la cancelación
/// a la fuente (verificado: la fuente sigue con oyente después de `cancel()`),
/// que es exactamente lo contrario de liberar el sensor.
Stream<TrackedFix> trackedFixes(
  Stream<LatLng> fixes, {
  int drawMeters = gpsMinDrawMeters,
  int moveMeters = gpsMinMovementMeters,
  Duration heartbeat = gpsQuietHeartbeat,
  DateTime Function() clock = DateTime.now,
}) {
  late final StreamController<TrackedFix> out;
  StreamSubscription<LatLng>? upstream;

  /// Último punto despachado (gobierna el punto propio).
  LatLng? drawn;

  /// Último punto que movió la cámara (gobierna la cámara).
  LatLng? anchor;
  var lastEmit = clock();

  out = StreamController<TrackedFix>(
    onListen: () {
      upstream = fixes.listen(
        (fix) {
          // `drawn`/`anchor` se reasignan: no las promueve el flujo de tipos.
          final previousDraw = drawn;
          final previousAnchor = anchor;
          final movement =
              previousAnchor == null ||
              haversineMeters(previousAnchor, fix) >= moveMeters;
          final advance =
              previousDraw == null ||
              haversineMeters(previousDraw, fix) >= drawMeters;
          // El latido lento: quietud prolongada igualmente refresca el punto.
          final due = clock().difference(lastEmit) >= heartbeat;
          if (!movement && !advance && !due) return;
          drawn = fix;
          lastEmit = clock();
          if (movement || due) anchor = fix;
          out.add(TrackedFix(fix, moved: movement || due));
        },
        onError: out.addError,
        onDone: out.close,
      );
    },
    onCancel: () async {
      final subscription = upstream;
      upstream = null;
      await subscription?.cancel();
    },
  );

  return out.stream;
}
