import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routes/data/route_models.dart';
import '../../stops/data/stop_search_models.dart';
import '../data/journey_models.dart';
import '../data/journey_repository.dart';
import '../domain/journey_query.dart';
import 'refine_journey_options.dart';

export '../domain/journey_place.dart';
export '../domain/journey_query.dart';
export 'refine_journey_options.dart';

/// Opciones de viaje refinadas: sin rutas repetidas y directas primero.
///
/// Se pide un grupo más grande de candidatos al backend ([candidatePool]) para
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
            maxResults: candidatePool(query.maxResults),
          )
          .then(
            (options) =>
                refineJourneyOptions(options, maxShown: query.maxResults),
          );
    });

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
