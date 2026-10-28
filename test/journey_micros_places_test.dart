import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/map/map_types.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/journey/presentation/journey_planner_controller.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';
import 'package:urbano/src/features/journey/presentation/map_picker_screen.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_micros_sheet.dart';
import 'package:urbano/src/features/journey/presentation/widgets/micros_places_list.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/stops/data/stop_search_models.dart';
import 'package:urbano/src/features/stops/data/stop_search_repository.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/fake_route_repository.dart';

class FakeStopSearchRepository implements StopSearchRepository {
  FakeStopSearchRepository(this.hits);

  final List<StopHit> hits;
  final List<String> calls = [];

  @override
  Future<List<StopHit>> search(String q) async {
    calls.add('q=$q');
    return hits;
  }

  @override
  Future<List<StopHit>> nearby({
    required double lat,
    required double lon,
  }) async {
    calls.add('nearby=$lat,$lon');
    return hits;
  }
}

StopHit _hit(String name, List<StopRouteRef> routes, {double? distance}) =>
    StopHit(
      id: 'S${name.hashCode}',
      name: name,
      lat: -17.78,
      lon: -63.16,
      routes: routes,
      distanceMeters: distance,
    );

const _micros = [
  StopRouteRef(id: '41', shortName: '41', color: 'D35400'),
  StopRouteRef(id: '60', shortName: '60', color: '27AE60'),
];

const _grid = ['41', '60'];

RouteSummary _route(String shortName) => RouteSummary(
  id: shortName,
  shortName: shortName,
  longName: 'Línea $shortName · Centro',
  color: '2980B9',
  textColor: 'FFFFFF',
  description: 'Transporte publico urbano de micros',
  type: 3,
  directionsCount: 2,
  stopCount: 10,
  tripCount: 1,
);

/// Harness del panel suelto: capta las claves activas, los toggles de recorrido
/// que delega el panel y los encuadres pedidos, para asertar el feature de
/// lugares (marcadores en el mapa + dibujar recorridos por resultado).
class _PanelHarness {
  _PanelHarness(ProviderContainer container)
    : _container = container,
      session = container.read(journeyMicrosSessionProvider);

  final ProviderContainer _container;
  final JourneyMicrosSession session;
  final List<String> toggleCalls = [];
  final List<List<({double lat, double lon})>> frames = [];

  /// Claves activas: viven en el controller (el panel las mira con watch).
  Set<String> get active =>
      _container.read(journeyPlannerControllerProvider).visibleRouteKeys;

  List<MapMarker> get placeMarkers =>
      _container.read(journeyPlannerControllerProvider).placeMarkers;

  void _setActive(Set<String> keys) {
    final notifier = _container.read(journeyPlannerControllerProvider.notifier);
    notifier.state = notifier.state.copyWith(visibleRouteKeys: keys);
  }

  void openPanel(WidgetRef ref) {
    unawaited(
      showJourneyMicrosPanel(
        ref.context,
        ref: ref,
        onToggleDirection: (micro, directionId) async {
          final key = '${micro.id}#$directionId';
          toggleCalls.add(key);
          _setActive({...active, key});
        },
        onClearAll: () {},
        onFramePlaces: frames.add,
      ),
    );
  }
}

Widget _app(FakeStopSearchRepository stopRepo, LatLng? me, _PanelHarness h) =>
    UncontrolledProviderScope(
      container: h._container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => h.openPanel(ref),
                child: const Text('abrir micros'),
              ),
            ),
          ),
        ),
      ),
    );

