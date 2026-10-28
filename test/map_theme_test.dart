import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/map/map_scene.dart';
import 'package:urbano/src/core/map/map_styles.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_colors.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/theme/map_theme_controller.dart';
import 'package:urbano/src/core/theme/map_theme_scope.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/core/widgets/glass_card.dart';
import 'package:urbano/src/core/widgets/map_theme_toggle_button.dart';
import 'package:urbano/src/core/widgets/urbano_map.dart';
import 'package:urbano/src/features/home/presentation/widgets/home_header.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';

import 'helpers/contrast.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';

/// Persistencia del modo del mapa en memoria (regla del repo: `flutter test`
/// nunca depende de plugins).
class MemoryMapThemeStore implements MapThemeStore {
  MemoryMapThemeStore([this._initial]);

  bool? _initial;
  bool? lastSaved;
  int saves = 0;

  @override
  Future<bool?> load() async {
    final value = _initial;
    _initial = null; // como un store real: la carga no es idempotente.
    return value;
  }

  @override
  Future<void> save(bool? dark) async {
    lastSaved = dark;
    saves++;
  }
}

/// Store que lanza al leer (simula una preferencia corrupta sin plugins).
class _BrokenMapThemeStore implements MapThemeStore {
  @override
  Future<bool?> load() async => throw Exception('store corrupta');

  @override
  Future<void> save(bool? dark) async {}
}

/// Colores del buscador de la cabecera, leídos del widget ya pintado.
typedef _HeaderField = ({
  Color border,
  Color glass,
  Color hint,
  Color icon,
  Color ink,
});

/// Brillo del mapa para una combinación: elección del usuario o tema de la app.
bool _mapIsDark({required bool appDark, bool? choice}) => choice ?? appDark;

