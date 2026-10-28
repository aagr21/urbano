import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/map/map_scene.dart';
import 'package:urbano/src/core/map/map_styles.dart';
import 'package:urbano/src/core/map/map_tile.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_colors.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/theme/map_theme_controller.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/core/widgets/map_tile_button.dart';
import 'package:urbano/src/core/widgets/urbano_map.dart';
import 'package:urbano/src/features/home/presentation/widgets/home_header.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';

import 'helpers/contrast.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';

/// Persistencia del tile del mapa en memoria (regla del repo: `flutter test`
/// nunca depende de plugins).
class MemoryMapThemeStore implements MapThemeStore {
  MemoryMapThemeStore([this._initial]);

  MapTile? _initial;
  MapTile? lastSaved;
  int saves = 0;

  @override
  Future<MapTile?> load() async {
    final value = _initial;
    _initial = null; // como un store real: la carga no es idempotente.
    return value;
  }

  @override
  Future<void> save(MapTile? tile) async {
    lastSaved = tile;
    saves++;
  }
}

/// Store que lanza al leer (simula una preferencia corrupta sin plugins).
class _BrokenMapThemeStore implements MapThemeStore {
  @override
  Future<MapTile?> load() async => throw Exception('store corrupta');

  @override
  Future<void> save(MapTile? tile) async {}
}

/// Colores del buscador de la cabecera, leídos del widget ya pintado.
typedef _HeaderField = ({
  Color border,
  Color glass,
  Color hint,
  Color icon,
  Color ink,
});

/// Tile efectivo del mapa para una combinación (mismo cálculo que [UrbanoMap]).
MapTile _effectiveTile({required bool appDark, MapTile? choice}) =>
    MapTile.resolve(appDark: appDark, choice: choice);

/// Brillo del mapa para una combinación: tile elegido o defecto del tema de la app.
bool _mapIsDark({required bool appDark, MapTile? choice}) =>
    _effectiveTile(appDark: appDark, choice: choice).brightness ==
    Brightness.dark;

/// Estilo (URL MapTiler) que debe resultar para un tile no-Google.
String _expectedStyle({required bool appDark, MapTile? choice}) =>
    _effectiveTile(appDark: appDark, choice: choice).staticStyle!;

