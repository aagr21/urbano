"""Deriva el escudo municipal con el texto en blanco.

Uso: python3 tools/brand_seal.py <escudo.png> <salida.png>

`gobierno-santa-cruz.png` trae el blasón a la izquierda y el texto
(«Gobierno Autónomo Municipal de / SANTA CRUZ DE LA SIERRA») a la derecha, en
negro y verde. Sobre el degradado de la splash ese texto no se lee, así que
aquí se pinta de blanco conservando su alfa (los bordes suavizados siguen
iguales). El blasón NO se toca: es el símbolo oficial y no se recolorea.
"""

import sys

from PIL import Image

# El blasón ocupa las primeras ~235 columnas del PNG (de 900); el texto empieza
# pasada la columna 250.
TEXT_FROM = 250


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    image = Image.open(src).convert('RGBA')
    pixels = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(TEXT_FROM, width):
            alpha = pixels[x, y][3]
            if alpha:
                pixels[x, y] = (255, 255, 255, alpha)
    image.save(dst, optimize=True)


if __name__ == '__main__':
    main()
