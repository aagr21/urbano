import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:urbano/src/features/journey/data/journey_models.dart';
import 'package:urbano/src/features/journey/presentation/journey_planner_controller.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';
import 'package:urbano/src/features/journey/presentation/journey_results_view.dart';

void main() {
  // ------------------------------------------------------------------
  // Fixtures
  // ------------------------------------------------------------------
  // La igualdad de [JourneyQuery] es por campos, así que basta con que los
  // puntos coincidan: una única tupla origen/destino para todo el lote.
  const placeOrigin = JourneyPlacePoint(lat: -17.78, lon: -63.18);
  const placeDestination = JourneyPlacePoint(lat: -17.75, lon: -63.14);
  const query = JourneyQuery(
    origin: placeOrigin,
    destination: placeDestination,
  );

  JourneyOption option(String hour) => JourneyOption(
    type: JourneyType.direct,
    departAt: '08:00:00$hour',
    arriveAt: '08:30:00',
    durationMinutes: 30,
    legs: const [],
  );

  // ------------------------------------------------------------------
  // Fake del fetch: un completer por consulta → el test decide cuándo
  // llega la respuesta (loading suspendido) o cuándo falla.
  // ------------------------------------------------------------------
  late Map<JourneyQuery, Completer<List<JourneyOption>>> completers;
  final calls = <JourneyQuery>[];
  final journeyFake = journeyProvider.overrideWith((ref, q) {
    calls.add(q);
    return (completers[q] ??= Completer()).future;
  });

  late ProviderContainer container;
  setUp(() {
    completers = {};
    container = ProviderContainer(overrides: [journeyFake]);
    addTearDown(container.dispose);
    calls.clear();
    // Listener vivo para todo el test: sin él, el elemento del provider
    // muere/recicla entre pasos (nadie lo observa) y con él se pierden los
    // campos del caché del Notifier. En la app real la pantalla siempre lo
    // watchea — aquí replicamos esa condición del mundo real.
    container.listen(journeyResultsProvider, (_, _) {});
  });

  /// Deja el planner en modo resultados con el fetch EN CURSO (loading) y
  /// devuelve la vista recién leída.
  JourneyResultsView givenSubmitted() {
    final planner = container.read(journeyPlannerControllerProvider.notifier);
    planner.setPlace(placeOrigin, isOrigin: true);
    planner.setPlace(placeDestination, isOrigin: false);
    planner.submit();
    final view = container.read(journeyResultsProvider);
    expect(view.query, query);
    return view;
  }

  JourneyResultsNotifier resultsNotifier() =>
      container.read(journeyResultsProvider.notifier);

  test('sin envío: modo exploración (query y options en null)', () {
    final v = container.read(journeyResultsProvider);
    expect(v.query, isNull);
    expect(v.options, isNull);
    expect(v.hasResults, isFalse);
    expect(v.bare, isFalse);
    expect(v.replanning, isFalse);
  });

  test(
    'submit sin respuesta: consulta activa, sin hoja, mapa en «pines solo»',
    () {
      expect(givenSubmitted().options, isNull);
      final v = container.read(journeyResultsProvider);
      expect(v.hasResults, isFalse);
      expect(v.mapOption.type, JourneyType.direct);
      expect(v.mapOption.legs, isEmpty);
    },
  );

  test(
    'respuesta fresca de la consulta actual se adopta (hoja + mapa)',
    () async {
      givenSubmitted();
      completers[query]!.complete([option('1'), option('2')]);
      await container.pump();

      final v = container.read(journeyResultsProvider);
      expect(v.options, hasLength(2));
      expect(v.selectedIndex, 0);
      expect(v.mapOption.departAt, '08:00:001');
      // plan == campos aquí: el mapa sale de la query comprometida.
      expect(v.mapOrigin!.lat, placeOrigin.lat);
      expect(v.mapDestination!.lon, placeDestination.lon);
    },
  );

  test(
    'drop del pin: campos por delante del plan + caché conserva + replanning',
    () async {
      givenSubmitted();
      completers[query]!.complete([option('1')]);
      await container.pump();

      const dragged = LatLng(-17.77, -63.17);
      container
          .read(journeyPlannerControllerProvider.notifier)
          .endpointDragged(isOrigin: true, point: dragged);
      container.pump();

      final v = container.read(journeyResultsProvider);
      expect(v.replanning, isTrue); // replanPending
      expect(v.options, isNotNull); // caché conservado durante el replan
      expect(v.mapOrigin!.lat, dragged.latitude); // el pin sigue el dedo
    },
  );

  test('replan comprometido conserva el caché hasta la respuesta nueva', () async {
    givenSubmitted();
    completers[query]!.complete([option('1')]);
    await container.pump();

    // El debounce real es parte del controller: aquí replicamos SU callback
    // (commit del plan tras el drop, sin matar submitted) con copyWith
    // directo, para probar SOLO la regla del caché.
    const dropped = JourneyPlacePoint(lat: -17.77, lon: -63.17);
    final planner = container.read(journeyPlannerControllerProvider.notifier);
    planner.state = planner.state.copyWith(
      planOrigin: dropped,
      replanPending: false,
      selectedOptionIndex: 0,
    );
    container.pump();

    const replanQuery = JourneyQuery(
      origin: dropped,
      destination: placeDestination,
    );
    final v = container.read(journeyResultsProvider);
    expect(v.query, replanQuery);
    // ignore: avoid_print
    print(
      'probe Q=${v.query} opts=${v.options} replan=${v.replanning} calls=${calls.length}',
    );
    expect(v.options, isNotNull); // caché VIEJO aún visible
    expect(v.replanning, isTrue); // fetch de la consulta nueva en vuelo

    completers[replanQuery]!.complete([option('9')]);
    await container.pump();
    final v2 = container.read(journeyResultsProvider);
    expect(v2.options!.single.departAt, '08:00:009');
    expect(v2.mapOption.departAt, '08:00:009');
    expect(v2.replanning, isFalse);
  });

  test(
    'nuevo extremo/solución: setPlace limpia submitted y el caché muere',
    () async {
      givenSubmitted();
      completers[query]!.complete([option('1')]);
      await container.pump();
      expect(container.read(journeyResultsProvider).hasResults, isTrue);

      // setPlace pone submitted:false → consulta nula → caché fuera
      // (equivalente al antiguo _discardCachedOptions()).
      container
          .read(journeyPlannerControllerProvider.notifier)
          .setPlace(placeOrigin, isOrigin: true);
      container.pump();

      final v = container.read(journeyResultsProvider);
      expect(v.query, isNull);
      expect(v.options, isNull);
      expect(v.hasResults, isFalse);
      expect(v.replanning, isFalse);
    },
  );

  test('nueva hora («llegar antes») también descarta el caché', () async {
    givenSubmitted();
    completers[query]!.complete([option('1')]);
    await container.pump();

    container.read(journeyPlannerControllerProvider.notifier).setTime('07:00');
    container.pump();

    expect(container.read(journeyResultsProvider).options, isNull);
  });

  test('swap y clear sueltan «vuelvo cero» con el caché fuera', () async {
    givenSubmitted();
    completers[query]!.complete([option('1')]);
    await container.pump();

    final planner = container.read(journeyPlannerControllerProvider.notifier);
    planner.swap();
    container.pump();
    expect(container.read(journeyResultsProvider).options, isNull);

    planner.setPlace(placeOrigin, isOrigin: true);
    planner.setPlace(placeDestination, isOrigin: false);
    completers[query] = Completer(); // fetch nuevo → completer fresco
    planner.submit();
    container.pump();
    completers[query]!.complete([option('2')]); // la respuesta "nueva"
    await container.pump();
    expect(container.read(journeyResultsProvider).hasResults, isTrue);

    planner.clear();
    container.pump();
    final v = container.read(journeyResultsProvider);
    expect(v.options, isNull);
    expect(v.query, isNull);
  });

  test('selectedIndex se acota a la lista vigente', () async {
    givenSubmitted();
    completers[query]!.complete([option('1'), option('2')]);
    await container.pump();

    final planner = container.read(journeyPlannerControllerProvider.notifier);
    planner.selectOption(5); // fuera de rango
    expect(
      container.read(journeyResultsProvider).selectedIndex,
      1, // clamp a la última
    );
    planner.selectOption(0);
    expect(container.read(journeyResultsProvider).selectedIndex, 0);
  });

  test(
    'replan por drag falla: refreshFailed con el caché anterior visible',
    () async {
      givenSubmitted();
      completers[query]!.complete([option('1')]);
      await container.pump();

      // Replan: arriba el commit del debounce (copia del callback del
      // controller); la respuesta nueva FALLA sin valor previo.
      // El fetch de la respuesta nueva solo arranca en el próximo build de la
      // vista: dejamos el completer listo ANTES del commit.
      const dropped = JourneyPlacePoint(lat: -17.77, lon: -63.17);
      const replanQuery = JourneyQuery(
        origin: dropped,
        destination: placeDestination,
      );
      completers[replanQuery] = Completer();
      final planner = container.read(journeyPlannerControllerProvider.notifier);
      planner.state = planner.state.copyWith(
        planOrigin: dropped,
        replanPending: false,
        selectedOptionIndex: 0,
      );
      // El completer YA está observado (la vista lo consume con el build): a
      // partir de aquí un completeError es un error manejado, no fugado.
      await container.pump();
      completers[replanQuery]!.completeError('backend abajo');
      await container.pump();

      final v = container.read(journeyResultsProvider);
      expect(v.options, isNotNull); // caché vivo
      expect(v.refreshFailed, isTrue);
      expect(v.mapOption.departAt, '08:00:001'); // datos viejos
    },
  );

  test('fetch falla sin caché', () async {
    givenSubmitted();
    completers[query]!.completeError('backend abajo');
    await container.pump();

    final v = container.read(journeyResultsProvider);
    expect(v.options, isNull);
    expect(v.refreshFailed, isFalse);
  });

  test(
    'retryRefresh invalida la consulta vigente (y nada si no hay)',
    () async {
      givenSubmitted();
      completers[query]!.complete([option('1')]);
      await container.pump();

      completers.remove(query);
      resultsNotifier().retryRefresh();
      await container.pump();
      expect(
        container.read(journeyResultsProvider).replanning,
        isTrue,
      ); // nuevo fetch en vuelo sobre caché vivo

      // Sin consulta vigente: no debe lanzarse.
      container
          .read(journeyPlannerControllerProvider.notifier)
          .setPlace(placeOrigin, isOrigin: true);
      container.pump();
      completers.remove(query);
      resultsNotifier().retryRefresh(); // no-op tolerado
    },
  );
}
