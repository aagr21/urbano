/// Configuración inyectada en tiempo de compilación vía `--dart-define`.
///
/// ```sh
/// # Navegador / escritorio (default)
/// flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1
///
/// # Emulador de Android: el host se ve como 10.0.2.2
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
///
/// # Dispositivo físico en la misma red WiFi
/// flutter run --dart-define=API_BASE_URL=http://192.168.26.6:3000/api/v1
/// ```
///
/// Capas de Google (Map Tiles API). Las cuatro capas aparecen SIEMPRE en el
/// selector; sin clave, las de Google quedan marcadas «Requiere clave» y
/// explican cómo activarla. Dos formas de pasarla:
/// ```sh
/// flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...
/// # o escribiéndola en config/env.json (leído por los launch configs)
/// flutter run --dart-define-from-file=config/env.json
/// ```
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.26.6:3000/api/v1',
  );

  /// Clave de la Map Tiles API de Google (`''` = capas de Google bloqueadas).
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  static const String appName = 'Urbano';
  static const String tagline = 'Muévete por Santa Cruz';
  static const String userAgent = 'bo.urbano.app';
}
