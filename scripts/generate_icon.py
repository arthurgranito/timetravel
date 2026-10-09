#!/usr/bin/env python3
"""Gera o ícone do app (1024x1024, RGB sem transparência), com cara de app de notas.

Uso (precisa do Pillow: pip install pillow):
    python3 scripts/generate_icon.py
Salva em Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png.
O iOS aplica os cantos arredondados sozinho, então o desenho é um quadrado cheio.
"""
import os
from PIL import Image, ImageDraw

SIZE = 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")


def main():
    image = Image.new("RGB", (SIZE, SIZE), (255, 247, 200))
    draw = ImageDraw.Draw(image)

    # Faixa superior amarela mais forte (como um bloco de notas).
    draw.rectangle([0, 0, SIZE, 250], fill=(255, 214, 64))
    draw.rectangle([0, 250, SIZE, 262], fill=(232, 190, 40))

    # Linhas pautadas.
    for y in range(372, SIZE - 80, 110):
        draw.rounded_rectangle([110, y, SIZE - 110, y + 14], radius=7, fill=(214, 206, 170))

    # Linha de margem vermelha discreta.
    draw.rectangle([180, 262, 190, SIZE], fill=(240, 160, 150))

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    image.save(OUTPUT, "PNG", optimize=True)
    print("Ícone salvo em", OUTPUT)


if __name__ == "__main__":
    main()
