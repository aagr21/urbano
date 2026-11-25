import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/theme_mode_controller.dart';

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
