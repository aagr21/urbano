import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Intento pendiente de abrir el **panel de origen/destino** desde otra pantalla.
///
/// Lo usan la barra «¿A dónde vas?» del home (y una fila del historial): el
/// usuario ya pidió viajar,
/// así que llegar a `/journey` con el
/// panel cerrado (la píldora «¿A dónde vas?») lo obligaba a tocar otra vez.
/// El despliegue es acción del `State` del planeador, así que el home deja
/// esta bandera, cambia de rama, y el planeador la lee, la limpia y abre.
final pendingPlannerPanelProvider = StateProvider<bool>((_) => false);
