import 'endpoint_distance.dart';
import 'journey_place.dart';

/// Borrador del viaje que se arma en la hoja «¿A dónde vas?» de la portada.
///
/// Inmutable y sin Flutter: cada gesto (llega el GPS, escribir, elegir un
/// lugar, invertir…) es una transición pura que devuelve el borrador nuevo, y
/// los textos que muestran los campos se derivan de él. La hoja solo traduce
/// gestos a transiciones y pinta el resultado; así toda la política se prueba
/// sin montar widgets (`test/destination_draft_test.dart`).
class DestinationDraft {
  const DestinationDraft._({
    required this.origin,
    required this.destination,
    required this.gpsOrigin,
    required this.originTouched,
    required this.locating,
    required this.originFailed,
    required this.originQuery,
    required this.destinationQuery,
  });

  /// Borrador inicial: sin origen se sale a buscar el GPS ([locating]).
  factory DestinationDraft.initial({
    JourneyPlace? origin,
    JourneyPlace? destination,
  }) => DestinationDraft._(
    origin: origin,
    destination: destination,
    gpsOrigin: null,
    originTouched: false,
    locating: origin == null,
    originFailed: false,
    originQuery: fieldText(origin),
    destinationQuery: fieldText(destination),
  );

  final JourneyPlace? origin;
  final JourneyPlace? destination;

  /// Último punto GPS conocido: si el usuario borra el texto del origen,
  /// puede volver a «Mi ubicación» sin esperar un fix nuevo.
  final JourneyPlaceLocation? gpsOrigin;

  /// `true` en cuanto el usuario escribe o elige un origen propio. Un fix del
  /// GPS que llegue tarde no puede pisar lo que la persona ya eligió: solo
  /// queda guardado como opción «Mi ubicación».
  final bool originTouched;

  /// `true` mientras se busca el primer fix del GPS para el origen.
  final bool locating;

  /// `true` cuando no hubo forma de leer la ubicación (permiso o servicio).
  final bool originFailed;

  /// Texto que hoy muestra cada campo (lo escrito o el nombre del lugar).
  final String originQuery;
  final String destinationQuery;

  /// Con origen y destino resueltos (y no en el mismo sitio) se puede
  /// planificar.
  bool get canPlan => origin != null && destination != null && !tooClose;

  /// Origen y destino (casi) en el mismo sitio: no hay viaje en micro, así
  /// que no se pide (la misma regla de 150 m que el planeador y el backend).
  bool get tooClose => endpointsTooClose(origin, destination);

  // ── Transiciones ─────────────────────────────────────────────────────────

  /// Llegó un fix del GPS. Fija el origen **de inmediato** (es lo que
  /// habilita el viaje), salvo que el usuario ya haya elegido otro: entonces
  /// solo se recuerda para la sugerencia «Mi ubicación».
  DestinationDraft gpsResolved({required double lat, required double lon}) {
    final place = JourneyPlaceLocation(lat: lat, lon: lon);
    if (originTouched) {
      return _copy(gpsOrigin: place, locating: false);
    }
    return _copy(
      gpsOrigin: place,
      origin: place,
      locating: false,
      originFailed: false,
      originQuery: fieldText(place),
    );
  }

  /// No hubo forma de leer la ubicación (permiso o servicio).
  DestinationDraft gpsUnavailable() =>
      _copy(locating: false, originFailed: true);

  /// `true` si el origen sigue siendo el punto GPS en ([lat], [lon]): solo
  /// entonces vale la pena pedir su dirección.
  bool originIsGpsAt({required double lat, required double lon}) =>
      switch (origin) {
        JourneyPlaceLocation(lat: final a, lon: final b) =>
          a == lat && b == lon,
        _ => false,
      };

  /// Llegó la dirección del punto GPS. Solo se anota si el origen sigue
  /// siendo ESE punto; el campo sigue diciendo «Mi ubicación».
  DestinationDraft addressResolved({
    required double lat,
    required double lon,
    required String address,
  }) {
    if (!originIsGpsAt(lat: lat, lon: lon)) return this;
    final enriched = JourneyPlaceLocation(lat: lat, lon: lon, address: address);
    return _copy(origin: enriched, gpsOrigin: enriched);
  }

  /// Escribir manda: si el texto deja de coincidir con el lugar resuelto, el
  /// extremo se vacía hasta que se elija una sugerencia (o el mapa).
  DestinationDraft originTyped(String text) => _copy(
    originTouched: true,
    originQuery: text,
    origin: text == fieldText(origin) ? origin : null,
  );

  DestinationDraft destinationTyped(String text) => _copy(
    destinationQuery: text,
    destination: text == fieldText(destination) ? destination : null,
  );

  /// Se eligió un lugar (sugerencia, hito, calle o punto del mapa).
  DestinationDraft picked(JourneyPlace place, {required bool isOrigin}) {
    if (!isOrigin) {
      return _copy(destination: place, destinationQuery: fieldText(place));
    }
    return _copy(
      origin: place,
      originTouched: true,
      locating: false,
      originFailed: false,
      originQuery: fieldText(place),
    );
  }

