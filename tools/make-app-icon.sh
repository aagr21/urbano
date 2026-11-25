#!/usr/bin/env bash
# Regenera el ícono de la app en TODAS las plataformas desde tools/app_icon.py.
#
#   tools/make-app-icon.sh
#
# 1. app_icon.py escribe los SVG fuente en assets/brand/app-icon/.
# 2. resvg los rasteriza a PNG de 1024 (misma carpeta, son la entrada de
#    icons_launcher y se versionan para que el paso 3 sea reproducible).
# 3. icons_launcher (config en icons_launcher.yaml) genera los mipmaps de
#    Android (adaptativo + monocromático + legacy), el AppIcon de iOS (claro y
#    oscuro), los de macOS, web, Windows y Linux.
#
# Necesita `resvg` (pacman -S resvg / cargo install resvg) y python3.
set -euo pipefail

cd "$(dirname "$0")/.."
out=assets/brand/app-icon

command -v resvg >/dev/null || { echo "falta resvg" >&2; exit 1; }

python3 -I tools/app_icon.py "$out"
for svg in "$out"/*.svg; do
  resvg -w 1024 -h 1024 "$svg" "${svg%.svg}.png"
done

dart run icons_launcher:create
echo "Ícono regenerado. Revisa: git status android ios macos web windows linux"
