import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Puerto de persistencia del modo propio del mapa.
///
/// Igual que [ThemeModeStore] con el tema de la app, aísla al controller de
/// `shared_preferences`: en la app real se inyecta
/// [SharedPreferencesMapThemeStore]; en los tests, un fake en memoria (la
/// regla del repo es que `flutter test` nunca toque plugins).
abstract interface class MapThemeStore {
  /// Modo guardado para el mapa: `true` = oscuro, `false` = claro, `null` =
  /// el usuario nunca eligió (el mapa arranca con el brillo del tema de la app).
  Future<bool?> load();

  /// Guarda la elección. `null` borra la preferencia (volver a seguir al tema).
  Future<void> save(bool? dark);
}

/// Implementación con `shared_preferences`.
class SharedPreferencesMapThemeStore implements MapThemeStore {
  static const _key = 'urbano.map_theme_dark';

  @override
  Future<bool?> load() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key);
  }

  @override
  Future<void> save(bool? dark) async {
    final preferences = await SharedPreferences.getInstance();
    if (dark == null) {
      await preferences.remove(_key);
      return;
    }
    await preferences.setBool(_key, dark);
  }
}

/// Elección de brillo **del mapa**, independiente del tema de la app.
///
/// Estado `bool?`:
/// - `null` → sin elección: el mapa usa el brillo del tema de la app (el
///   comportamiento histórico, y el único modo en que tema y mapa coinciden).
/// - `true` / `false` → modo fijado por el usuario: NUNDA cambia cuando cambia
///   el tema de la app, y se conserva entre sesiones.
///
/// Como un cambio de brillo del mapa recarga el estilo nativo (`setStyleString`),
/// la preferencia se lee EN [main] antes del primer frame y se inyecta con
/// [MapThemeController.preloaded]; si se dejara cargar en background, el mapa
/// se montaría con un estilo y recibiría un segundo `setStyleString` que compite
/// con la carga inicial (`PlatformException(STYLE_NOT_READY)` en
/// `maplibre_gl`).
class MapThemeController extends Notifier<bool?> {
  /// Sin valor pre-cargado: restaura la preferencia en background (tests).
  MapThemeController() : _preloaded = null, _hasPreloaded = false;

  /// Valor ya resuelto en el arranque (incluye `null` = nunca eligió).
  MapThemeController.preloaded(bool? dark)
    : _preloaded = dark,
      _hasPreloaded = true;

  final bool? _preloaded;
  final bool _hasPreloaded;

  /// Invalida restauraciones de una generación anterior si el provider se
  /// reconstruye (mismo guard que [ThemeModeController]).
  int _generation = 0;

  MapThemeStore get _store => ref.watch(mapThemeStoreProvider);

  @override
  bool? build() {
    final generation = ++_generation;
    ref.onDispose(() {
      if (generation == _generation) _generation++;
    });

    if (_hasPreloaded) return _preloaded;

    unawaited(_load(generation));
    return null;
  }

  Future<void> _load(int generation) async {
    bool? saved;
    try {
      saved = await _store.load();
    } catch (_) {
      // Store corrupto o plataforma sin plugin: se queda siguiendo al tema.
      return;
    }
    if (generation != _generation) return;
    if (saved == state) return;
    state = saved;
  }

  /// Fija el modo del mapa (claro/oscuro) y lo persiste.
  void setDark(bool dark) {
    if (state == dark) return;
    state = dark;
    unawaited(_store.save(dark));
  }

  /// Devuelve el mapa al comportamiento por defecto: seguir al tema de la app.
  void followAppTheme() {
    if (state == null) return;
    state = null;
    unawaited(_store.save(null));
  }
}

/// Store del modo del mapa (único punto entre app real y tests).
final mapThemeStoreProvider = Provider<MapThemeStore>(
  (_) => SharedPreferencesMapThemeStore(),
);

/// Elección de brillo del mapa (`null` = sigue al tema de la app).
final mapThemeControllerProvider = NotifierProvider<MapThemeController, bool?>(
  MapThemeController.new,
);
