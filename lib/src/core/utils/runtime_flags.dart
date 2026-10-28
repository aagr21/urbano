import 'package:flutter/foundation.dart' show visibleForTesting;

import 'runtime_flags_io.dart'
    if (dart.library.js_interop) 'runtime_flags_web.dart';

/// `true` cuando el código corre dentro de `flutter test`.
///
/// No es un detalle de plataforma sino una condición de diseño: bajo tests un
/// ticker eterno impide que `pumpAndSettle` llegue a SETTLED (y en un
/// `StatefulShellRoute.indexedStack` las ramas ocultas siguen montadas, así que
/// el bucle de otra pestaña consumiría el timeout de la pestaña probada). Por
/// eso el kit de motion acota sus bucles ambiente solo aquí, y por eso el mapa
/// fuerza el motor simulado.
bool get isRunningUnderTest => debugRunningUnderTest ?? runningUnderTest;

/// Anula [isRunningUnderTest]. Solo para pruebas.
///
/// Hace falta para poder ejercitar la rama de producción del bucle ambiente:
/// bajo `flutter test` el runner exporta `FLUTTER_TEST` y, sin este hook, el
/// modo `repeat()` de `Ambient` sería literalmente invisible para los tests.
/// Déjalo en `null` (o restáuralo en `tearDown`) para no enmascarar el
/// comportamiento real.
@visibleForTesting
bool? debugRunningUnderTest;
