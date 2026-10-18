"""Gera as duas imagens da página Saline Astral (saline-astral.qmd).

Uso: python scripts/imagens_saline.py

Lê só os dois arquivos abaixo da pasta de artes (orbita-marcas/artes, ao lado
da pasta do site, ou ORBITA_ARTES) e grava versões leves em JPG em
assets/img/saline/. Nenhum outro arquivo da pasta de artes vai para o site.
"""
import os
from pathlib import Path

from PIL import Image

SITE = Path(__file__).resolve().parent.parent
ARTES = Path(os.environ.get("ORBITA_ARTES") or SITE.parent / "orbita-marcas" / "artes")
DESTINO = SITE / "assets" / "img" / "saline"
LIMITE_KB = 250

IMAGENS = {
    "salineastral_Ethereal_watercolor_landscape_vast_salt_flat_des_38ee8bb5-7235-4398-ad3f-9ba7b98662a6_3 (1).png": "planicie.jpg",
    "salineastral_ethereal_watercolor_illustration_deep_indigo_and_13d65588-a1bc-485e-9c53-8b7848d52e6f_0.png": "sombras.jpg",
}


def main() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    for origem, destino in IMAGENS.items():
        img = Image.open(ARTES / origem).convert("RGB")
        img.thumbnail((800, 800), Image.LANCZOS)
        # Baixa a qualidade aos poucos até caber no limite.
        for qualidade in range(84, 59, -4):
            img.save(DESTINO / destino, quality=qualidade, optimize=True, progressive=True)
            kb = (DESTINO / destino).stat().st_size / 1024
            if kb <= LIMITE_KB:
                break
        print(f"{destino}: {img.size[0]}x{img.size[1]}, qualidade {qualidade}, {kb:.0f} KB")


if __name__ == "__main__":
    main()
