import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/journey_models.dart';
import '../data/journey_repository.dart';
import 'journey_planner_controller.dart';
import 'journey_providers.dart';

/// Proyección inmutable de la **vista de resultados** del planeador: todos
/// los derivados que la pantalla (hoja, chips, mapa) necesita, ya calculados.
///
/// Es la interface del módulo; nada de lo que un consumidor lee aquí exige
/// conocer la regla de frescura del caché ni el clamp del índice seleccionado:
/// eso vive en la implementación del [journeyResultsProvider].
class JourneyResultsView {
  const JourneyResultsView({
    required this.query,
    required this.result,
    required this.options,
    required this.hasResults,
    required this.bare,
    required this.replanning,
    required this.refreshFailed,
    required this.selectedIndex,
    required this.mapOption,
    required this.mapOrigin,
    required this.mapDestination,
  });

  /// Consulta efectiva (contra los puntos planificados), o `null` en modo
  /// exploración (sin envío, sin extremos o extremos incompletos).
  ///
  /// Con `null`, [options] también es `null`: cambiar extremo/hora/swap/
  /// limpiar pone `submitted: false` en el controller, la consulta muere y
  /// con ella el caché (antes era el `_discardCachedOptions()` explícito).
  final JourneyQuery? query;

  /// `AsyncValue` crudo de la consulta vigente (para [JourneyStatusPanel]).
  final AsyncValue<List<JourneyOption>>? result;

  /// Opciones VIGENTES: las de la última respuesta fresca de ESTA consulta.
  /// `null` = sin viaje que mostrar; lista vacía = viaje válido sin micros.
  final List<JourneyOption>? options;

  /// Hay hoja de resultados que mostrar (`options != null`).
  final bool hasResults;

  /// Hay lista pero está vacía (viaje legal sin micros).
  final bool bare;

  /// La consulta actual se RECALCULA sobre resultados ya visibles
  /// (debounce del replan pendiente o fetch en vuelo).
  final bool replanning;

  /// El refresco falló y se sigue mostrando el caché anterior.
  final bool refreshFailed;

  /// Índice de opción seleccionada, acotado a la lista vigente.
  final int selectedIndex;

  /// Opción a dibujar en el mapa: la seleccionada, o la opción «fresca»
  /// falsa («pines solos») cuando no hay lista que dibujar.
  final JourneyOption mapOption;

  /// Extremos para el mapa: prefieren lo que muestran los CAMPOS (que
  /// durante un arrastre de pin van por delante del plan comprometido),
  /// así el pin sigue al dedo.
  final JourneyPoint? mapOrigin;
  final JourneyPoint? mapDestination;
}

/// Proveedor de la vista de resultados: vivo con la app (no `autoDispose`),
/// igual que el controller del planeador del que deriva.
final journeyResultsProvider =
    NotifierProvider<JourneyResultsNotifier, JourneyResultsView>(
      JourneyResultsNotifier.new,
    );

/// Implementación de la vista de resultados: deriva [JourneyResultsView]
/// mirando al controller del planeador y a la consulta en curso.
///
/// El caché de la última respuesta VIVE AQUÍ (antes vivía en el `State` de la
/// pantalla como `_cachedQuery`/`_cachedOptions`): los campos del [Notifier]
/// sobreviven a cada re-ejecución de [build], así la regla de frescura es
/// explícita, testeable sin widgets y la pantalla queda sin side-effects en
/// su `build`.
class JourneyResultsNotifier extends Notifier<JourneyResultsView> {
  /// Consulta cuya respuesta está en el caché (la vigente mientras no llegue
  /// una respuesta nueva de otra consulta).
  JourneyQuery? _adoptedQuery;

  /// Última respuesta con datos: mantiene el viaje visible mientras se
  /// recalcula tras arrastrar el origen/destino.
  List<JourneyOption>? _cachedOptions;

  @override
  JourneyResultsView build() {
    final planner = ref.watch(journeyPlannerControllerProvider);
    // Consulta efectiva: contra los puntos PLANIFICADOS (no los campos, que
    // durante un arrastre van por delante del plan comprometido).
    JourneyQuery? query;
    if (planner.submitted && planner.ready) {
      query = JourneyQuery(
        origin: planner.planOrigin ?? planner.origin!,
        destination: planner.planDestination ?? planner.destination!,
        time: planner.time,
      );
    }
    // Resultado en curso (solo mientras hay consulta; al morir la consulta
    // suelte la dependencia y el family autoDispose libera su estado igual
    // que hoy lo hacía el `watch` del widget).
    final result = query == null ? null : ref.watch(journeyProvider(query));

    // Regla de frescura del caché:
    //  - consulta `null` (nuevo extremo/hora/swap/limpiar) → descartar;
    //  - respuesta fresca de la consulta ACTUAL → adoptar;
    //  - lo demás (fetch en vuelo o con error) → conservar la anterior.
    final fresh = result?.valueOrNull;
    if (query == null) {
      _adoptedQuery = null;
      _cachedOptions = null;
    } else if (fresh != null && query != _adoptedQuery) {
      _adoptedQuery = query;
      _cachedOptions = fresh;
    }

    final cached = _cachedOptions;
    final hasResults = cached != null;
    final bare = cached != null && cached.isEmpty;
    final replanning =
        hasResults && (planner.replanPending || (result?.isLoading ?? false));
    final refreshFailed =
        hasResults && (result?.hasError ?? false) && fresh == null;
    final selectedIndex = cached == null || cached.isEmpty
        ? 0
        : planner.selectedOptionIndex.clamp(0, cached.length - 1);
    final mapOption = !hasResults || cached.isEmpty
        ? _bareOption()
        : cached[selectedIndex];
    // El mapa prefiere lo que muestran los CAMPOS (que durante un arrastre de
    // pin van por delante del plan comprometido): así el pin sigue el dedo.
    final mapOrigin = planner.origin.pointOrNull ?? query?.originPoint;
    final mapDestination =
        planner.destination.pointOrNull ?? query?.destinationPoint;

    return JourneyResultsView(
      query: query,
      result: result,
      options: cached,
      hasResults: hasResults,
      bare: bare,
      replanning: replanning,
      refreshFailed: refreshFailed,
      selectedIndex: selectedIndex,
      mapOption: mapOption,
      mapOrigin: mapOrigin,
      mapDestination: mapDestination,
    );
  }

  /// Reintenta la consulta vigente («Reintentar» de los chips): invalidate
  /// del family con la consulta activa, sin que el caller conozca el caché
  /// ni la clave.
  void retryRefresh() {
    final query = state.query;
    if (query != null) ref.invalidate(journeyProvider(query));
  }
}

/// Opción «vacía» para mostrar el mapa (con origen/destino) cuando la
/// respuesta no trae ninguna ruta. Vive aquí (ya no en la pantalla) porque es
/// parte de la política de la vista: todo consumidor muestra lo mismo.
JourneyOption _bareOption() => const JourneyOption(
  type: JourneyType.direct,
  departAt: '',
  arriveAt: '',
  durationMinutes: 0,
  legs: [],
);
