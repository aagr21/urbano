/// Presupuesto de GPS: lo que puede costarle al teléfono saber dónde estamos.
///
/// Todo este archivo es **puro** (sin plugin y sin Riverpod) para poder probarlo
/// con un reloj inyectado. Es la mitad "barato" de la política de ubicación; la
/// otra mitad —CUÁNDO se abre el sensor— vive en la demanda de
/// `location_controller.dart`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../utils/geo.dart';

/// Metros de desplazamiento real para que un punto **cuente como movimiento**.
///
/// Está en el rango 5–10 m que pide el seguimiento a nivel de calle: por debajo
/// de ~5 m el ruido del GNSS con el móvil quieto sobre la mesa ya genera puntos
/// "nuevos", y por encima de 10 m una caminata lenta dejaría de contarse.
///
/// Se usa dos veces, con propósitos distintos:
/// - como `distanceFilter` del proveedor: lo que no mueva 8 m ni siquiera sube
///   a Dart (ahorra el método canalizado y el parseo).
/// - como umbral de [onlyRealMovement]: el proveedor compara posiciones **crudas**
///   y no sabe si lo que llegó ya fue contado; el filtro Dart recién garantiza
///   que entre dos puntos procesados haya desplazamiento de verdad.
const int gpsMinMovementMeters = 8;

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
/// Es el mismo default del proveedor (5 s), escrito a propósito: nadie debe
/// "mejorar" la fluidez bajando el intervalo sin saber que cada vuelta despierta
/// al radio. Con [gpsMinMovementMeters] de filtro, bajarlo no aporta nada.
const Duration gpsReportInterval = Duration(seconds: 5);

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
/// - **Android** (FusedLocationProvider): [gpsReportInterval] + filtro de
///   [gpsMinMovementMeters], y se queda en el proveedor fundido de Play (nunca
///   `forceLocationManager`, que enciende el GNSS sin la fusión de sensores que
///   reparte el costo).
/// - **Apple** (iOS/macOS): `pauseLocationUpdatesAutomatically` deja que el
///   sistema **apague el sensor** cuando detecta que el dispositivo está quieto
///   —el ahorro de energía pasiva, sin temporizadores nuestros— y
///   `allowBackgroundLocationUpdates: false` lo suelta al pasar a segundo plano
///   (coherente con el manifiesto: sin permiso de fondo en Android y sin
///   `UIBackgroundModes` de ubicación).
/// - Resto (web/escritorio): [LocationSettings] peladas.
LocationSettings gpsTrackingSettings({
  LocationAccuracy accuracy = LocationAccuracy.high,
  int distanceFilter = gpsMinMovementMeters,
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

/// Deja pasar solo **desplazamiento real**; lo demás es ruido.
///
/// Es el ahorro que se nota en el uso: cada punto que sale de aquí reconstruye
/// la capa del mapa y mueve la cámara sobre una vista nativa. Con 2 m de umbral
/// un bus detenido en un semáforo generaba un `animateCamera` por cada sacudida
/// del GNSS — CPU, GPU y calor para correr el centro medio metro.
///
/// El ancla es el último punto **dejado pasar** (no el último recibido), así que
/// deriva acumulada: 10 fijaciones de 1 m no despiertan la cámara.
///
/// Se cancela aguas arriba de verdad: cuando el dueño de este stream se
/// desuscribe, [StreamController.onCancel] cancela la suscripción de [fixes] y
/// con ella el listener nativo del GPS. Esto **no** se implementa con un
/// generador `async*` + `await for` porque ese patrón NO propaga la cancelación
/// a la fuente (verificado: la fuente sigue con oyente después de `cancel()`),
/// que es exactamente lo contrario de liberar el sensor.
Stream<LatLng> onlyRealMovement(
  Stream<LatLng> fixes, {
  int minMeters = gpsMinMovementMeters,
  Duration heartbeat = gpsQuietHeartbeat,
  DateTime Function() clock = DateTime.now,
}) {
  late final StreamController<LatLng> out;
  StreamSubscription<LatLng>? upstream;
  LatLng? anchor;
  var lastEmit = clock();

  out = StreamController<LatLng>(
    onListen: () {
      upstream = fixes.listen(
        (fix) {
          // `anchor` es capturada y reasignada: no la promueve el flujo de tipos.
          final previous = anchor;
          final moved =
              previous == null || haversineMeters(previous, fix) >= minMeters;
          // El latido lento: quietud prolongada igualmente refresca el punto.
          final due = clock().difference(lastEmit) >= heartbeat;
          if (!moved && !due) return;
          anchor = fix;
          lastEmit = clock();
          out.add(fix);
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
