import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/boot/boot_readiness.dart';
import 'src/core/map/map_tile.dart';
import 'src/core/map/maplibre_dispose_fix.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/theme/map_theme_controller.dart';
import 'src/core/theme/theme_mode_controller.dart';
import 'src/core/widgets/splash_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Las fuentes van empaquetadas e inscritas como manifiesto `fonts:` en
  // pubspec.yaml, resueltas por `fontFamily` sin `google_fonts`: nada de
  // descargas en runtime y los tests nunca intentan fetch de red.
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

  // `SplashGate` es el primer widget de Flutter: no puede quedar detrás de
  // MaterialApp, porque el arranque nativo ya terminó al llegar aquí y la
  // pantalla de carga tiene que tapar el montaje del árbol, no la marca.
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
      child: const _BootGate(),
    ),
  );
}

/// La pantalla de carga con la señal de arranque real de la app.
///
/// Escuchar [bootReadinessProvider] desde el composition root —y no desde el
/// home— es lo que hace que la espera sea honesta: las llamadas del inicio salen
/// en el frame 1, tapadas por la portada, y la cortina se levanta cuando
/// respondieron, no a los 900 ms de un reloj inventado.
class _BootGate extends ConsumerWidget {
  const _BootGate();

  /// El tema de la portada, calculado una sola vez.
  ///
  /// `SplashGate` vive POR ENCIMA de `MaterialApp` —es el primer widget de Flutter
  /// y tapar el montaje del árbol es su trabajo—, así que sin este `Theme` sus
  /// letras caerían en el `ThemeData.fallback()` de Material: `Inter` viene en
  /// `AppTypography.apply` y un `TextStyle` sin familia de fuente lo descarta en
  /// silencio. La portada es siempre el degradado oscuro de la marca, así que el
  /// tema oscuro es el que le corresponde.
  static final ThemeData _coverTheme = AppTheme.dark();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Theme(
    data: _coverTheme,
    child: SplashGate(
      ready: ref.watch(bootReadinessProvider.future),
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
