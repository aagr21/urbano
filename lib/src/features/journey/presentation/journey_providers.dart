import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routes/data/route_models.dart';
import '../../stops/data/stop_search_models.dart';
import '../data/journey_models.dart';
import '../data/journey_repository.dart';

/// Selección de origen/destino ("mi ubicación" o punto del mapa).
sealed class JourneyPlace {
  const JourneyPlace();

  String get label;
}

class JourneyPlaceLocation extends JourneyPlace {
  const JourneyPlaceLocation({required this.lat, required this.lon});

  final double lat;
  final double lon;

  @override
  String get label => 'Mi ubicación';
}

/// Punto elegido en el mapa (selector de origen/destino).
///
/// El origen/destino es SIEMPRE el punto marcado por el usuario, nunca una
/// parada GTFS: el planificador usa la parada más cercana solo como punto de
/// subida/baja y calcula la caminata hasta el punto exacto.
class JourneyPlacePoint extends JourneyPlace {
  const JourneyPlacePoint({required this.lat, required this.lon});

  final double lat;
  final double lon;

  @override
  String get label =>
      'Punto en el mapa · ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
}

/// Hito o lugar de interés común en Santa Cruz (mercado, plaza, hospital, etc.).
class JourneyPlacePoi extends JourneyPlace {
  const JourneyPlacePoi({
    required this.name,
    required this.lat,
    required this.lon,
    this.subtitle,
  });

  final String name;
  final String? subtitle;
  final double lat;
  final double lon;

  @override
  String get label => name;
}

/// Parámetros de una consulta al planeador.
class JourneyQuery {
  const JourneyQuery({
    required this.origin,
    required this.destination,
    this.time,
    this.maxResults = 3,
  });

  final JourneyPlace origin;
  final JourneyPlace destination;
  final String? time;
  final int maxResults;

  JourneyPoint get originPoint => switch (origin) {
    JourneyPlaceLocation(:final lat, :final lon) => (lat: lat, lon: lon),
    JourneyPlacePoint(:final lat, :final lon) => (lat: lat, lon: lon),
    JourneyPlacePoi(:final lat, :final lon) => (lat: lat, lon: lon),
  };

  JourneyPoint get destinationPoint => switch (destination) {
    JourneyPlaceLocation(:final lat, :final lon) => (lat: lat, lon: lon),
    JourneyPlacePoint(:final lat, :final lon) => (lat: lat, lon: lon),
    JourneyPlacePoi(:final lat, :final lon) => (lat: lat, lon: lon),
  };

  @override
  bool operator ==(Object other) =>
      other is JourneyQuery &&
      other.origin.label == origin.label &&
      other.destination.label == destination.label &&
      other.originPoint == originPoint &&
      other.destinationPoint == destinationPoint &&
      other.time == time &&
      other.maxResults == maxResults;

  @override
  int get hashCode => Object.hash(
    origin.label,
    destination.label,
    originPoint,
    destinationPoint,
    time,
    maxResults,
  );
}

/// Opciones de viaje refinadas: sin rutas repetidas y directas primero.
///
/// Se pide un grupo más grande de candidatos al backend (`_candidatePool`) para
/// que, tras colapsar las opciones casi idénticas, queden tantas combinaciones
/// distintas de micros como `query.maxResults` permita mostrar.
final journeyProvider = FutureProvider.autoDispose
    .family<List<JourneyOption>, JourneyQuery>((ref, query) {
      return ref
          .watch(journeyRepositoryProvider)
          .plan(
            origin: query.originPoint,
            destination: query.destinationPoint,
            time: query.time,
            maxResults: _candidatePool(query.maxResults),
          )
          .then(
            (options) =>
                refineJourneyOptions(options, maxShown: query.maxResults),
          );
    });

/// Nº de candidatos a pedir al planificador para tener margen tras el filtrado.
///
/// Tope 10: el DTO del backend valida `maxResults` con `@Max(10)`; pasarlo
/// devuelve 400 "Validation failed" y el viaje entero falla.
int _candidatePool(int maxShown) => (maxShown * 4).clamp(1, 10);

/// Quita opciones "parecidas" (misma secuencia de micros, solo cambia la hora)
/// y pone primero los viajes SIN transbordo.
///
/// - Dos opciones comparten firma si usan la misma secuencia de rutas (p. ej.
///   `8 → 10`). De cada firma se conserva UNA: la de salida más próxima, y ante
///   empate la de menor duración.
/// - Orden final: primero todos los directos, luego los de transbordo; dentro
///   de cada grupo, por duración asc y después por hora de salida asc.
List<JourneyOption> refineJourneyOptions(
  List<JourneyOption> options, {
  required int maxShown,
}) {
  final bestBySignature = <String, JourneyOption>{};
  for (final option in options) {
    final key = _routeSignature(option);
    final current = bestBySignature[key];
    if (current == null || _departsSooner(option, current)) {
      bestBySignature[key] = option;
    }
  }

  final ordered = bestBySignature.values.toList()
    ..sort((a, b) {
      final byType = _typeRank(a) - _typeRank(b);
      if (byType != 0) return byType;
      final byDuration = a.durationMinutes - b.durationMinutes;
      if (byDuration != 0) return byDuration;
      return a.departAt.compareTo(b.departAt);
    });

  return ordered.length <= maxShown ? ordered : ordered.sublist(0, maxShown);
}

