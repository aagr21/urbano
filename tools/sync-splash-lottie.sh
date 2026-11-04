#!/usr/bin/env bash
# Copia el Lottie de la portada al lugar donde lo lee la splash NATIVA de Android.
#
# Por qué hace falta una copia: `android/app/src/main/assets/` es lo único que
# Kotlin puede abrir antes de que exista el engine de Flutter. Los assets de
# Flutter (`assets/lottie/`) no están accesibles desde ahí.
#
# Por qué se MINIFICA de paso: el JSON fuente está indentado para que se pueda
# leer y versionar (18,7 KB); el parser de Lottie se come ese whitespace en el
# arranque en frío, cuando la CPU está disputando con `libflutter.so`. Con la
# versión compacta son 7,5 KB y el parseo baja a la mitad.
#
# El origen es SIEMPRE `assets/lottie/splash.json`; nunca editar la copia.
set -eu
cd "$(dirname "$0")/.." || exit 1
SRC="assets/lottie/splash.json"
DST="android/app/src/main/assets/splash.json"

python3 - "$SRC" "$DST" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as fh:
    data = json.load(fh)
# Compacto y sin espacios: mismos bytes, menos trabajo de parseo en el arranque.
with open(dst, "w", encoding="utf-8") as fh:
    json.dump(data, fh, separators=(",", ":"), ensure_ascii=True)
print(f"{src} -> {dst}  ({len(json.dumps(data, separators=(',',':')))} bytes compactos)")
PY