void main() {
  group('MapThemeController (tile propio del mapa)', () {
    test(
      'sin preferencia guardada el mapa arranca siguiendo al tema de la app',
      () {
        final container = _container(MemoryMapThemeStore());
        addTearDown(container.dispose);

        expect(container.read(mapThemeControllerProvider), isNull);
      },
    );

    test('restaura en background el tile que el usuario eligió', () async {
      final container = _container(MemoryMapThemeStore(MapTile.dark));
      addTearDown(container.dispose);

      // Mientras la carga está en vuelo no hay tile fijado visible.
      expect(container.read(mapThemeControllerProvider), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(mapThemeControllerProvider), MapTile.dark);
    });

    // Regresión STYLE_NOT_READY: `main()` pre-carga la preferencia y la inyecta.
    // Si el controller la cambiara después, el mapa ya montado recibiría un
    // segundo `setStyleString` que compite con la carga del estilo nativo.
    test(
      'tile pre-cargado se aplica síncrono y no cambia en background',
      () async {
        final store = MemoryMapThemeStore(MapTile.osm);
        final container = _container(
          store,
          preload: true,
          preloaded: MapTile.osm,
        );
        addTearDown(container.dispose);

        expect(container.read(mapThemeControllerProvider), MapTile.osm);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(mapThemeControllerProvider), MapTile.osm);
      },
    );

    test('setTile fija el tile al instante y lo persiste', () {
      final store = MemoryMapThemeStore();
      final container = _container(store);
      addTearDown(container.dispose);

      container.read(mapThemeControllerProvider.notifier).setTile(MapTile.dark);

      expect(container.read(mapThemeControllerProvider), MapTile.dark);
      expect(store.lastSaved, MapTile.dark);
    });

    test('setTile con el valor que ya estaba no escribe en disco', () {
      final store = MemoryMapThemeStore(MapTile.osm);
      final container = _container(
        store,
        preload: true,
        preloaded: MapTile.osm,
      );
      addTearDown(container.dispose);

      container.read(mapThemeControllerProvider.notifier).setTile(MapTile.osm);

      expect(store.saves, isZero);
    });

    test('followAppTheme borra la elección y persiste el borrado', () {
      final store = MemoryMapThemeStore(MapTile.dark);
      final container = _container(
        store,
        preload: true,
        preloaded: MapTile.dark,
      );
      addTearDown(container.dispose);

      container.read(mapThemeControllerProvider.notifier).followAppTheme();

      expect(container.read(mapThemeControllerProvider), isNull);
      expect(store.lastSaved, isNull);
    });

    test(
      'una store corrupta no rompe: el mapa queda siguiendo al tema',
      () async {
        final container = ProviderContainer(
          overrides: [
            mapThemeStoreProvider.overrideWith((_) => _BrokenMapThemeStore()),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(mapThemeControllerProvider), isNull);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(mapThemeControllerProvider), isNull);
      },
    );

    test(
      'migra la preferencia antigua (bool oscuro/claro) a un tile',
      () async {
        SharedPreferences.setMockInitialValues({'urbano.map_theme_dark': true});
        expect(await SharedPreferencesMapThemeStore().load(), MapTile.dark);

        SharedPreferences.setMockInitialValues({
          'urbano.map_theme_dark': false,
        });
        expect(await SharedPreferencesMapThemeStore().load(), MapTile.osm);

        // Sin ninguna clave → `null` (sigue al tema de la app).
        SharedPreferences.setMockInitialValues({});
        expect(await SharedPreferencesMapThemeStore().load(), isNull);
      },
    );
  });

  group('Independencia tile/tema (el tile solo cambia el mapa)', () {
    test(
      'resolve: sin elección manda el brillo de la app; con ella, el tile',
      () {
        expect(MapTile.resolve(appDark: false), MapTile.osm);
        expect(MapTile.resolve(appDark: true), MapTile.dark);
        expect(
          MapTile.resolve(appDark: false, choice: MapTile.dark),
          MapTile.dark,
        );
        expect(
          MapTile.resolve(appDark: true, choice: MapTile.osm),
          MapTile.osm,
        );
        expect(
          MapTile.resolve(
            appDark: false,
            choice: MapTile.googleSatellite,
          ).brightness,
          Brightness.dark,
        );
      },
    );

    // El corazón de la independencia pedida por el usuario: «Oscuro» pinta el
    // mapa base oscuro, pero los botones/paneles siguen al tema de la app.
    testWidgets('mapa en Oscuro con app clara: solo el mapa se oscurece', (
      tester,
    ) async {
      await _pumpScope(tester, appDark: false, choice: MapTile.dark);

      final scene = _scene(tester);
      expect(scene.dark, isTrue);
      expect(scene.styleString, UrbanoMapStyles.dark);
      expect(scene.background, MapTile.dark.backgroundColor);
      // El chrome de la app NO se movió.
      expect(_appBrightness(tester), Brightness.light);
    });

    testWidgets('mapa en OSM con app oscura: la interfaz sigue oscura', (
      tester,
    ) async {
      await _pumpScope(tester, appDark: true, choice: MapTile.osm);

      final scene = _scene(tester);
      expect(scene.dark, isFalse);
      expect(scene.styleString, UrbanoMapStyles.light);
      expect(_appBrightness(tester), Brightness.dark);
    });

    testWidgets('sin elección el mapa hereda el brillo de la app', (
      tester,
    ) async {
      await _pumpScope(tester, appDark: true, choice: null);

      expect(_scene(tester).dark, isTrue);
      expect(_appBrightness(tester), Brightness.dark);
    });
  });

  group('Combinaciones app × tile en la pantalla Viaje', () {
    for (final appDark in [false, true]) {
      for (final choice in <MapTile?>[MapTile.osm, MapTile.dark, null]) {
        final mapLabel = switch (choice) {
          null => 'sin elección',
          MapTile.osm => 'OSM',
          MapTile.dark => 'Oscuro',
          _ => choice.name,
        };
        testWidgets('app ${appDark ? 'oscura' : 'clara'} con mapa $mapLabel', (
          tester,
        ) async {
          final store = MemoryMapThemeStore(choice);
          await _pumpPlanner(
            tester,
            appDark: appDark,
            choice: choice,
            store: store,
          );

          final expectedDark = _mapIsDark(appDark: appDark, choice: choice);
          final scene = _scene(tester);

          // 1. El estilo de los tiles sigue al mapa, no al tema de la app.
          expect(scene.dark, expectedDark);
          expect(
            scene.styleString,
            _expectedStyle(appDark: appDark, choice: choice),
          );

          // 2. Sin fugas hacia ningún lado: la pantalla entera conserva el
          //    brillo de la app. El chrome (tarjeta origen→destino, píldora de
          //    atribución, controles) NO se re-tematiza por elegir un tile.
          final appBrightness = appDark ? Brightness.dark : Brightness.light;
          final themeOnSurface = appDark
              ? AppTheme.dark().colorScheme.onSurface
              : AppTheme.light().colorScheme.onSurface;
          expect(_appBrightness(tester), appBrightness);
          expect(
            Theme.of(
              tester.element(
                find.text(
                  _effectiveTile(appDark: appDark, choice: choice).attribution,
                ),
              ),
            ).brightness,
            appBrightness,
          );

          // 3. Legibilidad del chrome: los overlays siguen al tema de la app
          //    sea cual sea el tile que pinte debajo (el lienzo del mapa es
          //    solo fondo), así que la tinta se mide contra su propio tema.
          expect(
            colorContrast(
              themeOnSurface,
              appDark
                  ? AppTheme.dark().colorScheme.surface
                  : AppTheme.light().colorScheme.surface,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'letra del overlay ilegible sobre su propio tema',
          );

          // 4. Nadie escribe en la store: el tile solo lo cambia el usuario.
          expect(store.saves, isZero);
        });
      }
    }
  });

  group('Selector de capa del mapa (UI)', () {
    testWidgets('abrir la hoja y elegir "Oscuro" fija la capa y persiste', (
      tester,
    ) async {
      final store = MemoryMapThemeStore();
      await _pumpPlanner(tester, appDark: false, choice: null, store: store);

      expect(_scene(tester).dark, isFalse);

      await tester.tap(find.byType(MapTileButton));
      await tester.pumpAndSettle();

      await tester.tap(_layerCard(MapTile.dark));
      await tester.pumpAndSettle();

      // El cruce pedido: mapa oscuro con app clara.
      expect(_scene(tester).dark, isTrue);
      expect(store.lastSaved, MapTile.dark);
      expect(_appBrightness(tester), Brightness.light);
    });

    testWidgets('hoja con app clara: legible con miniaturas oscuras enfrente', (
      tester,
    ) async {
      // Capa oscura fijada con app clara: las tarjetas se pintan con el tema de
      // la app (la miniatura oscura es solo un dibujo dentro de la tarjeta).
      await _pumpPlanner(
        tester,
        appDark: false,
        choice: MapTile.dark,
        store: MemoryMapThemeStore(MapTile.dark),
      );
      await _expectSheetCardsLegible(tester, appDark: false);
    });

    testWidgets('hoja con app oscura: misma regla, tinta clara', (
      tester,
    ) async {
      await _pumpPlanner(
        tester,
        appDark: true,
        choice: MapTile.osm,
        store: MemoryMapThemeStore(MapTile.osm),
      );
      await _expectSheetCardsLegible(tester, appDark: true);
    });

    testWidgets('Google se ve siempre: bloqueado sin clave, activo con clave', (
      tester,
    ) async {
      final store = MemoryMapThemeStore();
      await _pumpPlanner(tester, appDark: false, choice: null, store: store);

      await tester.tap(find.byType(MapTileButton));
      await tester.pumpAndSettle();

      // En test `Env.googleMapsApiKey` está vacío: las dos capas de Google están
      // visibles (ocultarlas era el bug) pero marcadas como no disponibles.
      expect(_layerCard(MapTile.googleRoadmap), findsOneWidget);
      expect(_layerCard(MapTile.googleSatellite), findsOneWidget);
      expect(find.text('Mapas'), findsOneWidget);
      expect(find.text('Satélite'), findsOneWidget);
      expect(find.text('Requiere clave'), findsNWidgets(2));
      expect(find.text('OpenStreetMap'), findsOneWidget);
      expect(find.text('MapTiler'), findsOneWidget);

      // Tocar una capa bloqueada NO elige nada ni cierra la hoja.
      await tester.tap(_layerCard(MapTile.googleSatellite));
      await tester.pumpAndSettle();

      expect(store.saves, isZero);
      expect(
        find.text('flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza…'),
        findsOneWidget,
      );
      expect(_scene(tester).dark, isFalse);
    });

    testWidgets('seguir el tema de la app borra la elección', (tester) async {
      final store = MemoryMapThemeStore(MapTile.dark);
      await _pumpPlanner(
        tester,
        appDark: false,
        choice: MapTile.dark,
        store: store,
      );

      await tester.tap(find.byType(MapTileButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Capa automática'));
      await tester.pumpAndSettle();

      expect(store.lastSaved, isNull);
      expect(_scene(tester).dark, isFalse); // vuelve a heredar el tema claro
    });

    testWidgets('cambiar el tema de la app no mueve la capa fijada del mapa', (
      tester,
    ) async {
      // Mapa fijado en CLARO (OSM) con app clara; después la app pasa a oscura.
      final container = await _pumpPlanner(
        tester,
        appDark: false,
        choice: MapTile.osm,
        store: MemoryMapThemeStore(MapTile.osm),
      );
      expect(_scene(tester).dark, isFalse);
      expect(_appBrightness(tester), Brightness.light);

      await tester.pumpWidget(_plannerApp(container, appDark: true));
      await tester.pumpAndSettle();

      // El chrome de la app SÍ se movió...
      expect(_appBrightness(tester), Brightness.dark);
      // ...el mapa se quedó donde lo dejó el usuario.
      expect(_scene(tester).dark, isFalse);
      expect(_scene(tester).styleString, UrbanoMapStyles.light);
    });
  });

  group('Buscador «Busca rutas…» de la cabecera', () {
    testWidgets(
      'letra, placeholder, ícono y borde son legibles sobre la marca',
      (tester) async {
        await _pumpHome(tester, appDark: false);

        final field = _readHeaderField(tester);
        // Fondo realmente pintado bajo el vidrio: `aqua`, el extremo MÁS CLARO del
        // degradado de marca y por tanto el peor caso para una tinta oscura.
        final bg = Color.lerp(AppColors.aqua, Colors.white, field.glass.a)!;

        expect(
          colorContrast(field.ink, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'la letra del buscador desaparece sobre la marca',
        );
        expect(
          colorContrast(field.hint, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'el placeholder no se lee',
        );
        expect(
          colorContrast(field.icon, bg),
          greaterThanOrEqualTo(3.0),
          reason: 'el ícono de búsqueda no se ve',
        );
        expect(
          colorContrast(field.border, bg),
          greaterThanOrEqualTo(3.0),
          reason: 'el borde del campo no marca dónde empieza',
        );
        // El vidrio es propio del campo: heredando el del tema oscuro (blanco al
        // 6%) el límite desaparecía sobre el verde.
        expect(field.glass.withValues(alpha: 1), Colors.white);
        expect(field.glass.a, greaterThanOrEqualTo(0.9));
      },
    );

    testWidgets('el campo es ancla de marca: idéntico con app clara y oscura', (
      tester,
    ) async {
      await _pumpHome(tester, appDark: false);
      final light = _readHeaderField(tester);

      await _pumpHome(tester, appDark: true);
      final dark = _readHeaderField(tester);

      expect(dark.ink, light.ink);
      expect(dark.hint, light.hint);
      expect(dark.icon, light.icon);
      expect(dark.border, light.border);
      expect(dark.glass, light.glass);
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

ProviderContainer _container(
  MemoryMapThemeStore store, {
  bool preload = false,
  MapTile? preloaded,
}) => ProviderContainer(
  overrides: [
    mapThemeStoreProvider.overrideWithValue(store),
    if (preload)
      mapThemeControllerProvider.overrideWith(
        () => MapThemeController.preloaded(preloaded),
      ),
  ],
);

/// `MapScene` del motor simulado que montó la pantalla.
MapScene _scene(WidgetTester tester) =>
    tester.state<FakeMapEngineState>(find.byType(FakeMapEngine)).widget.scene;

/// Etiqueta de la tarjeta de una capa dentro de la hoja del selector.
Finder _layerCard(MapTile tile) =>
    find.byKey(ValueKey('layer-card-${tile.name}'));

/// Colores realmente pintados de una tarjeta de capa.
({Color fill, Color ink, Color secondary}) _cardOf(
  WidgetTester tester,
  MapTile tile,
) {
  // Fondo efectivamente pintado por la tarjeta.
  final box = tester.widget<AnimatedContainer>(
    find.byKey(ValueKey('layer-card-box-${tile.name}')),
  );
  final label = tester.widget<Text>(_layerCard(tile));
  // La segunda línea de la tarjeta (proveedor o «Requiere clave»).
  final secondary = tester.widget<Text>(
    find.byKey(ValueKey('layer-card-state-${tile.name}')),
  );
  return (
    fill: (box.decoration as BoxDecoration).color!,
    ink: label.style!.color!,
    secondary: secondary.style!.color!,
  );
}

/// Abre la hoja y mide que toda tarjeta de capa sea legible **en su propio
/// tema**: la miniatura puede ser oscura o clara (es un dibujo del mapa), pero
/// la tinta y el fondo de la tarjeta son los del tema de la app.
Future<void> _expectSheetCardsLegible(
  WidgetTester tester, {
  required bool appDark,
}) async {
  await tester.tap(find.byType(MapTileButton));
  await tester.pumpAndSettle();

  final expectedBrightness = appDark ? Brightness.dark : Brightness.light;
  expect(
    Theme.of(tester.element(_layerCard(MapTile.osm))).brightness,
    expectedBrightness,
  );

  for (final tile in MapTile.values) {
    final card = _cardOf(tester, tile);
    expect(
      colorContrast(card.ink, card.fill),
      greaterThanOrEqualTo(4.5),
      reason:
          '${tile.shortLabel} ilegible (app ${appDark ? 'oscura' : 'clara'})',
    );
    expect(
      colorContrast(card.secondary, card.fill),
      greaterThanOrEqualTo(3.0),
      reason: '${tile.provider} ilegible (app ${appDark ? 'oscura' : 'clara'})',
    );
    // Nadie pinta blanco/negro literales sobre la superficie de la hoja.
    expect(card.ink, isNot(same(Colors.white)));
    expect(card.ink, isNot(same(Colors.black)));
  }
}

/// Brillo con el que se pinta la interfaz de la pantalla (el `Scaffold` raíz).
/// Sin ámbitos de mapa, es SIEMPRE el de la app, sea cual sea el tile.
Brightness _appBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

/// Mapa suelto con una etiqueta encima: aísla el resuelto del tile sin
/// arrastrar providers del planeador.
Future<void> _pumpScope(
  WidgetTester tester, {
  required bool appDark,
  required MapTile? choice,
}) async {
  final container = ProviderContainer(
    overrides: [
      mapThemeStoreProvider.overrideWithValue(MemoryMapThemeStore(choice)),
      mapThemeControllerProvider.overrideWith(
        () => MapThemeController.preloaded(choice),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appDark ? AppTheme.dark() : AppTheme.light(),
        home: const Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: UrbanoMap(
                  center: LatLng(-17.78, -63.15),
                  zoom: 12,
                  interactive: false,
                  showTiles: false,
                ),
              ),
              Positioned(top: 8, left: 8, child: Text('Origen → destino')),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pumpPlanner(
  WidgetTester tester, {
  required bool appDark,
  required MapTile? choice,
  required MemoryMapThemeStore store,
}) async {
  final container = ProviderContainer(
    overrides: [
      myLocationProvider.overrideWith(
        (ref) async => const LatLng(-17.7833, -63.1821),
      ),
      journeyProvider.overrideWith(
        (ref, query) async => [fixtureDirectOption(), fixtureTransferOption()],
      ),
      locationServiceProvider.overrideWithValue(FakeLocationService()),
      mapThemeStoreProvider.overrideWithValue(store),
      if (choice != null)
        mapThemeControllerProvider.overrideWith(
          () => MapThemeController.preloaded(choice),
        ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(_plannerApp(container, appDark: appDark));
  final router = container.read(appRouterProvider);
  router.go('/journey');
  await tester.pumpAndSettle();
  // Se devuelve el contenedor: un test necesita re-pumpear la pantalla con otro
  // tema de app SIN tocar la preferencia del mapa.
  return container;
}

Widget _plannerApp(ProviderContainer container, {required bool appDark}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: appDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: container.read(appRouterProvider),
      ),
    );

Future<void> _pumpHome(WidgetTester tester, {required bool appDark}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myLocationProvider.overrideWith(
          (ref) async => const LatLng(-17.7833, -63.1821),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: appDark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(body: HomeHeader(controller: TextEditingController())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Colores del buscador de la cabecera tal como los pintó el widget.
_HeaderField _readHeaderField(WidgetTester tester) {
  final field = tester.widget<TextField>(find.byType(TextField).first);
  final decoration = field.decoration!;
  return (
    ink: field.style!.color!,
    hint: decoration.hintStyle!.color!,
    glass: decoration.fillColor!,
    icon: decoration.prefixIconColor!,
    border: (decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
  );
}
