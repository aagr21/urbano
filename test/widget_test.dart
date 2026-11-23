import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/network/api_client.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/home/data/stats.dart';
import 'package:urbano/src/features/home/presentation/home_providers.dart';
import 'package:urbano/src/features/home/presentation/home_screen.dart';
import 'package:urbano/src/features/home/presentation/widgets/home_header.dart';
import 'package:urbano/src/features/journey/application/trip_history_controller.dart';
import 'package:urbano/src/features/journey/data/trip_history.dart';
import 'package:urbano/src/features/journey/presentation/journey_planner_screen.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/routes/presentation/micros_screen.dart';
import 'package:urbano/src/features/routes/presentation/route_providers.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/fake_route_repository.dart';
import 'helpers/memory_trip_history_store.dart';

RouteSummary _route() => const RouteSummary(
  id: '101 ANGOSTURA',
  shortName: '101 ANGOSTURA',
  longName: 'Micro 101 ANGOSTURA',
  color: '7F8C8D',
  textColor: 'FFFFFF',
  description: 'Transporte publico urbano de micros',
  type: 3,
  directionsCount: 2,
  stopCount: 84,
  tripCount: 2,
);

List<Override> _overrides({TripHistoryStore? history}) => [
  statsProvider.overrideWith(
    (ref) async => const Stats(
      routes: 154,
      stops: 31461,
      trips: 308,
      shapes: 130105,
      service: ServiceWindow(
        start: '2026-10-06',
        end: '2027-10-06',
        days: 'diario',
      ),
      firstDeparture: '06:00:00',
      lastDeparture: '22:00:00',
      headwaySeconds: 300,
    ),
  ),
  myLocationProvider.overrideWith(
    (ref) async => const LatLng(-17.7833, -63.1821),
  ),
  routesListProvider.overrideWith(
    (ref, query) async =>
        Paged<RouteSummary>(items: [_route()], meta: const Meta(total: 154)),
  ),
  globalSearchProvider.overrideWith(
    (ref, query) async => GlobalSearchResult(
      routes: Paged<RouteSummary>(
        items: [_route()],
        meta: const Meta(total: 1),
      ),
    ),
  ),
  // El mini mapa del home no debe pedir geometrías en los tests.
  featuredRouteShapeProvider.overrideWith((ref) async => null),
  // Historial de viajes sin plugins: el home lo lee al montarse.
  tripHistoryControllerProvider.overrideWith(
    () => TripHistoryController(history ?? MemoryTripHistoryStore()),
  ),
];

/// Abre el menú principal desde el botón de la rama que se está viendo.
///
/// El shell mantiene las tres ramas montadas, así que el árbol puede tener
/// varios botones de menú a la vez: `.hitTestable()` deja solo el de la rama
/// visible (el resto está bajo el `IndexedStack`). La rama Viaje ya no tiene
/// menú: su vuelta al inicio es la flecha `journey-back-button`.
Future<void> _openMenu(WidgetTester tester) async {
  for (final key in const ['home-menu-button', 'complaints-menu-button']) {
    final finder = find.byKey(ValueKey(key)).hitTestable();
    if (finder.evaluate().isEmpty) continue;
    await tester.tap(finder);
    await tester.pumpAndSettle();
    return;
  }
  fail('No hay ningún botón de menú visible');
}

/// Cambia de sección por el menú (la barra inferior ya no existe).
Future<void> _goTo(WidgetTester tester, String section) async {
  // Viaje no tiene menú: se sale por su flecha de volver a Inicio antes de
  // abrir el menú de la portada.
  final back = find.byKey(const ValueKey('journey-back-button')).hitTestable();
  if (back.evaluate().isNotEmpty) {
    await tester.tap(back);
    await tester.pumpAndSettle();
  }
  await _openMenu(tester);
  await tester.tap(find.byKey(ValueKey('menu-item-$section')));
  await tester.pumpAndSettle();
}

/// Repo de rutas sin red: el panel de micros pagina `/routes` al abrirse.
Widget _app() => ProviderScope(
  overrides: _overrides(),
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: const HomeScreen(),
  ),
);

