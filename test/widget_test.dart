import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/network/api_client.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/theme/theme_mode_controller.dart';
import 'package:urbano/src/core/utils/location.dart';
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
import 'helpers/memory_theme_mode_store.dart';
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

/// Cambia de sección como lo hace la app sin menú: Viaje vuelve a Inicio por
/// su flecha y el resto de los saltos son los del router (los accesos de la
/// portada hacen exactamente ese `go`).
Future<void> _goTo(WidgetTester tester, GoRouter router, String path) async {
  final back = find.byKey(const ValueKey('journey-back-button')).hitTestable();
  if (path == '/' && back.evaluate().isNotEmpty) {
    await tester.tap(back);
  } else {
    router.go(path);
  }
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

  testWidgets('la cabecera mide lo mismo en claro y en oscuro', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    // La placa blanca del escudo en oscuro se pintaba como `padding` y hacía
    // crecer la banda 6 dp: toda la portada bajaba un pelín respecto de claro.
    Future<(Rect, Rect, Rect)> measure(ThemeData theme) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(),
          child: MaterialApp(
            theme: theme,
            home: const Scaffold(body: HomeHeader()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return (
        tester.getRect(find.byKey(const ValueKey('home-official-band'))),
        tester.getRect(
          find.image(const AssetImage('assets/images/gobierno-santa-cruz.png')),
        ),
        tester.getRect(find.byType(HomeHeader)),
      );
    }

    final (lightBand, lightSeal, lightHeader) = await measure(AppTheme.light());
    final (darkBand, darkSeal, darkHeader) = await measure(AppTheme.dark());

    expect(darkBand, lightBand, reason: 'la banda no crece en oscuro');
    expect(darkSeal, lightSeal, reason: 'el escudo no se mueve en oscuro');
    expect(darkHeader, lightHeader, reason: 'la cabecera no empuja la portada');

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
    'sin menú: el botón de la cabecera alterna claro/oscuro y lo persiste',
    (tester) async {
      final store = MemoryThemeModeStore(null);
      final container = ProviderContainer(
        overrides: [
          ..._overrides(),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
          themeModeStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: ref.watch(themeModeControllerProvider),
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Ni barra inferior ni menú: el botón de la cabecera es el del tema.
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const ValueKey('home-menu-button')), findsNothing);
      final toggle = find.byKey(const ValueKey('home-theme-button'));
      expect(toggle, findsOneWidget);

      Brightness brightness() =>
          Theme.of(tester.element(find.byType(HomeHeader))).brightness;

      // En claro ofrece la luna (ir a oscuro).
      expect(brightness(), Brightness.light);
      expect(find.byTooltip('Cambiar a tema oscuro'), findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(container.read(themeModeControllerProvider), ThemeMode.dark);
      expect(brightness(), Brightness.dark);
      expect(find.byTooltip('Cambiar a tema claro'), findsOneWidget);
      expect(store.lastSaved, ThemeMode.dark);

      // Y de vuelta a claro.
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(container.read(themeModeControllerProvider), ThemeMode.light);
      expect(brightness(), Brightness.light);
      expect(store.lastSaved, ThemeMode.light);

      // «Acerca de» ya no existe: su ruta cae en la pantalla de error.
      router.go('/info');
      await tester.pumpAndSettle();
      expect(find.text('Pantalla no encontrada'), findsOneWidget);

      // Viaje sigue accesible y /map redirige a /journey (la pantalla-mapa
      // única).
      router.go('/map');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, '/journey');
      expect(find.byKey(const ValueKey('planner-trigger')), findsOneWidget);
      expect(find.textContaining('Marca origen y destino'), findsOneWidget);

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
    expect(find.text('Red urbana de micros'), findsOneWidget);
    expect(find.textContaining('Busca por número'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('micros-card-101 ANGOSTURA')),
      findsOneWidget,
    );
    // Sin pie «Ver recorrido»: toda la tarjeta es el botón.
    expect(find.text('Ver recorrido'), findsNothing);

    // Cada tarjeta lleva al detalle de la línea.
    await tester.tap(find.text('Micro 101 ANGOSTURA').first);
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
      // El origen por defecto es «Mi ubicación»: el punto GPS queda por
      // detrás, pero el valor del campo nunca muestra coordenadas.
      expect(find.text('Mi ubicación'), findsOneWidget);
      expect(find.text('GPS'), findsOneWidget);
      expect(find.textContaining('-17.'), findsNothing);
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

    router.go('/journey');
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
    await _goTo(tester, router, '/');
    await _goTo(tester, router, '/journey');
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
