"""Genera los SVG del ícono de Urbano desde UN solo diseño.

Uso: python3 tools/app_icon.py <carpeta-salida>

Escribe cuatro variantes (1024 × 1024) que `tools/make-app-icon.sh` rasteriza:

* `icon-full.svg`        fondo + glifo, a sangre y opaco (iOS, web, legacy).
* `icon-background.svg`  capa de fondo del ícono adaptativo de Android.
* `icon-foreground.svg`  capa de frente (transparente, dentro de la zona segura).
* `icon-monochrome.svg`  silueta para los íconos temáticos de Android 13+.

El dibujo: la «U» de Urbano trazada como un recorrido de micro (línea blanca
con su eje de paradas), que sale de una parada y termina en el pin coral del
destino, sobre el degradado de marca y los anillos de Santa Cruz (los mismos
que pinta la splash). Las patas son de distinto largo a propósito: simétrica,
con dos puntas redondas, la U se leía como un imán.
"""

import sys
from pathlib import Path

AQUA = '#2AD8C3'
PRIMARY = '#008C7B'
PRIMARY_DARK = '#00584F'
ACCENT = '#FF5B35'
INK = '#004A42'

# Geometría del glifo en un lienzo de 1024 (centro 512).
LEFT, RIGHT = 330, 694          # ejes de las patas de la U
TOP_L, TOP_R = 330, 520         # la pata del destino es más corta: asimetría
BEND = 560                      # arranque de la curva inferior
RADIUS = (RIGHT - LEFT) / 2     # curva inferior = semicircunferencia
STROKE = 124
U_PATH = (
    f'M{LEFT} {TOP_L} L{LEFT} {BEND} '
    f'A{RADIUS} {RADIUS} 0 0 0 {RIGHT} {BEND} L{RIGHT} {TOP_R}'
)

# Pin de destino sobre la pata derecha: gota con la punta apoyada en la línea.
PIN_R = 104
PIN_TIP = TOP_R - 40
PIN_CY = PIN_TIP - PIN_R * 1.6
PIN_PATH = (
    f'M{RIGHT} {PIN_TIP} '
    f'C{RIGHT - PIN_R * 0.3} {PIN_CY + PIN_R * 1.15} {RIGHT - PIN_R} {PIN_CY + PIN_R * 0.6} '
    f'{RIGHT - PIN_R} {PIN_CY} '
    f'A{PIN_R} {PIN_R} 0 1 1 {RIGHT + PIN_R} {PIN_CY} '
    f'C{RIGHT + PIN_R} {PIN_CY + PIN_R * 0.6} {RIGHT + PIN_R * 0.3} {PIN_CY + PIN_R * 1.15} '
    f'{RIGHT} {PIN_TIP} Z'
)
# Centro de la caja del conjunto (de la tapa izquierda al borde del pin y de la
# cabeza del pin al fondo de la curva): el glifo se centra por ella.
GLYPH_CX = ((LEFT - STROKE / 2) + (RIGHT + PIN_R + 11)) / 2
GLYPH_CY = ((PIN_CY - PIN_R - 11) + (BEND + RADIUS + STROKE / 2)) / 2


def background(dark: bool = False) -> str:
    stops = (
        ('#0E3B36', '#062925', '#031614') if dark else (AQUA, PRIMARY, PRIMARY_DARK)
    )
    glow = '.10' if dark else '.22'
    rings = ''.join(
        f'<circle cx="-40" cy="1090" r="{r}" fill="none" stroke="#fff" '
        f'stroke-opacity="{o}" stroke-width="{w}"/>'
        for r, o, w in ((360, 0.14, 12), (540, 0.11, 10), (730, 0.09, 10), (930, 0.07, 8))
    )
    return f'''
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{stops[0]}"/>
      <stop offset=".58" stop-color="{stops[1]}"/>
      <stop offset="1" stop-color="{stops[2]}"/>
    </linearGradient>
    <radialGradient id="glow" cx=".28" cy=".2" r=".65">
      <stop offset="0" stop-color="#fff" stop-opacity="{glow}"/>
      <stop offset="1" stop-color="#fff" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <rect width="1024" height="1024" fill="url(#glow)"/>
  {rings}'''


