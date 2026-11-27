#!/usr/bin/env bash
# Regenera el logotipo de Urbano y el escudo en blanco desde sus fuentes.
#
#   tools/make-brand-logo.sh
#
# 1. brand_logo.py escribe los SVG del logo en assets/brand/logo/.
# 2. resvg los rasteriza (con Montserrat ExtraBold cargada a mano) a los PNG
#    que usan la app (`UrbanoLogo`) y la splash nativa de Android, en
#    assets/images/.
# 3. brand_seal.py deriva `gobierno-santa-cruz-blanco.png` del escudo oficial:
#    el blasón queda intacto y solo el texto pasa a blanco, para ir sobre el
#    degradado verde de la splash.
#
# Necesita `resvg` (pacman -S resvg / cargo install resvg) y python3 con Pillow.
set -euo pipefail

cd "$(dirname "$0")/.."
src=assets/brand/logo
out=assets/images

command -v resvg >/dev/null || { echo "falta resvg" >&2; exit 1; }

python3 -I tools/brand_logo.py "$src"
for name in urbano-logo urbano-logo-blanco; do
  resvg --use-font-file assets/fonts/Montserrat-ExtraBold.ttf \
    -w 1350 "$src/$name.svg" "$out/$name.png"
done

python3 -I tools/brand_seal.py "$out/gobierno-santa-cruz.png" \
  "$out/gobierno-santa-cruz-blanco.png"
echo "Logo regenerado en $out/"
