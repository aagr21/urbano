#!/usr/bin/env bash
# APK universal de release, lo más liviano posible sin tocar la app.
#
#   tools/build-apk.sh            → build/app/outputs/flutter-apk/app-release.apk
#
# - Solo ARM (arm64-v8a + armeabi-v7a): sirve para todos los teléfonos Android;
#   x86_64 es solo de emuladores (para eso está el build de debug). El bloque
#   `ndk.abiFilters` de android/app/build.gradle.kts recorta además los `.so`
#   de los plugins (MapLibre), que `--target-platform` no toca.
# - Librerías nativas comprimidas (`useLegacyPackaging`, mismo archivo).
# - `--obfuscate` achica el código Dart; los símbolos quedan en
#   build/symbols/<versión>/ y hacen falta para leer los reportes de errores
#   de ESA versión (`flutter symbolize`): guárdalos con cada APK que repartas.
#
# Para Google Play no uses esto: `flutter build appbundle` (Play entrega a cada
# teléfono solo su parte).
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}')
symbols="build/symbols/$version"

flutter build apk --release \
  --target-platform android-arm,android-arm64 \
  --obfuscate --split-debug-info="$symbols" \
  "$@"

apk=build/app/outputs/flutter-apk/app-release.apk
echo "APK: $apk ($(du -h "$apk" | cut -f1)) · símbolos: $symbols"
