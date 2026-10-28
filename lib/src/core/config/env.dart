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
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.26.6:3000/api/v1',
  );

  static const String appName = 'Urbano';
  static const String tagline = 'Muévete por Santa Cruz';
  static const String userAgent = 'bo.urbano.app';
}