void main() {
  testWidgets('Home muestra identidad y accesos con providers mock', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    // Identidad.
    expect(find.text('Urbano'), findsOneWidget);
    expect(find.text('Muévete por Santa Cruz'), findsOneWidget);

    // La cabecera abre con la banda oficial: escudo del municipio + la
    // píldora que firma la app como transporte del Gobierno Autónomo.
    expect(find.byKey(const ValueKey('home-official-band')), findsOneWidget);
    expect(find.text('Transporte Oficial'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/gobierno-santa-cruz.png')),
      findsOneWidget,
    );

    // El buscador se retiró con la poda de la portada: ya no hay campo de
    // texto en Inicio (el catálogo se abre desde el acceso Micros).
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Busca rutas…'), findsNothing);

    // Portada con los cuatro accesos de la referencia.
    expect(find.byKey(const ValueKey('home-tile-micros')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-tile-journey')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-tile-places')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-tile-complaints')), findsOneWidget);
    expect(find.text('Micros'), findsOneWidget);
    expect(find.text('Viajes'), findsOneWidget);
    expect(find.text('Lugares'), findsOneWidget);
    expect(find.text('Denuncias'), findsOneWidget);

    // Barra de destino: el gesto principal del home. Con la retícula compacta
    // entra en el viewport de test (600 lógicos) sin bajar la lista.
    expect(find.text('¿A dónde vas?'), findsOneWidget);
    expect(find.text('Marca tu destino y listo'), findsOneWidget);

    // Sin historial, «Tus viajes recientes» no ocupa espacio.
    expect(find.text('Tus viajes recientes'), findsNothing);

    // La cola que antes bajaba del pliegue (banner vivo, tirilla de micros y
    // mini mapa) ya no forma parte de la portada.
    expect(find.text('Santa Cruz en movimiento'), findsNothing);
    expect(find.text('Tus micros'), findsNothing);
    expect(find.text('Explora Santa Cruz en el mapa'), findsNothing);
    expect(find.text('31.461'), findsNothing);
    expect(find.text('Cerca de mí'), findsNothing);

    // Deja que el kit de motion termine (Reveal de las secciones).
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('la banda oficial cabe a ancho real de móvil', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HomeHeader()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Escudo a la izquierda y píldora a la derecha, sin desbordar la franja
    // en el viewport más ajustado (393 lógicos): es lo primero que se pinta.
    final seal = tester.getRect(
      find.image(const AssetImage('assets/images/gobierno-santa-cruz.png')),
    );
    final pill = tester.getRect(find.text('Transporte Oficial'));
    expect(seal.left, lessThan(pill.left), reason: 'escudo · píldora');
    expect(seal.height, greaterThan(20));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('los cuatro accesos pintan su acento sin cristal', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(theme: AppTheme.dark(), home: const HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Cada tarjeta pinta su acento como degradado tonal sobre la superficie
    // del tema, con borde sutil y sombra. La guarda ya no exige un color
    // plano: el degradado es justamente lo que da profundidad, y el borde
    // confirma que el acento sigue ahí.
    for (final key in const [
      'home-tile-micros',
      'home-tile-journey',
      'home-tile-places',
      'home-tile-complaints',
    ]) {
      final tile = find.byKey(ValueKey(key));

      // No hay BackdropFilter — nada de cristal en los accesos.
      expect(
        find.descendant(of: tile, matching: find.byType(BackdropFilter)),
        findsNothing,
        reason: '$key no debe tener BackdropFilter',
      );

      // El primer Container es la superficie con el degradado del acento.
      final surfaceContainer = tester.widget<Container>(
        find.descendant(of: tile, matching: find.byType(Container)).first,
      );
      final decoration = surfaceContainer.decoration! as BoxDecoration;
      expect(
        decoration.gradient,
        isA<LinearGradient>(),
        reason: '$key debe tener un degradado tonal',
      );
      expect(
        (decoration.gradient! as LinearGradient).colors.length,
        greaterThanOrEqualTo(2),
        reason: '$key debe mezclar dos pasos del acento',
      );

      // El borde sutil confirma el acento visible.
      expect(
        decoration.border,
        isNotNull,
        reason: '$key debe tener borde de acento',
      );
    }

    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
    'el menú reemplaza a la barra inferior y conserva las tres ramas',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          ..._overrides(),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Ya no hay barra inferior: la navegación vive en el menú de la cabecera.
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const ValueKey('home-menu-button')), findsOneWidget);

      // El menú lista las tres secciones (y «Acerca de»).
      await tester.tap(find.byKey(const ValueKey('home-menu-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-item-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-item-journey')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('menu-item-complaints')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('menu-item-info')), findsOneWidget);

      // Viaje: cambia de rama y aterriza en el mapa con la píldora cerrada.
      await tester.tap(find.byKey(const ValueKey('menu-item-journey')));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/journey');
      expect(find.byKey(const ValueKey('planner-trigger')), findsOneWidget);
      expect(find.textContaining('Marca origen y destino'), findsOneWidget);

      // /map redirige por seguridad a /journey (la pantalla-mapa única).
      router.go('/map');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('planner-trigger')), findsOneWidget);
      expect(
        find.text('Marca un punto en el mapa o usa tu ubicación'),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('el acceso Micros del home abre el catálogo completo', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ..._overrides(),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        // El catálogo pagina `/routes` al abrirse: sin este doble habría red.
        routeRepositoryProvider.overrideWithValue(
          FakeRouteRepository([_route()]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // La sección vive bajo el borde inferior del viewport de test.
    await tester.ensureVisible(find.byKey(const ValueKey('home-tile-micros')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('home-tile-micros')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Pantalla propia: ya no es el cajón lateral de Viaje.
    // `push` agrega una página: el lugar real está en `state.uri`, no en la
    // configuración base del shell.
    expect(router.state.uri.path, '/micros');
    expect(find.text('Red Urbana de Micros'), findsOneWidget);
    expect(find.textContaining('Busca por número'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('micros-card-101 ANGOSTURA')),
      findsOneWidget,
    );
    expect(find.text('Ver recorrido'), findsOneWidget);

    // Cada tarjeta lleva al detalle de la línea.
    await tester.tap(find.text('Ver recorrido'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/routes/101%20ANGOSTURA');
    expect(find.text('101 ANGOSTURA'), findsWidgets);
  });

  testWidgets(
    '«¿A dónde vas?» del home abre el sheet de origen/destino (como Viajes)',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          ..._overrides(),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.ensureVisible(find.text('Marca tu destino y listo'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Marca tu destino y listo'));
      await tester.pumpAndSettle();

      // Se abre el sheet de origen/destino (modal), no se navega a /journey.
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        isNot('/journey'),
      );
      expect(find.text('Origen'), findsOneWidget);
      expect(find.text('Destino'), findsOneWidget);
      expect(find.text('Planificar viaje'), findsNWidgets(2)); // título + botón
    },
  );

  testWidgets('volver desde Micros regresa a Inicio sin dejar copias', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ..._overrides(),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        routeRepositoryProvider.overrideWithValue(
          FakeRouteRepository([_route()]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.ensureVisible(find.byKey(const ValueKey('home-tile-micros')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('home-tile-micros')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.state.uri.path, '/micros');

    // La flecha del header vuelve: el catálogo se empuja sobre el shell.
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).hitTestable());
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    expect(find.byType(MicrosScreen), findsNothing);

    // Reabrirlo entra UNA pantalla, no una copia apilada.
    await tester.ensureVisible(find.byKey(const ValueKey('home-tile-micros')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('home-tile-micros')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MicrosScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('cambiar de pestaña funde el cuerpo en vez de un tijeretazo', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ..._overrides(),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // El `FadeTransition` del cuerpo es el más somero bajo el shell (`.first`,
    // no `.last`: más abajo hay fundidos de `Reveal`/`AnimatedSwitcher` que no
    // son la transición de pestaña).
    double bodyOpacity() => tester
        .widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(UrbanoShell),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    expect(bodyOpacity(), 1, reason: 'en reposo el cuerpo se pinta entero');

    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('menu-item-journey')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      bodyOpacity(),
      lessThan(1),
      reason: 'a media transición el cuerpo todavía está fundiéndose',
    );

    await tester.pumpAndSettle();
    expect(bodyOpacity(), 1);
    // Idas y vueltas: el fundido anima al padre, no reconstruye las ramas, así
    // que la pantalla del planner sigue siendo el MISMO `Element` (la regla del
    // mapa siempre montado no puede romperse por meter una transición).
    final planner = tester.element(find.byType(JourneyPlannerScreen));
    await _goTo(tester, 'home');
    await _goTo(tester, 'journey');
    expect(
      tester.element(find.byType(JourneyPlannerScreen)),
      same(planner),
      reason: 'cambiar de sección no debe remontar el mapa',
    );
  });

  testWidgets(
    'el historial del home muestra el último viaje y abre el sheet de destino',
    (tester) async {
      final store = MemoryTripHistoryStore([
        TripHistoryEntry(
          label: 'Plaza 24 de Septiembre',
          subtitle: 'Centro histórico',
          lat: -17.7833,
          lon: -63.1821,
          lastUsed: DateTime.now().subtract(const Duration(hours: 2)),
          durationMinutes: 8,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          ..._overrides(history: store),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // La sección aparece con el destino y la duración de la última vez. La
      // tarjeta queda bajo el pliegue del viewport de test.
      await tester.scrollUntilVisible(
        find.text('Tus viajes recientes'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Tus viajes recientes'), findsOneWidget);
      expect(find.text('Plaza 24 de Septiembre'), findsOneWidget);
      expect(find.text('8 min'), findsOneWidget);

      // Tocar la fila abre el sheet de destino modal (no navega a /journey).
      await tester.ensureVisible(find.text('Plaza 24 de Septiembre'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Plaza 24 de Septiembre'));
      await tester.pumpAndSettle();

      // No navega a /journey: el sheet se abre en la portada.
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      // El sheet de destino aparece con el destino pre-llenado.
      expect(find.text('Plaza 24 de Septiembre'), findsWidgets);
    },
  );
}
