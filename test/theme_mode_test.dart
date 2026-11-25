import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/theme_mode_controller.dart';

import 'helpers/memory_theme_mode_store.dart';

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
}
