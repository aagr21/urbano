"""Genera los SVG del ícono de Urbano desde UN solo diseño.

Uso: python3 tools/app_icon.py <carpeta-salida>

Escribe cuatro variantes (1024 × 1024) que `tools/make-app-icon.sh` rasteriza:

* `icon-full.svg`        fondo + glifo, a sangre y opaco (iOS, web, legacy).
* `icon-background.svg`  capa de fondo del ícono adaptativo de Android.
* `icon-foreground.svg`  capa de frente (transparente, dentro de la zona segura).
* `icon-monochrome.svg`  silueta para los íconos temáticos de Android 13+.

El dibujo (ícono oficial de la marca, «Ícono de ruta verde degradado»): la
«U» de Urbano trazada en blanco como un recorrido que sale de una parada (aro
blanco con su centro verde y punto blanco, arriba a la izquierda) y llega al
pin naranja del destino, apoyado sobre la pata derecha, encima del degradado de
verdes de la paleta. La pata del destino es más corta: el pin la remata.
"""

import sys
from pathlib import Path

LIME = '#35F04F'
BRAND = '#06BD4A'
PRIMARY = '#029E46'
PRIMARY_DARK = '#018A3C'
ACCENT = '#FD7502'
INK = '#014D23'

# Geometría del glifo en un lienzo de 1024 (centro 512).
LEFT, RIGHT = 342, 682          # ejes de las patas de la U
TOP_L, TOP_R = 330, 470         # la pata del destino es más corta: asimetría
BEND = 560                      # arranque de la curva inferior
RADIUS = (RIGHT - LEFT) / 2     # curva inferior = semicircunferencia
STROKE = 104
U_PATH = (
    f'M{LEFT} {TOP_L} L{LEFT} {BEND} '
    f'A{RADIUS} {RADIUS} 0 0 0 {RIGHT} {BEND} L{RIGHT} {TOP_R}'
)

# Pin de destino sobre la pata derecha: gota con la punta apoyada en la línea.
PIN_R = 100
PIN_TIP = TOP_R + 10
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
GLYPH_CX = ((LEFT - 92) + (RIGHT + PIN_R)) / 2
GLYPH_CY = ((min(PIN_CY - PIN_R, TOP_L - 92)) + (BEND + RADIUS + STROKE / 2)) / 2


def background(dark: bool = False) -> str:
    stops = ('#0F5A2C', '#0A4423', '#052A15') if dark else (LIME, BRAND, PRIMARY_DARK)
    glow = '.08' if dark else '.18'
    return f'''
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{stops[0]}"/>
      <stop offset=".55" stop-color="{stops[1]}"/>
      <stop offset="1" stop-color="{stops[2]}"/>
    </linearGradient>
    <radialGradient id="glow" cx=".2" cy=".15" r=".6">
      <stop offset="0" stop-color="#fff" stop-opacity="{glow}"/>
      <stop offset="1" stop-color="#fff" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <rect width="1024" height="1024" fill="url(#glow)"/>'''


def glyph(scale: float, mono: bool = False) -> str:
    """La U-recorrido con su pin, escalada desde el centro del lienzo."""
    t = f'translate(512 512) scale({scale}) translate({-GLYPH_CX} {-GLYPH_CY})'
    if mono:
        # Silueta: el sistema la tiñe; los huecos (centro de la parada, ojo del
        # pin y el filo entre pin y pata) se recortan para que no sea un borrón.
        return f'''
  <defs>
    <mask id="cut" maskUnits="userSpaceOnUse" x="-512" y="-512" width="2048" height="2048">
      <rect x="-512" y="-512" width="2048" height="2048" fill="#fff"/>
      <circle cx="{LEFT}" cy="{TOP_L}" r="62" fill="#000"/>
      <circle cx="{RIGHT}" cy="{PIN_CY}" r="{PIN_R * 0.42}" fill="#000"/>
      <path d="{PIN_PATH}" fill="none" stroke="#000" stroke-width="26"/>
    </mask>
  </defs>
  <g transform="{t}" mask="url(#cut)">
    <path d="{U_PATH}" fill="none" stroke="#fff" stroke-width="{STROKE}"/>
    <circle cx="{LEFT}" cy="{TOP_L}" r="92" fill="#fff"/>
    <path d="{PIN_PATH}" fill="#fff"/>
  </g>
  <g transform="{t}">
    <circle cx="{LEFT}" cy="{TOP_L}" r="32" fill="#fff"/>
  </g>'''
    return f'''
  <defs>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="{INK}" flood-opacity=".35"/>
    </filter>
  </defs>
  <g transform="{t}">
    <!-- El recorrido: la U blanca, de la parada al destino. -->
    <path d="{U_PATH}" fill="none" stroke="#fff" stroke-width="{STROKE}" filter="url(#shadow)"/>
    <!-- La parada de salida: aro blanco, centro verde y punto blanco. -->
    <circle cx="{LEFT}" cy="{TOP_L}" r="92" fill="#fff" filter="url(#shadow)"/>
    <circle cx="{LEFT}" cy="{TOP_L}" r="62" fill="{BRAND}"/>
    <circle cx="{LEFT}" cy="{TOP_L}" r="34" fill="#fff"/>
    <!-- A dónde vas: el pin naranja, con la punta sobre la pata derecha. -->
    <path d="{PIN_PATH}" fill="{ACCENT}" filter="url(#shadow)"/>
    <circle cx="{RIGHT}" cy="{PIN_CY}" r="{PIN_R * 0.42}" fill="#fff"/>
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
