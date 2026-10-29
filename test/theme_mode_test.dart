import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/theme/theme_mode_controller.dart';
import 'package:urbano/src/features/home/presentation/home_providers.dart';
import 'package:urbano/src/features/info/presentation/info_screen.dart';

/// Fake de persistencia: en memoria, sin plugins (regla del repo:
/// `flutter test` nunca depende de red/plugins).
class MemoryThemeModeStore implements ThemeModeStore {
  MemoryThemeModeStore(this._initial);

  ThemeMode? _initial;
  ThemeMode? lastSaved;

  @override
  Future<ThemeMode?> load() async {
    final value = _initial;
    _initial = null; // como un store real, la carga no es idempotente.
    return value;
  }

  @override
  Future<void> save(ThemeMode mode) async {
    // En memoria completa al instante; la asincronía real (canal a la
    // plataforma) vive en SharedPreferencesThemeModeStore y no aporta nada
    // en un fake.
    lastSaved = mode;
  }
}

/// Fake de persistencia que falla al leer (simula un store corrupto sin
/// tocar plugins).
class _ThrowingStore implements ThemeModeStore {
  @override
  Future<ThemeMode?> load() async => throw Exception('store corrupta');

  @override
  Future<void> save(ThemeMode mode) async {}
}

ProviderContainer _container(MemoryThemeModeStore store) => ProviderContainer(
  overrides: [themeModeStoreProvider.overrideWithValue(store)],
);

void main() {
  group('ThemeModeController', () {
    test('arranca en sistema cuando no hay preferencia guardada', () {
      final store = MemoryThemeModeStore(null);
      final container = _container(store);
      addTearDown(container.dispose);

      expect(container.read(themeModeControllerProvider), ThemeMode.system);
    });

    test(
      'restaura en background el modo guardado de la sesión anterior',
      () async {
        final store = MemoryThemeModeStore(ThemeMode.dark);
        final container = _container(store);
        addTearDown(container.dispose);

        // Mientras la carga está en vuelo, el modo visible es el del sistema.
        expect(container.read(themeModeControllerProvider), ThemeMode.system);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(themeModeControllerProvider), ThemeMode.dark);
      },
    );

    test('setMode cambia el estado al instante y persiste', () async {
      final store = MemoryThemeModeStore(null);
      final container = _container(store);
      addTearDown(container.dispose);

      final notifier = container.read(themeModeControllerProvider.notifier);
      notifier.setMode(ThemeMode.light);

      expect(container.read(themeModeControllerProvider), ThemeMode.light);
      expect(store.lastSaved, ThemeMode.light);
    });

    test('ignora valores corruptos del store y no rompe', () async {
      final container = ProviderContainer(
        overrides: [
          themeModeStoreProvider.overrideWith((_) => _ThrowingStore()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeControllerProvider), ThemeMode.system);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeControllerProvider), ThemeMode.system);
    });

    // Regresión STYLE_NOT_READY: cuando `main()` pre-carga el modo guardado y
    // lo inyecta, `build()` debe devolverlo YA y no cambiarlo después. Si lo
    // cambiara en un microtask posterior, `MaterialApp` reharía el brillo con
    // el mapa montado → segundo `setStyleString` → carrera en el plugin.
    test(
      'modo pre-cargado se aplica síncrono y no cambia en background',
      () async {
        final store = MemoryThemeModeStore(ThemeMode.dark);
        final container = ProviderContainer(
          overrides: [
            themeModeStoreProvider.overrideWithValue(store),
            themeModeControllerProvider.overrideWith(
              () => ThemeModeController(ThemeMode.dark),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Primer read: ya viene resuelto (no `system` transitorio).
        expect(container.read(themeModeControllerProvider), ThemeMode.dark);
        // Ni un frame posterior lo mueve: el mapa verá un único estilo.
        await Future<void>.delayed(Duration.zero);
        expect(container.read(themeModeControllerProvider), ThemeMode.dark);
      },
    );
  });

  group('Selector de modo en la pantalla de Info', () {
    Future<ProviderContainer> pumpInfo(
      WidgetTester tester, {
      MemoryThemeModeStore? store,
    }) async {
      final effectiveStore = store ?? MemoryThemeModeStore(null);
      final container = ProviderContainer(
        overrides: [
          themeModeStoreProvider.overrideWithValue(effectiveStore),
          // La pantalla de Info también consulta stats/salud del API: fuera de
          // línea basta con que esos providers queden en estado de error.
          statsProvider.overrideWith((ref) async => throw Exception('offline')),
          metaProvider.overrideWith((ref) async => throw Exception('offline')),
          healthProvider.overrideWith(
            (ref) async => throw Exception('offline'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InfoScreen()),
        ),
      );
      return container;
    }

    testWidgets('muestra las tres opciones con Sistema preseleccionado', (
      tester,
    ) async {
      final container = await pumpInfo(tester);
      await tester.pump();
      // El viewport de test (800x600) ya muestra la tarjeta de Apariencia:
      // no hace falta scroll (arrastrar movería la tarjeta fuera del viewport
      // y el ListView perezoso la desmontaría).

      expect(find.text('Apariencia'), findsOneWidget);
      // OJO: el tipo es necesario. `find.byType(SegmentedButton)` sin
      // argumentos instaancia `SegmentedButton<dynamic>` y `byType` compara
      // runtimeType EXACTO, así que no encontraría nada.
      final button = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(button.segments, hasLength(3));
      expect(button.selected, {ThemeMode.system});
      expect(container.read(themeModeControllerProvider), ThemeMode.system);
    });

    testWidgets('al tocar Oscuro cambia el modo visible y se persiste', (
      tester,
    ) async {
      final store = MemoryThemeModeStore(null);
      final container = await pumpInfo(tester, store: store);
      await tester.pump();

      await tester.tap(find.text('Oscuro'));
      await tester.pump();

      expect(container.read(themeModeControllerProvider), ThemeMode.dark);
      expect(store.lastSaved, ThemeMode.dark);
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