/// Clave que identifica "la misma combinación de micros" ignorando la hora.
String _routeSignature(JourneyOption option) {
  final routes = option.busLegs
      .map((leg) => leg.routeShortName ?? leg.routeId ?? '')
      .join('>');
  return routes;
}

int _typeRank(JourneyOption option) =>
    option.type == JourneyType.direct ? 0 : 1;

/// `true` si [a] sale antes que [b]; a igualdad de hora, la de menor duración.
bool _departsSooner(JourneyOption a, JourneyOption b) {
  final byDepart = a.departAt.compareTo(b.departAt);
  if (byDepart != 0) return byDepart < 0;
  return a.durationMinutes < b.durationMinutes;
}

/// Modo **pantalla completa** del mapa de `/journey`.
///
/// `true` oculta los paneles flotantes (origen/destino, chips, hoja de
/// resultados y píldora) y la barra de navegación inferior del shell, dejando
/// solo el mapa con sus controles. Vive en un provider (no en el `State` de
/// la pantalla) porque también lo lee `UrbanoShell` para esconder su
/// `NavigationBar`: así la pantalla completa es real, de punta a punta.
final mapFullscreenProvider = StateProvider<bool>((_) => false);

/// Intento pendiente de abrir el **panel de micros** desde otra pantalla.
///
/// El listado completo de líneas ya no tiene ruta propia: la pestaña «Rutas»
/// se retiró y ese catálogo vive en el panel de `/journey`. Abrirlo es acción
/// del `State` del planeador (necesita las claves de los recorridos ya
/// dibujados), así que quien pide «ver todas» —el home— cambia de rama y deja
/// esta bandera; el planeador la lee, la limpia y abre el cajón.
final pendingMicrosPanelProvider = StateProvider<bool>((_) => false);

/// Estado de trabajo del **panel de micros**, que sobrevive a cerrarlo y
/// volverlo a abrir mientras la app esté abierta.
///
/// El panel se abre como una ruta sobre el mapa y su `State` muere al
/// cerrarse: sin este store se perderían cada vez el texto buscado, la
/// posición del scroll, el listado ya descargado de `/routes` (otro pago de
/// red) y los headsign de las direcciones consultadas.
class JourneyMicrosSession {
  /// Listado de líneas ya descargado (`/routes` paginado por completo).
  List<RouteSummary> micros = const [];

  /// `true` cuando el listado de [micros] viene de una descarga exitosa.
  bool loaded = false;

  /// Texto del buscador del panel.
  String query = '';

  /// Posición del scroll del listado (se va guardando en cada desplazamiento).
  double scrollOffset = 0;

  /// Modo del panel: `false` = busco LÍNEAS (catálogo); `true` = busco
  /// LUGARES («¿qué línea pasa por aquí?»). Persiste entre aperturas.
  bool placesMode = false;

  /// Última búsqueda de lugares confirmada (commit, no borrador). Lleva la
  /// fuente: texto o «cerca de mí» con el punto usado.
  String placesQuery = '';
  ({double lat, double lon})? placesNearbyPoint;

  /// Última lista de lugares mostrada: la restauración instantánea del
  /// panel no vuelve a pagar la red. «Jalar para actualizar» la invalida.
  List<StopHit>? placeResults;

  /// Detalles pedidos por id de micro (`/routes/:id`): dan los headsign y las
  /// direcciones reales de cada tarjeta.
  final Map<String, RouteDetail> details = {};
}

/// Proveedor de la sesión: `Provider` a secas (no `autoDispose`) para que el
/// estado viva mientras exista el `ProviderScope` de la app.
final journeyMicrosSessionProvider = Provider<JourneyMicrosSession>(
  (ref) => JourneyMicrosSession(),
);

/// Punto geográfico del lugar elegido, o `null` si no hay lugar.
extension JourneyPlacePointX on JourneyPlace? {
  JourneyPoint? get pointOrNull => switch (this) {
    null => null,
    JourneyPlaceLocation(:final lat, :final lon) => (lat: lat, lon: lon),
    JourneyPlacePoint(:final lat, :final lon) => (lat: lat, lon: lon),
    JourneyPlacePoi(:final lat, :final lon) => (lat: lat, lon: lon),
  };
}