  /// Vuelve a «Mi ubicación» con el último fix conocido (si lo hay).
  DestinationDraft usedGps() {
    final gps = gpsOrigin;
    if (gps == null) return this;
    return _copy(
      origin: gps,
      originTouched: false,
      locating: false,
      originFailed: false,
      originQuery: fieldText(gps),
    );
  }

  /// Invierte origen y destino. El origen deja de ser intocable salvo que el
  /// GPS haya vuelto arriba.
  DestinationDraft swapped() => _copy(
    origin: destination,
    destination: origin,
    locating: false,
    originTouched: destination is! JourneyPlaceLocation,
    originQuery: fieldText(destination),
    destinationQuery: fieldText(origin),
  );

  /// Un viaje guardado repone los dos extremos.
  DestinationDraft tripLoaded({
    required JourneyPlace origin,
    required JourneyPlace destination,
  }) => _copy(
    origin: origin,
    destination: destination,
    locating: false,
    originFailed: false,
    originQuery: fieldText(origin),
    destinationQuery: fieldText(destination),
  );

  /// Un destino del historial repone el destino y, si falta origen, usa la
  /// última posición conocida ([lastKnown]).
  DestinationDraft historyLoaded({
    required JourneyPlace destination,
    JourneyPlaceLocation? lastKnown,
  }) {
    final fillOrigin = origin == null && lastKnown != null;
    final nextOrigin = fillOrigin ? lastKnown : origin;
    return _copy(
      destination: destination,
      origin: nextOrigin,
      locating: fillOrigin ? false : locating,
      originQuery: fieldText(nextOrigin),
      destinationQuery: fieldText(destination),
    );
  }

  /// `true` si lo escrito pide «Mi ubicación» y hay un fix para usarla.
  bool wantsGps(String query) {
    final q = query.trim().toLowerCase();
    return gpsOrigin != null && q.isNotEmpty && 'mi ubicación'.contains(q);
  }

  // ── Textos ───────────────────────────────────────────────────────────────

  /// Texto del campo para un extremo. La ubicación del teléfono siempre se
  /// llama «Mi ubicación» (el punto GPS queda por detrás).
  static String fieldText(JourneyPlace? place) => switch (place) {
    null => '',
    JourneyPlaceLocation() => 'Mi ubicación',
    JourneyPlacePoi(:final name) => name,
    JourneyPlacePoint(:final address) => address ?? 'Punto en el mapa',
  };

  /// Nombre del origen a la vista, o `null` si falta.
  String? get originLabel => origin == null ? null : fieldText(origin);

  /// Píldora junto al origen: «GPS» cuando es la ubicación del teléfono.
  String? get originTag => origin is JourneyPlaceLocation ? 'GPS' : null;

  String get originSubtitle {
    if (locating) return 'Ubicando tu posición…';
    if (originFailed) return 'Activa tu ubicación o elige en el mapa';
    return switch (origin) {
      null => 'Escribe un lugar o elige en el mapa',
      JourneyPlaceLocation() => 'Usando la ubicación de tu teléfono',
      JourneyPlacePoi(:final subtitle) => subtitle ?? 'Lugar elegido',
      JourneyPlacePoint() => 'Punto elegido en el mapa',
    };
  }

  /// Nombre del destino a la vista, o `null` si falta. A diferencia del
  /// origen, un destino «ubicación» muestra su dirección si la tiene.
  String? get destinationLabel => switch (destination) {
    null => null,
    JourneyPlacePoi(:final name) => name,
    JourneyPlacePoint(:final address) => address ?? 'Punto en el mapa',
    JourneyPlaceLocation(:final address) => address ?? 'Mi ubicación',
  };

  String? get destinationSubtitle {
    if (tooClose) {
      final meters = endpointsDistanceMeters(origin, destination) ?? 0;
      return meters < 1
          ? 'Es el mismo punto que el origen: elige otro destino'
          : 'Está a ${meters.round()} m del origen: camina hasta allí';
    }
    return _destinationContext;
  }

  String? get _destinationContext => switch (destination) {
    null => 'Escribe un lugar o toca uno reciente',
    JourneyPlacePoi(:final subtitle) => subtitle,
    JourneyPlacePoint() => 'Punto elegido en el mapa',
    JourneyPlaceLocation() => 'Usando la ubicación de tu teléfono',
  };

  // ── Copia ────────────────────────────────────────────────────────────────

  /// Centinela: distingue «no tocar el campo» de «dejarlo en `null`».
  static const Object _keep = Object();

  DestinationDraft _copy({
    Object? origin = _keep,
    Object? destination = _keep,
    Object? gpsOrigin = _keep,
    bool? originTouched,
    bool? locating,
    bool? originFailed,
    String? originQuery,
    String? destinationQuery,
  }) => DestinationDraft._(
    origin: identical(origin, _keep) ? this.origin : origin as JourneyPlace?,
    destination: identical(destination, _keep)
        ? this.destination
        : destination as JourneyPlace?,
    gpsOrigin: identical(gpsOrigin, _keep)
        ? this.gpsOrigin
        : gpsOrigin as JourneyPlaceLocation?,
    originTouched: originTouched ?? this.originTouched,
    locating: locating ?? this.locating,
    originFailed: originFailed ?? this.originFailed,
    originQuery: originQuery ?? this.originQuery,
    destinationQuery: destinationQuery ?? this.destinationQuery,
  );
}
