import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../map/map_tile.dart';

/// Puerto de persistencia de la capa **propia del mapa**.
///
/// Igual que [ThemeModeStore] con el tema de la app, aísla al controller de
/// `shared_preferences`: en la app real se inyecta
/// [SharedPreferencesMapThemeStore]; en los tests, un fake en memoria (la
/// regla del repo es que `flutter test` nunca toque plugins).
abstract interface class MapThemeStore {
  /// Capa guardada para el mapa; `null` = el usuario nunca eligió (el mapa
  /// arranca siguiendo el brillo del tema de la app: OSM claro u Oscuro).
  Future<MapTile?> load();

  /// Guarda la elección. `null` borra la preferencia (volver a seguir al tema).
  Future<void> save(MapTile? tile);
}

/// Resuelve un [MapTile] (capa) por su nombre de enum (`null` si no coincide).
MapTile? _mapTileFromName(String? name) {
  if (name == null) return null;
  for (final tile in MapTile.values) {
    if (tile.name == name) return tile;
  }
  return null;
}

/// Implementación con `shared_preferences`.
class SharedPreferencesMapThemeStore implements MapThemeStore {
  static const _key = 'urbano.map_tile';

  /// Preferencia antigua (toggle claro/oscuro) que se migra una sola vez.
  static const _legacyKey = 'urbano.map_theme_dark';

  @override
  Future<MapTile?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = _mapTileFromName(preferences.getString(_key));
    if (saved != null) return saved;
    // Migración: el booleano oscuro/claro pasa a una capa concreta.
    final legacy = preferences.getBool(_legacyKey);
    if (legacy == null) return null;
    return legacy ? MapTile.dark : MapTile.osm;
  }

  @override
  Future<void> save(MapTile? tile) async {
    final preferences = await SharedPreferences.getInstance();
    if (tile == null) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(_key, tile.name);
    }
    // El toggle antiguo ya no existe: se descarta tras migrar.
    await preferences.remove(_legacyKey);
  }
}

/// Elección de capa **del mapa**, independiente del tema de la app.
///
/// Estado `MapTile?`:
/// - `null` → sin elección: el mapa usa la capa por defecto del brillo del tema
///   de la app (OSM claro con app clara, Oscuro con app oscura) — el
///   comportamiento histórico.
/// - `MapTile` → capa fijada por el usuario: NUNCA cambia cuando cambia el tema
///   de la app, y se conserva entre sesiones.
///
/// Como cambiar de capa recarga el estilo nativo (`setStyleString`), la
/// preferencia se lee EN [main] antes del primer frame y se inyecta con
/// [MapThemeController.preloaded]; si se dejara cargar en background, el mapa se
/// montaría con un estilo y recibiría un segundo `setStyleString` que compite con
/// la carga inicial (`PlatformException(STYLE_NOT_READY)` en `maplibre_gl`).
class MapThemeController extends Notifier<MapTile?> {
  /// Sin valor pre-cargado: restaura la preferencia en background (tests).
  MapThemeController() : _preloaded = null, _hasPreloaded = false;

  /// Valor ya resuelto en el arranque (incluye `null` = nunca eligió).
  MapThemeController.preloaded(MapTile? tile)
    : _preloaded = tile,
      _hasPreloaded = true;

  final MapTile? _preloaded;
  final bool _hasPreloaded;

  /// Invalida restauraciones de una generación anterior si el provider se
  /// reconstruye (mismo guard que [ThemeModeController]).
  int _generation = 0;

  MapThemeStore get _store => ref.watch(mapThemeStoreProvider);

  @override
  MapTile? build() {
    final generation = ++_generation;
    ref.onDispose(() {
      if (generation == _generation) _generation++;
    });

    if (_hasPreloaded) return _preloaded;

    unawaited(_load(generation));
    return null;
  }

  Future<void> _load(int generation) async {
    MapTile? saved;
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

  /// Fija la capa del mapa y la persiste.
  void setTile(MapTile tile) {
    if (state == tile) return;
    state = tile;
    unawaited(_store.save(tile));
  }

  /// Devuelve el mapa al comportamiento por defecto: seguir al tema de la app.
  void followAppTheme() {
    if (state == null) return;
    state = null;
    unawaited(_store.save(null));
  }
}

/// Store de la capa del mapa (único punto entre app real y tests).
final mapThemeStoreProvider = Provider<MapThemeStore>(
  (_) => SharedPreferencesMapThemeStore(),
);

/// Elección de capa del mapa (`null` = sigue al tema de la app).
final mapThemeControllerProvider =
    NotifierProvider<MapThemeController, MapTile?>(MapThemeController.new);
