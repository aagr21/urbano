#!/usr/bin/env bash
# Regenera la imagen estática del launch screen de iOS a partir del SVG que copia
# el frame 0 de `assets/lottie/splash.json`.
#
# Por qué hace falta una imagen y no un drawable vectorial: el launch screen de
# iOS es una INSTANTÁNEA que el sistema guarda antes de que la app tenga proceso.
# No puede ejecutar código ni animar (una animación ahí se rechaza en la App
# Store), así que la única forma de que el arranque se vea continuo es pintar en
# el storyboard el mismo frame 0 que después reproduce el Lottie dentro de Flutter.
#
# Necesita `resvg` (o `rsvg-convert`) en el PATH. Se corre a mano, no en CI: los
# PNG generados están commiteados para que Xcode compile sin dependencias.
set -eu
cd "$(dirname "$0")/.." || exit 1
SRC="assets/lottie/splash-frame0.svg"
OUT="ios/Runner/Assets.xcassets/LaunchImage.imageset"

render() { # <px> <archivo destino>
  if command -v resvg >/dev/null; then
    # El SVG lleva el texto «Cargando»: hay que cargar Inter a mano, porque el
    # frame 0 imita al JSON y ese texto se hornea con la cara de la marca.
    resvg --use-font-file assets/fonts/Inter-SemiBold.ttf -w "$1" -h "$1" "$SRC" "$2"
  else
    rsvg-convert -w "$1" -h "$1" -o "$2" "$SRC"
  fi
}

# El lienzo del SVG es 360; los tres escalados de un imageset universal.
render 360 "$OUT/LaunchImage.png"
render 720 "$OUT/LaunchImage@2x.png"
render 1080 "$OUT/LaunchImage@3x.png"

ls -l "$OUT"
echo "listo: $OUT (revisar en el simulador que el frame 0 caiga donde lo pinta SplashGate)"
