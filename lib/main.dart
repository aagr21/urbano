import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/app.dart';
import 'src/core/map/map_tile.dart';
import 'src/core/map/maplibre_dispose_fix.dart';
import 'src/core/theme/map_theme_controller.dart';
import 'src/core/theme/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Las fuentes van empaquetadas en assets/fonts (ver pubspec.yaml): nada de
  // descargas en runtime. Esto también evita que los tests intenten fetch de red.
  GoogleFonts.config.allowRuntimeFetching = false;
  installMapLibreDisposeFix();

  // Restaurar el modo de tema ANTES del primer frame. Si se dejara al controller
  // cargarlo en background (como hacía antes), `MaterialApp` cambiaría de brillo
  // una vez montado el mapa y la vista nativa recibiría un segundo
  // `setStyleString` que compite con la carga del estilo inicial: los managers
  // de anotaciones de `maplibre_gl` llaman a `addLayer` contra un estilo que ya
  // es `null` y revientan con `PlatformException(STYLE_NOT_READY)`. Con el modo
  // resuelto por adelantado, el mapa se construye una sola vez con su estilo
  // final y la carrera desaparece.
  final savedThemeMode = await _readSavedThemeMode();
  // Lo MISMO para la capa propia del mapa: si su preferencia se leyera en
  // background, el mapa ya montado recibiría un segundo `setStyleString` al
  // terminar la carga y volvería la carrera con los managers de anotaciones.
  final savedMapTile = await _readSavedMapTile();

  runApp(
    ProviderScope(
      overrides: [
        if (savedThemeMode != null)
          themeModeControllerProvider.overrideWith(
            () => ThemeModeController(savedThemeMode),
          ),
        // Se inyecta siempre (también `null` = «sigue al tema»): el valor ya
        // está resuelto, así que el controller no programa ninguna lectura.
        mapThemeControllerProvider.overrideWith(
          () => MapThemeController.preloaded(savedMapTile),
        ),
      ],
      child: const UrbanoApp(),
    ),
  );
}

/// Lee la preferencia de tema guardada sin lanzar: si el plugin falla (store
/// corrupto, plataforma ausente) la app arranca con el modo del sistema.
Future<ThemeMode?> _readSavedThemeMode() async {
  try {
    return await SharedPreferencesThemeModeStore().load();
  } catch (_) {
    return null;
  }
}

/// Lee la capa propia del mapa (`null` = nunca eligió, sigue al tema de la app).
Future<MapTile?> _readSavedMapTile() async {
  try {
    return await SharedPreferencesMapThemeStore().load();
  } catch (_) {
    return null;
  }
}
