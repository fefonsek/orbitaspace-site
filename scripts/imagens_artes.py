"""Gera as imagens do site que vêm da pasta de artes das duas marcas.

Uso: python scripts/imagens_artes.py

Lê só os arquivos listados abaixo da pasta de artes (orbita-marcas/artes, ao
lado da pasta do site, ou ORBITA_ARTES) e grava versões leves em JPG.
Nenhum outro arquivo da pasta de artes vai para o site.

- As duas aquarelas da página Saline Astral (saline-astral.qmd), em
  assets/img/saline/.
- A faixa de arte que fica logo acima do rodapé em todas as páginas
  (assets/lua/faixa.lua), em assets/img/faixa_orbita.jpg.
"""
import os
from pathlib import Path

from PIL import Image

SITE = Path(__file__).resolve().parent.parent
ARTES = Path(os.environ.get("ORBITA_ARTES") or SITE.parent / "orbita-marcas" / "artes")
IMG = SITE / "assets" / "img"

# origem: (destino, maior lado em px, limite em KB)
IMAGENS = {
    "salineastral_Ethereal_watercolor_landscape_vast_salt_flat_des_38ee8bb5-7235-4398-ad3f-9ba7b98662a6_3 (1).png":
        (IMG / "saline" / "planicie.jpg", 800, 250),
    "salineastral_ethereal_watercolor_illustration_deep_indigo_and_13d65588-a1bc-485e-9c53-8b7848d52e6f_0.png":
        (IMG / "saline" / "sombras.jpg", 800, 250),
    "faixa_fefonsek.png": (IMG / "faixa_orbita.jpg", 2000, 200),
}


def main() -> None:
    for origem, (destino, lado, limite_kb) in IMAGENS.items():
        destino.parent.mkdir(parents=True, exist_ok=True)
        img = Image.open(ARTES / origem).convert("RGB")
        img.thumbnail((lado, lado), Image.LANCZOS)
        # Baixa a qualidade aos poucos até caber no limite.
        for qualidade in range(84, 59, -4):
            img.save(destino, quality=qualidade, optimize=True, progressive=True)
            kb = destino.stat().st_size / 1024
            if kb <= limite_kb:
                break
        print(f"{destino.relative_to(SITE).as_posix()}: {img.size[0]}x{img.size[1]}, qualidade {qualidade}, {kb:.0f} KB")


if __name__ == "__main__":
    main()