def glyph(scale: float, mono: bool = False) -> str:
    """La U-recorrido con su pin, escalada desde el centro del lienzo."""
    t = f'translate(512 512) scale({scale}) translate({-GLYPH_CX} {-GLYPH_CY})'
    if mono:
        # Silueta: el sistema la tiñe; los huecos (eje, parada, ojo del pin)
        # se recortan para que la forma no sea un borrón a 24 dp.
        return f'''
  <defs>
    <mask id="cut" maskUnits="userSpaceOnUse" x="-512" y="-512" width="2048" height="2048">
      <rect x="-512" y="-512" width="2048" height="2048" fill="#fff"/>
      <path d="{U_PATH}" fill="none" stroke="#000" stroke-width="18"
            stroke-linecap="round" stroke-dasharray="0 52"/>
      <circle cx="{LEFT}" cy="{TOP_L}" r="30" fill="#000"/>
      <circle cx="{RIGHT}" cy="{PIN_CY}" r="{PIN_R * 0.42}" fill="#000"/>
      <path d="{PIN_PATH}" fill="none" stroke="#000" stroke-width="26"/>
    </mask>
  </defs>
  <g transform="{t}" mask="url(#cut)">
    <path d="{U_PATH}" fill="none" stroke="#fff" stroke-width="{STROKE}" stroke-linecap="round"/>
    <path d="{PIN_PATH}" fill="#fff"/>
  </g>'''
    return f'''
  <defs>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="{INK}" flood-opacity=".45"/>
    </filter>
    <linearGradient id="route" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fff"/>
      <stop offset="1" stop-color="#E3FFFA"/>
    </linearGradient>
    <linearGradient id="pin" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FF7A55"/>
      <stop offset="1" stop-color="{ACCENT}"/>
    </linearGradient>
  </defs>
  <g transform="{t}">
    <path d="{U_PATH}" fill="none" stroke="url(#route)" stroke-width="{STROKE}"
          stroke-linecap="round" stroke-linejoin="round" filter="url(#shadow)"/>
    <!-- Eje del recorrido: paradas punteadas, como en los mapas de la app. -->
    <path d="{U_PATH}" fill="none" stroke="{PRIMARY}" stroke-opacity=".5"
          stroke-width="18" stroke-linecap="round" stroke-dasharray="0 52"/>
    <!-- Donde se sube: la parada, un anillo hueco como en un diagrama de metro. -->
    <circle cx="{LEFT}" cy="{TOP_L}" r="30" fill="none" stroke="{PRIMARY}" stroke-width="20"/>
    <!-- A dónde vas: el pin coral, con borde blanco para despegarlo del fondo. -->
    <path d="{PIN_PATH}" fill="url(#pin)" stroke="#fff" stroke-width="22"
          stroke-linejoin="round" filter="url(#shadow)"/>
    <circle cx="{RIGHT}" cy="{PIN_CY}" r="{PIN_R * 0.4}" fill="#fff"/>
  </g>'''


def svg(body: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        f'viewBox="0 0 1024 1024">{body}\n</svg>\n'
    )


def macos() -> str:
    """macOS no recorta el ícono: la placa redondeada, su margen y su sombra van
    dibujados (rejilla de Apple: placa de 824 con 100 de margen)."""
    return f'''
  <defs>
    <clipPath id="plate"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath>
    <filter id="drop" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000" flood-opacity=".3"/>
    </filter>
  </defs>
  <rect x="100" y="100" width="824" height="824" rx="185" fill="{PRIMARY}" filter="url(#drop)"/>
  <g clip-path="url(#plate)">
    <g transform="translate(100 100) scale({824 / 1024})">{background()}{glyph(0.94)}</g>
  </g>'''


def rounded() -> str:
    """Placa redondeada a sangre con esquinas transparentes (web, Windows, Linux)."""
    return f'''
  <defs><clipPath id="plate"><rect width="1024" height="1024" rx="230"/></clipPath></defs>
  <g clip-path="url(#plate)">{background()}{glyph(0.94)}</g>'''


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    variants = {
        # iOS recorta solo y exige un PNG opaco sin esquinas: a sangre.
        'icon-full': background() + glyph(0.94),
        # iOS 18 en modo oscuro: mismo glifo sobre la laguna de noche.
        'icon-dark': background(dark=True) + glyph(0.94),
        'icon-rounded': rounded(),
        'icon-macos': macos(),
        # Adaptativo de Android: zona segura = círculo de 66/108 del lienzo
        # (~626 px). El glifo a escala 0.72 cabe entero dentro, pin incluido.
        'icon-background': background(),
        'icon-foreground': glyph(0.72),
        'icon-monochrome': glyph(0.72, mono=True),
    }
    for name, body in variants.items():
        (out / f'{name}.svg').write_text(svg(body))


if __name__ == '__main__':
    main()
