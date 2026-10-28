import 'dart:io' show Platform;

/// `true` dentro de `flutter test` (el runner exporta `FLUTTER_TEST=true`).
bool get runningUnderTest => Platform.environment.containsKey('FLUTTER_TEST');
