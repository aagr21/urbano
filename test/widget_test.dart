import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/network/api_client.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/home/data/stats.dart';
import 'package:urbano/src/features/home/presentation/home_providers.dart';
import 'package:urbano/src/features/home/presentation/home_screen.dart';
import 'package:urbano/src/features/journey/presentation/journey_planner_screen.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/routes/presentation/route_providers.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/fake_route_repository.dart';

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

List<Override> _overrides() => [
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
];

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
  testWidgets('Home muestra identidad, stats y accesos con providers mock', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    // Identidad.
    expect(find.text('Urbano'), findsOneWidget);
    expect(find.text('Muévete por Santa Cruz'), findsOneWidget);

    // Buscador (solo rutas: las paradas se retiraron de la app).
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
      'Busca rutas…',
    );

    // Servicio de hoy (frecuencia + ventana de salida del feed, sin la
    // píldora de paradas ni stats de dashboard).
    expect(find.text('154 líneas · diario'), findsOneWidget);
    expect(find.text('31.461'), findsNothing);

    // Accesos rápidos (Mapa se fusionó con Viaje: la pestaña es el mapa).
    expect(find.text('Cerca de mí'), findsNothing);
    expect(find.text('Viajar'), findsOneWidget);

    // Tirilla de micros por color con el título nueva marca.
    expect(find.text('Tus micros'), findsOneWidget);
    expect(find.text('101 ANGOSTURA'), findsOneWidget);
    expect(find.text('Micro 101 ANGOSTURA'), findsOneWidget);

    // Tarjeta destacada con mapa: quedó bajo la tirilla, entra con scroll.
    await tester.scrollUntilVisible(
      find.text('Explora Santa Cruz en el mapa'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Explora Santa Cruz en el mapa'), findsOneWidget);

    // Deja que el kit de motion termine (Reveal de las secciones + CountUp de
    // las stats), que es lo que antes hacía `flutter_animate` aquí.
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('Home muestra resultados en vivo al buscar (debounced)', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField), 'angostura');
    // El debounce dispara a los 350 ms.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Rutas'), findsWidgets);
    expect(find.text('Micro 101 ANGOSTURA'), findsOneWidget);

    // Al limpiar vuelve el contenido principal.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tus micros'), findsOneWidget);

    // Deja que el kit de motion termine (Reveal de las secciones + CountUp de
    // las stats), que es lo que antes hacía `flutter_animate` aquí.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
    'El shell muestra 2 pestañas (Rutas fusionada en el panel de Viaje)',
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

      // 2 pestañas: Inicio · Viaje (Cerca se retiró con las paradas y Rutas se
      // fusionó en el panel de micros de /journey).
      final navBar = find.byType(NavigationBar);
      expect(
        find.descendant(of: navBar, matching: find.text('Inicio')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Rutas')),
        findsNothing,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Cerca')),
        findsNothing,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Viaje')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Mapa')),
        findsNothing,
      );

      // /map redirige por seguridad a /journey (la pantalla-mapa única).
      router.go('/map');
      await tester.pumpAndSettle();
      // El panel de origen/destino arranca cerrado: se anuncia con la píldora.
      expect(find.byKey(const ValueKey('planner-trigger')), findsOneWidget);
      expect(find.textContaining('Marca origen y destino'), findsOneWidget);
      expect(
        find.text('Marca un punto en el mapa o usa tu ubicación'),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    '«Ver todas» del home abre el panel de micros en Viaje (no una ruta muerta)',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          ..._overrides(),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
          // El panel pagina `/routes` al abrirse: sin este doble habría red.
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
      await tester.ensureVisible(find.text('Ver todas'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Ver todas'));

      // Cambio de rama → la bandera se consume en el frame siguiente → el
      // cajón se desliza (280 ms) sobre el mapa de `/journey`.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 400));

      // No cae en el `errorBuilder`: `/routes` (la antigua lista) ya no existe.
      expect(find.text('Pantalla no encontrada'), findsNothing);
      // Aterrizó en la pestaña Viaje (branch 1 del shell).
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(router.routerDelegate.currentConfiguration.uri.path, '/journey');
      // El catálogo completo de líneas es el panel de micros: buscador, acciones
      // y la tarjeta de la única línea del falso repositorio.
      expect(find.text('Buscar línea…'), findsOneWidget);
      expect(find.text('Activar todas'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('micro-tile-101 ANGOSTURA')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'reabrir «Ver todas» REPLACES the micros panel (does not stack another drawer)',
    (tester) async {
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

      // Primera apertura desde Inicio.
      await tester.ensureVisible(find.text('Ver todas'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Ver todas'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey('micro-tile-101 ANGOSTURA')),
        findsOneWidget,
      );

      // El usuario da al tab Inicio con el cajón EN PIE: la rama Viaje
      // conserva su stack (y el panel dentro de él).
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('micro-tile-101 ANGOSTURA')),
        findsNothing,
      );

      // Segunda apertura: el panel viejo debe salir del stack y entrar UNO
      // (regresión: antes se apilaban y al cerrar aparecía otro igual).
      await tester.ensureVisible(find.text('Ver todas'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Ver todas'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const ValueKey('micro-tile-101 ANGOSTURA')),
        findsOneWidget,
        reason: 'solo un cajón: el nuevo reemplaza al que quedó',
      );

      await tester.pump(const Duration(seconds: 1));
    },
  );

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

    await tester.tap(find.text('Viaje'));
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
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viaje'));
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byType(JourneyPlannerScreen)),
      same(planner),
      reason: 'cambiar de pestaña no debe remontar el mapa',
    );
  });
}