/// Abre el panel, cambia al modo Lugares y deja el estado listo. Devuelve el
/// contenedor para asertar el estado del planeador (marcadores).
Future<_PanelHarness> _openPlaces(
  WidgetTester tester,
  FakeStopSearchRepository stopRepo, {
  LatLng? me,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _PanelHarness(
    ProviderContainer(
      overrides: [
        routeRepositoryProvider.overrideWithValue(
          FakeRouteRepository(_grid.map(_route).toList()),
        ),
        stopSearchRepositoryProvider.overrideWithValue(stopRepo),
        myLocationProvider.overrideWith((ref) async => me),
      ],
    ),
  );
  addTearDown(harness._container.dispose);
  await tester.pumpWidget(_app(stopRepo, me, harness));
  await tester.tap(find.text('abrir micros'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lugares'));
  await tester.pumpAndSettle();
  return harness;
}

/// Confirma una consulta de lugares por texto.
Future<void> _commitSearch(WidgetTester tester, String q) async {
  await tester.tap(find.byType(TextField));
  await tester.enterText(find.byType(TextField), q);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

Future<void> _tapRouteToggle(WidgetTester tester, String routeId) async {
  await tester.tap(find.byKey(ValueKey('place-route-toggle-$routeId')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'modo Lugares: escribir + confirmar trae esquinas con sus líneas (sin GPS)',
    (tester) async {
      final repo = FakeStopSearchRepository([
        _hit('Avenida Cristo Redentor esquina Calle Sol', _micros),
        _hit('Terminal Bimodal esquina Cuarto Anillo', _micros),
      ]);
      await _openPlaces(tester, repo);

      // Guía inicial: «cerca de mí» o escribir; sin peticiones.
      expect(find.text('Cerca de mí'), findsOneWidget);

      // Commit: escribe y confirma con la acción de teclado «Buscar».
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'cristo');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(repo.calls, ['q=cristo']);
      expect(
        find.text('Avenida Cristo Redentor esquina Calle Sol'),
        findsOneWidget,
      );
      expect(
        find.text('Terminal Bimodal esquina Cuarto Anillo'),
        findsOneWidget,
      );

      // Las líneas de cada esquina aparecen como badges tappable.
      expect(find.text('41'), findsWidgets);
      expect(find.text('60'), findsWidgets);
    },
  );

  testWidgets('los resultados de lugares se clavan en el mapa y se encuadran', (
    tester,
  ) async {
    final repo = FakeStopSearchRepository([
      _hit('Avenida Cristo Redentor esquina Calle Sol', _micros),
      _hit('Terminal Bimodal esquina Cuarto Anillo', _micros),
    ]);
    final h = await _openPlaces(tester, repo);
    await _commitSearch(tester, 'cristo');

    // Un punto por parada devuelta (sin consulta de un punto fijo: es búsqueda
    // por texto), clavados en el controller del planeador — el mapa vive abajo
    // del cajón y los lee de ahí.
    expect(h.placeMarkers.map((m) => m.id), [
      'place-stop-S${'Avenida Cristo Redentor esquina Calle Sol'.hashCode}',
      'place-stop-S${'Terminal Bimodal esquina Cuarto Anillo'.hashCode}',
    ]);

    // Y el panel pidió encuadrar la cámara sobre esas paradas (el último
    // encuadre es el de los datos ya resueltos: durante la carga puede
    // haberse llamado con la lista vacía).
    final lastFrame = h.frames.last;
    expect(lastFrame, hasLength(2));
    expect(lastFrame.first.lat, -17.78);
  });

  testWidgets(
    'cada línea tiene su propio «Ver ruta» y se dibuja de forma independiente',
    (tester) async {
      final repo = FakeStopSearchRepository([
        _hit('Terminal Bimodal esquina Cuarto Anillo', _micros),
      ]);
      final h = await _openPlaces(tester, repo);
      await _commitSearch(tester, 'terminal');

      // Dos líneas del resultado = DOS botones «Ver ruta» (ya no es un único
      // botón global que encendía todo junto).
      expect(find.text('Ver ruta'), findsNWidgets(2));

      // Tocar la 41 delega SOLO su recorrido, y la bandera es «ver la ruta
      // entera»: dibuja ida (0) y vuelta (1), no una sola orientación.
      await _tapRouteToggle(tester, '41');
      expect(h.toggleCalls, ['41#0', '41#1']);
      expect(find.text('Ocultar'), findsOneWidget);
      // La 60 sigue independiente: todavía disponible.
      expect(find.text('Ver ruta'), findsOneWidget);

      // Encender la 60 añade su ruta por separado (las dos visibles).
      await _tapRouteToggle(tester, '60');
      expect(h.toggleCalls, ['41#0', '41#1', '60#0', '60#1']);
      expect(find.text('Ocultar'), findsNWidgets(2));

      // Apagar la 41 (ahora «Ocultar») retira solo ella: vuelve a invertir
      // sus dos direcciones, la 60 queda intacta.
      await _tapRouteToggle(tester, '41');
      expect(h.toggleCalls, ['41#0', '41#1', '60#0', '60#1', '41#0', '41#1']);
    },
  );

  testWidgets('un resultado no muestra líneas repetidas', (tester) async {
    // El feed puede declarar la misma línea dos veces (dos trips/orientaciones).
    const duplicated = [
      StopRouteRef(id: '41', shortName: '41', color: 'D35400'),
      StopRouteRef(id: '41', shortName: '41', color: 'D35400'),
      StopRouteRef(id: '60', shortName: '60', color: '27AE60'),
    ];
    final repo = FakeStopSearchRepository([
      _hit('Terminal Bimodal esquina Cuarto Anillo', duplicated),
    ]);
    await _openPlaces(tester, repo);
    await _commitSearch(tester, 'terminal');

    // La 41 iba duplicada: un solo badge y UN solo toggle por línea.
    expect(find.text('41'), findsOneWidget);
    expect(find.byKey(const ValueKey('place-route-toggle-41')), findsOneWidget);
    expect(find.byKey(const ValueKey('place-route-toggle-60')), findsOneWidget);
  });

  testWidgets('limpiar la búsqueda retira los marcadores del mapa', (
    tester,
  ) async {
    final repo = FakeStopSearchRepository([
      _hit('Terminal Bimodal esquina Cuarto Anillo', _micros),
    ]);
    final h = await _openPlaces(tester, repo);
    await _commitSearch(tester, 'terminal');
    expect(h.placeMarkers, isNotEmpty);

    // La «x» del buscador de lugares borra borrador + consulta y limpia los
    // pines clavados (los recorridos dibujados quedan: esos los apaga
    // «Limpiar» del modo líneas).
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    expect(h.placeMarkers, isEmpty);
    expect(find.text('Cerca de mí'), findsOneWidget);
  });

  testWidgets('el buscador de lugares ofrece «Marcar en el mapa»', (
    tester,
  ) async {
    final repo = FakeStopSearchRepository(const []);
    await _openPlaces(tester, repo);
    // Además de escribir o «cerca de mí», el sufijo del campo permite clavar
    // el lugar directamente sobre el mapa.
    expect(find.byTooltip('Marcar en el mapa'), findsOneWidget);
  });

  testWidgets(
    'marcar el lugar en el mapa consulta los alrededores y clava su pin',
    (tester) async {
      final repo = FakeStopSearchRepository([
        _hit('Terminal Bimodal esquina Cuarto Anillo', _micros),
      ]);
      final harness = _PanelHarness(
        ProviderContainer(
          overrides: [
            routeRepositoryProvider.overrideWithValue(
              FakeRouteRepository(_grid.map(_route).toList()),
            ),
            stopSearchRepositoryProvider.overrideWithValue(repo),
            myLocationProvider.overrideWith(
              (ref) async => const LatLng(-17.7833, -63.1821),
            ),
            locationServiceProvider.overrideWithValue(FakeLocationService()),
          ],
        ),
      );
      addTearDown(harness._container.dispose);
      harness.session.placesMode = true;

      // GoRouter REAL con la home del panel de pruebas: el push del botón
      // resuelve la URL `/journey/pick` de verdad (mismo selector que
      // origen/destino) y el pop entrega el punto al panel.
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => harness.openPanel(ref),
                    child: const Text('abrir micros'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/journey/pick',
            name: 'journey-pick',
            builder: (context, state) {
              final params = state.uri.queryParameters;
              final lat = double.tryParse(params['lat'] ?? '');
              final lon = double.tryParse(params['lon'] ?? '');
              return MapPickerScreen(
                title: params['title'] ?? 'Punto en el mapa',
                initial: lat != null && lon != null
                    ? (lat: lat, lon: lon)
                    : null,
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness._container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text('abrir micros'));
      await tester.pumpAndSettle();

      // Tap en el botón del buscador: se abre el selector con su título…
      await tester.tap(find.byTooltip('Marcar en el mapa'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MapPickerScreen>(find.byType(MapPickerScreen)).title,
        'Lugar',
      );

      // …se mueve el mapa (pin fijo al centro) y se confirma: el pop entrega
      // el punto al panel, que lo usa como lugar a consultar (el equivalente
      // a un «cerca de mí» en el punto clavado).
      final pickerEngine = tester.state<FakeMapEngineState>(
        find.descendant(
          of: find.byType(MapPickerScreen),
          matching: find.byType(FakeMapEngine),
        ),
      );
      pickerEngine.moveCamera(const LatLng(-17.79, -63.17), 15);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este punto'));
      await tester.pumpAndSettle();

      expect(find.byType(MapPickerScreen), findsNothing);
      expect(repo.calls, ['nearby=-17.79,-63.17']);
      expect(
        find.text('Terminal Bimodal esquina Cuarto Anillo'),
        findsOneWidget,
      );

      // El punto marcado queda clavado (pin propio + sus paradas) y encuadrado.
      expect(harness.placeMarkers.map((m) => m.id), [
        'place-search-point',
        'place-stop-S${'Terminal Bimodal esquina Cuarto Anillo'.hashCode}',
      ]);
      expect(harness.frames, isNotEmpty);
      expect(harness.frames.last.first, (lat: -17.79, lon: -63.17));

      // Y salir del modo lugares limpia sus marcadores.
      await tester.tap(find.text('Líneas'));
      await tester.pumpAndSettle();
      expect(harness.placeMarkers, isEmpty);
    },
  );

  testWidgets('sin texto y sin GPS: guía, sin resultados fantasma', (
    tester,
  ) async {
    final repo = FakeStopSearchRepository(const []);
    final h = await _openPlaces(tester, repo);
    // No hay consultas de red todavía: la guía manda hasta intención.
    expect(repo.calls, isEmpty);
    expect(find.text('Cerca de mí'), findsOneWidget);
    // Y el mapa del planeador queda limpio: nada clavado sin consulta.
    expect(h.placeMarkers, isEmpty);
  });

  testWidgets(
    'una fila por línea nunca desborda el panel (nombre/ruta largos, muchas '
    'líneas, ancho angosto)',
    (tester) async {
      // El badge de cada línea solía ser hijo no-flexible del Row: con un
      // `shortName` largo su texto se layout con ancho ilimitado (sin ellipsis)
      // y empujaba el chip «Ver ruta» fuera del panel -> RenderFlex overflowed
      // on the right. Se fija que la fila se ajuste sin importar la cantidad ni
      // la longitud.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final hit = _hit(
        'Avenida Cristo Redentor esquina Universidad Tecnológica y Segundo '
        'Anillo',
        [
          for (var i = 0; i < 8; i++)
            StopRouteRef(
              id: 'r$i',
              shortName: 'TRINITARIA-BAJA GRANDES $i',
              color: 'D35400',
            ),
        ],
        distance: 1520,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            // Ancho del interior del panel (~272) menos paddings del tile.
            body: Center(
              child: SizedBox(
                width: 240,
                child: MicrosPlaceTile(
                  hit: hit,
                  activeKeys: const {},
                  busyKey: null,
                  locked: false,
                  onToggleRoute: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Ningún desbordamiento (RenderFlex) ni otra excepción de renderizado.
      expect(tester.takeException(), isNull);
      // Cada línea conserva su toggle visible/tappable.
      expect(
        find.byKey(const ValueKey('place-route-toggle-r0')),
        findsOneWidget,
      );
    },
  );
}
