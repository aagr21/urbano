"""Genera los SVG del logotipo de Urbano desde UN solo diseño.

Uso: python3 tools/brand_logo.py <carpeta-salida>

El logotipo oficial (carpeta de marca «LOGO URBANO»): la palabra «Urbano» en
Montserrat ExtraBold con el degradado de verdes, subrayada por un recorrido que
sale de una parada (anillo con su punto blanco a la izquierda) y sube hasta el
pin naranja del destino, después de la «o». El lema «Muévete por Santa Cruz»
NO va dentro: lo pone la app como texto (cambia de tinta con el tema).

Escribe dos variantes que `tools/make-brand-logo.sh` rasteriza:

* `urbano-logo.svg`         verde (sobre lienzos claros y grafito).
* `urbano-logo-blanco.svg`  blanca con el pin naranja (sobre el degradado de
                            marca: splash y cabeceras verdes).

El texto se dibuja con `font-family="Montserrat"`: resvg necesita la fuente
cargada a mano (`--use-font-file`), igual que la splash de iOS.
"""

import sys
from pathlib import Path

LIME = '#35F04F'
BRIGHT = '#1BD64C'
BRAND = '#06BD4A'
DARK = '#029E46'
ORANGE = '#FD7502'
WHITE = '#FEFEFE'

# Lienzo y medidas (Montserrat ExtraBold, 1000 upm: «Urbano» avanza 3914).
W, H = 900, 224
SIZE = 200
TEXT_X = 34
BASELINE = 170
TRACKING = -4                   # -0,02 em: el logo va apretado
LINE_Y = 197                    # el recorrido corre bajo la línea base
RING_X = 44                     # la parada de salida, bajo la «U»
PIN_X = 846                     # el destino, después de la «o»
PIN_R = 38
PIN_TIP = 168
PIN_CY = PIN_TIP - PIN_R * 1.6
STROKE = 14

PIN_PATH = (
    f'M{PIN_X} {PIN_TIP} '
    f'C{PIN_X - PIN_R * 0.3} {PIN_CY + PIN_R * 1.15} {PIN_X - PIN_R} {PIN_CY + PIN_R * 0.6} '
    f'{PIN_X - PIN_R} {PIN_CY} '
    f'A{PIN_R} {PIN_R} 0 1 1 {PIN_X + PIN_R} {PIN_CY} '
    f'C{PIN_X + PIN_R} {PIN_CY + PIN_R * 0.6} {PIN_X + PIN_R * 0.3} {PIN_CY + PIN_R * 1.15} '
    f'{PIN_X} {PIN_TIP} Z'
)
# Recorrido: de la parada, a lo largo, y una curva que sube a la punta del pin.
ROUTE_PATH = (
    f'M{RING_X + 17} {LINE_Y} H{PIN_X - 44} '
    f'Q{PIN_X} {LINE_Y} {PIN_X} {PIN_TIP - 6}'
)


def logo(white: bool) -> str:
    ink = 'url(#ink)' if not white else WHITE
    ring_fill = WHITE if not white else 'none'
    defs = '' if white else f'''
    <linearGradient id="ink" gradientUnits="userSpaceOnUse" x1="0" y1="20" x2="{W}" y2="{H}">
      <stop offset="0" stop-color="{LIME}"/>
      <stop offset=".35" stop-color="{BRIGHT}"/>
      <stop offset=".7" stop-color="{BRAND}"/>
      <stop offset="1" stop-color="{DARK}"/>
    </linearGradient>'''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>{defs}
  </defs>
  <text x="{TEXT_X}" y="{BASELINE}" font-family="Montserrat" font-weight="800"
        font-size="{SIZE}" letter-spacing="{TRACKING}" fill="{ink}">Urbano</text>
  <path d="{ROUTE_PATH}" fill="none" stroke="{ink}" stroke-width="{STROKE}"
        stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="{RING_X}" cy="{LINE_Y}" r="17" fill="{ring_fill}" stroke="{ink}" stroke-width="11"/>
  <path d="{PIN_PATH}" fill="{ORANGE}"/>
  <circle cx="{PIN_X}" cy="{PIN_CY}" r="{PIN_R * 0.4}" fill="{WHITE}"/>
</svg>
'''


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    (out / 'urbano-logo.svg').write_text(logo(white=False))
    (out / 'urbano-logo-blanco.svg').write_text(logo(white=True))


if __name__ == '__main__':
    main()
