import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Puerto de persistencia del modo de tema.
///
/// Aísla a [ThemeModeController] de `shared_preferences`: en la app real se
/// inyecta [SharedPreferencesThemeModeStore]; en los tests, un fake en
/// memoria (la regla del repo es que `flutter test` nunca toque plugins).
abstract interface class ThemeModeStore {
  /// Devuelve el modo guardado en la sesión anterior, o `null` si no hay
  /// preferencia guardada (primera ejecución) o el valor es inválido.
  Future<ThemeMode?> load();

  /// Guarda el modo elegido por el usuario.
  Future<void> save(ThemeMode mode);
}

/// Implementación con `shared_preferences`.
class SharedPreferencesThemeModeStore implements ThemeModeStore {
  static const _key = 'urbano.theme_mode';

  @override
  Future<ThemeMode?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key);
    if (value == null) return null;
    try {
      return ThemeMode.values.byName(value);
    } on ArgumentError {
      // Valor corrupto o de una versión anterior: se ignora.
      return null;
    }
  }

  @override
  Future<void> save(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, mode.name);
  }
}

/// Controller Riverpod del modo claro/oscuro de la app.
///
/// - Arranca en [ThemeMode.system] y en background restaura la preferencia
///   guardada (si existe) desde [ThemeModeStore].
/// - [setMode] aplica el cambio al instante y lo persiste para la próxima
///   sesión.
class ThemeModeController extends Notifier<ThemeMode> {
  /// Invalida restauraciones de una generación anterior si el provider se
  /// reconstruye (mismo guard del controller de ubicación: Riverpod reutiliza
  /// la instancia entre rebuilds).
  int _generation = 0;

  ThemeModeStore get _store => ref.watch(themeModeStoreProvider);

  @override
  ThemeMode build() {
    final generation = ++_generation;
    ref.onDispose(() {
      if (generation == _generation) _generation++;
    });

    // La carga es asíncrona: mientras tanto la app usa el modo del sistema.
    unawaited(_load(generation));
    return ThemeMode.system;
  }

  Future<void> _load(int generation) async {
    // Si la plataforma fallara al leer (plugin ausente en tests, store
    // corrupta, etc.) la app arranca igual con el modo del sistema.
    ThemeMode? saved;
    try {
      saved = await _store.load();
    } catch (_) {
      return;
    }
    if (generation != _generation) return;
    if (saved == null || saved == state) return;
    state = saved;
  }

  /// Cambia el modo visible y guarda la preferencia en background.
  ///
  /// Solo toca el store, nunca el estado, así que no necesita generation
  /// guard: si el provider se reconstruye, la carga restaura el modo
  /// guardado.
  void setMode(ThemeMode mode) {
    state = mode;
    unawaited(_store.save(mode));
  }
}

/// Store del modo de tema (único punto entre app real y tests).
final themeModeStoreProvider = Provider<ThemeModeStore>(
  (_) => SharedPreferencesThemeModeStore(),
);

/// Modo de tema activo de la app (`MaterialApp.themeMode`).
final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