void main() {
  group('MapThemeController (modo propio del mapa)', () {
    test(
      'sin preferencia guardada el mapa arranca siguiendo al tema de la app',
      () {
        final container = _container(MemoryMapThemeStore());
        addTearDown(container.dispose);

        expect(container.read(mapThemeControllerProvider), isNull);
      },
    );

    test('restaura en background el modo que el usuario eligió', () async {
      final container = _container(MemoryMapThemeStore(true));
      addTearDown(container.dispose);

      // Mientras la carga está en vuelo no hay modo fijado visible.
      expect(container.read(mapThemeControllerProvider), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(mapThemeControllerProvider), isTrue);
    });

    // Regresión STYLE_NOT_READY: `main()` pre-carga la preferencia y la inyecta.
    // Si el controller la cambiara después, el mapa ya montado recibiría un
    // segundo `setStyleString` que compite con la carga del estilo nativo.
    test(
      'modo pre-cargado se aplica síncrono y no cambia en background',
      () async {
        final store = MemoryMapThemeStore(false);
        final container = _container(store, preloaded: false);
        addTearDown(container.dispose);

        expect(container.read(mapThemeControllerProvider), isFalse);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(mapThemeControllerProvider), isFalse);
      },
    );

    test('setDark fija el modo al instante y lo persiste', () {
      final store = MemoryMapThemeStore();
      final container = _container(store);
      addTearDown(container.dispose);

      container.read(mapThemeControllerProvider.notifier).setDark(true);

      expect(container.read(mapThemeControllerProvider), isTrue);
      expect(store.lastSaved, isTrue);
    });

    test('setDark con el valor que ya estaba no escribe en disco', () {
      final store = MemoryMapThemeStore(false);
      final container = _container(store, preloaded: false);
      addTearDown(container.dispose);

      container.read(mapThemeControllerProvider.notifier).setDark(false);

      expect(store.saves, isZero);
    });

    test('followAppTheme borra la elección y persiste el borrado', () {
      final store = MemoryMapThemeStore(true);
      final container = _container(store, preloaded: true);
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
  });

  group('MapThemeScope (el mapa y lo que flota sobre él)', () {
    test('themeFor: sin elección no hay tema extra; con ella, el del mapa', () {
      expect(MapThemeScope.themeFor(null), isNull);
      expect(MapThemeScope.themeFor(true)?.brightness, Brightness.dark);
      expect(MapThemeScope.themeFor(false)?.brightness, Brightness.light);
    });

    testWidgets('sin elección todo hereda el brillo de la app (no-op)', (
      tester,
    ) async {
      await _pumpScope(tester, appDark: true, choice: null);

      expect(_scene(tester).dark, isTrue);
      expect(_overlayTheme(tester).brightness, Brightness.dark);
    });

    // El corazón de la independencia: mapa oscuro con app clara.
    testWidgets('mapa en oscuro con app clara no arrastra al tema de la app', (
      tester,
    ) async {
      await _pumpScope(tester, appDark: false, choice: true);

      final scene = _scene(tester);
      expect(scene.dark, isTrue);
      expect(scene.styleString, UrbanoMapStyles.dark);
      // El overlay (vidrio + su letra) resuelve el brillo DEL mapa...
      expect(_overlayTheme(tester).brightness, Brightness.dark);
      // ...y la app, por encima del ámbito, sigue clara.
      expect(_appBrightness(tester), Brightness.light);

      // Legibilidad medida sobre el fondo REAL: el vidrio del tema oscuro puesto
      // sobre el lienzo oscuro. Sin el ámbito sería la tinta del tema CLARO
      // sobre ese mismo vidrio, y eso es lo que el segundo `expect` comprueba.
      final glass = Color.lerp(scene.background, Colors.white, 0.08)!;
      expect(
        colorContrast(_overlayTheme(tester).colorScheme.onSurface, glass),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        colorContrast(AppTheme.light().colorScheme.onSurface, glass),
        lessThan(4.5),
        reason: 'el test no vale si el cruce ya fuera legible',
      );

      // Y el filo del vidrio se separa del mapa (frontera significativa: 3:1),
      // que con el blanco al 12% histórico era invisible sobre el lienzo oscuro.
      expect(
        colorContrast(
          Color.lerp(scene.background, Colors.white, 0.35)!,
          scene.background,
        ),
        greaterThanOrEqualTo(3.0),
      );
    });

    testWidgets('mapa en claro con app oscura: sin letra clara sobre vidrio '
        'claro', (tester) async {
      await _pumpScope(tester, appDark: true, choice: false);

      final scene = _scene(tester);
      expect(scene.dark, isFalse);
      expect(scene.styleString, UrbanoMapStyles.light);
      expect(_overlayTheme(tester).brightness, Brightness.light);
      expect(_appBrightness(tester), Brightness.dark);

      final glass = Color.lerp(scene.background, Colors.white, 0.82)!;
      expect(
        colorContrast(_overlayTheme(tester).colorScheme.onSurface, glass),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        colorContrast(AppTheme.dark().colorScheme.onSurface, glass),
        lessThan(4.5),
        reason: 'el test no vale si el cruce ya fuera legible',
      );
    });
  });

  group('Cuatro combinaciones app × mapa en la pantalla Viaje', () {
    for (final appDark in [false, true]) {
      for (final choice in [false, true, null]) {
        final mapLabel = switch (choice) {
          null => 'sin elección',
          true => 'oscuro',
          false => 'claro',
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
            expectedDark ? UrbanoMapStyles.dark : UrbanoMapStyles.light,
          );

          // 2. Sin fugas hacia arriba: la pantalla (fuera del ámbito) conserva
          //    el brillo de la app.
          expect(
            _appBrightness(tester),
            appDark ? Brightness.dark : Brightness.light,
          );

          // 3. Los superpuestos del mapa leen el brillo del mapa: la tarjeta
          //    origen→destino (GlassCard) y la píldora de atribución.
          expect(
            _overlayTheme(tester).brightness,
            expectedDark ? Brightness.dark : Brightness.light,
          );
          expect(
            Theme.of(
              tester.element(
                find.text(UrbanoMapStyles.attribution(dark: expectedDark)),
              ),
            ).brightness,
            expectedDark ? Brightness.dark : Brightness.light,
          );

          // 4. Con ese brillo, la letra del overlay contra el fondo que
          //    realmente pinta (vidrio compuesto sobre el lienzo) pasa AA.
          final glass = Color.lerp(
            scene.background,
            Colors.white,
            expectedDark ? 0.08 : 0.82,
          )!;
          expect(
            colorContrast(_overlayTheme(tester).colorScheme.onSurface, glass),
            greaterThanOrEqualTo(4.5),
            reason: 'letra del overlay ilegible sobre el vidrio del mapa',
          );

          // 5. Nadie escribe en la store: el modo solo lo cambia el usuario.
          expect(store.saves, isZero);
        });
      }
    }
  });

  group('Cambiador de brillo del mapa (UI)', () {
    testWidgets('pulsar alterna el mapa y persiste, sin tocar la app', (
      tester,
    ) async {
      final store = MemoryMapThemeStore();
      await _pumpPlanner(tester, appDark: false, choice: null, store: store);

      expect(_scene(tester).dark, isFalse);

      await tester.tap(find.byType(MapThemeToggleButton));
      await tester.pumpAndSettle();

      // El cruce pedido: mapa oscuro con app clara.
      expect(_scene(tester).dark, isTrue);
      expect(store.lastSaved, isTrue);
      expect(_appBrightness(tester), Brightness.light);

      await tester.tap(find.byType(MapThemeToggleButton));
      await tester.pumpAndSettle();
      expect(_scene(tester).dark, isFalse);
      expect(store.lastSaved, isFalse);
    });

    testWidgets('mantener pulsado devuelve el mapa al tema de la app', (
      tester,
    ) async {
      final store = MemoryMapThemeStore(true);
      await _pumpPlanner(tester, appDark: false, choice: true, store: store);

      // Se dispara el callback en vez de `tester.longPress`: al borrarse la
      // elección, `MapThemeScope` deja de instalar su `Theme` y todo el subtree
      // del mapa se reconstruye; el `PointerUpEvent` del gesto caería sobre un
      // `RenderPointerListener` ya descartado (ruido del harness, no de la app).
      final detector = tester
          .widgetList<GestureDetector>(
            find.descendant(
              of: find.byType(MapThemeToggleButton),
              matching: find.byType(GestureDetector),
            ),
          )
          // `PressScale` también monta su `GestureDetector`: el que importa es
          // el que lleva el `onLongPress` del cambiador.
          .firstWhere((gesture) => gesture.onLongPress != null);
      detector.onLongPress!();
      await tester.pumpAndSettle();

      expect(store.lastSaved, isNull);
      expect(_scene(tester).dark, isFalse); // vuelve a heredar el tema claro
      expect(
        find.text('El mapa vuelve a seguir el tema de la app'),
        findsOneWidget,
      );
    });

    testWidgets('cambiar el tema de la app no mueve el modo fijado del mapa', (
      tester,
    ) async {
      // Mapa fijado en CLARO con app clara; después la app pasa a oscura.
      final container = await _pumpPlanner(
        tester,
        appDark: false,
        choice: false,
        store: MemoryMapThemeStore(false),
      );
      expect(_scene(tester).dark, isFalse);
      expect(_appBrightness(tester), Brightness.light);

      await tester.pumpWidget(_plannerApp(container, appDark: true));
      await tester.pumpAndSettle();

      // El chrome de la app SÍ se movió...
      expect(_appBrightness(tester), Brightness.dark);
      // ...el mapa se quedó donde lo dejó el usuario.
      expect(_scene(tester).dark, isFalse);
      expect(_overlayTheme(tester).brightness, Brightness.light);
    });

    testWidgets('el ícono ofrece el modo contrario al brillo activo', (
      tester,
    ) async {
      await _pumpPlanner(
        tester,
        appDark: false,
        choice: false,
        store: MemoryMapThemeStore(false),
      );

      Icon icon() => tester.widget<Icon>(
        find.descendant(
          of: find.byType(MapThemeToggleButton),
          matching: find.byType(Icon),
        ),
      );

      // Mapa claro → ofrece oscuro; tras el tap, mapa oscuro → ofrece claro.
      expect(icon().icon, Icons.dark_mode_rounded);
      await tester.tap(find.byType(MapThemeToggleButton));
      await tester.pumpAndSettle();
      expect(icon().icon, Icons.light_mode_rounded);
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

ProviderContainer _container(MemoryMapThemeStore store, {bool? preloaded}) =>
    ProviderContainer(
      overrides: [
        mapThemeStoreProvider.overrideWithValue(store),
        if (preloaded != null)
          mapThemeControllerProvider.overrideWith(
            () => MapThemeController.preloaded(preloaded),
          ),
      ],
    );

/// `MapScene` del motor simulado que montó la pantalla.
MapScene _scene(WidgetTester tester) =>
    tester.state<FakeMapEngineState>(find.byType(FakeMapEngine)).widget.scene;

/// Tema que resuelve un overlay montado SOBRE el mapa (la `GlassCard`).
ThemeData _overlayTheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(GlassCard).first));

/// Brillo de la app POR ENCIMA del ámbito del mapa (el `Scaffold` raíz).
Brightness _appBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

/// Mapa suelto con una tarjeta de vidrio encima: aínda el mecanismo del ámbito
/// sin arrastrar providers del planeador.
Future<void> _pumpScope(
  WidgetTester tester, {
  required bool appDark,
  required bool? choice,
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
          body: MapThemeScope(
            child: Stack(
              children: [
                Positioned.fill(
                  child: UrbanoMap(
                    center: LatLng(-17.78, -63.15),
                    zoom: 12,
                    interactive: false,
                    showTiles: false,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: GlassCard(child: Text('Origen → destino')),
                ),
              ],
            ),
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
  required bool? choice,
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
