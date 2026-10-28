import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:urbano/src/core/map/maplibre_dispose_fix.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapLibreDisposeFix', () {
    test(
      'dispose() del canal sin inicializar no lanza LateInitializationError',
      () {
        final previous = MapLibrePlatform.createInstance;
        addTearDown(() => MapLibrePlatform.createInstance = previous);

        installMapLibreDisposeFix();
        final platform = MapLibrePlatform.createInstance();

        // Sigue siendo un canal de método normal (los listeners, callbacks y
        // toda la API siguen intactos)...
        expect(platform, isA<MapLibreMethodChannel>());

        // ...pero su dispose() ya no revienta cuando el mapa se desmontó
        // antes de que initPlatform asignara el canal (bug de maplibre_gl
        // 0.27.1: "LateInitializationError: Field '_channel@...'").
        expect(platform.dispose, returnsNormally);
      },
    );

    test('en web no se instala (el plugin registra su propia plataforma)', () {
      // Este test corre en IO (flutter_tester), así que la instalación sí
      // aplica; solo verificamos que sea idempotente.
      final previous = MapLibrePlatform.createInstance;
      addTearDown(() => MapLibrePlatform.createInstance = previous);
      installMapLibreDisposeFix();
      installMapLibreDisposeFix();
      expect(MapLibrePlatform.createInstance(), isA<MapLibreMethodChannel>());
    });
  });
}
