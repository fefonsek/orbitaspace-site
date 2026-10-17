"""Miniatura do post "Quando cada área calcula o mesmo indicador do seu jeito".

Uso: python scripts/miniatura_post_indicadores.py [pt|es|en]

Parte do gráfico das três taxas do caso Um número, três respostas, já
renderizado em docs/ (rode o render antes), e grava uma imagem 640x360 no
mesmo formato das miniaturas do Radar: o gráfico sobre o fundo creme do site,
centralizado em 16:9. Cada língua usa o gráfico da sua versão do caso.
"""
import sys
from pathlib import Path

from PIL import Image

SITE = Path(__file__).resolve().parent.parent
CASO = {
    "pt": "projetos/governanca-indicadores",
    "es": "es/proyectos/gobernanza-indicadores",
    "en": "en/projects/kpi-governance",
}
CREME = (246, 244, 241)  # $creme do orbita.scss
LARGURA, ALTURA = 640, 360


def miniatura(lingua: str) -> Path:
    grafico = SITE / "docs" / CASO[lingua] / "index_files" / "figure-html" / "taxas-1.png"
    img = Image.open(grafico).convert("RGBA")
    fundo = Image.new("RGBA", img.size, CREME + (255,))
    img = Image.alpha_composite(fundo, img).convert("RGB")
    # Margem de 4% em volta e o resto em creme, para fechar 16:9 sem cortar.
    img.thumbnail((int(LARGURA * 0.92), int(ALTURA * 0.92)), Image.LANCZOS)
    tela = Image.new("RGB", (LARGURA, ALTURA), CREME)
    tela.paste(img, ((LARGURA - img.width) // 2, (ALTURA - img.height) // 2))
    saida = SITE / CASO[lingua] / "img" / "taxas_mini.jpg"
    tela.save(saida, quality=85, optimize=True, progressive=True)
    return saida


if __name__ == "__main__":
    for lingua in sys.argv[1:] or ["pt"]:
        print(miniatura(lingua).relative_to(SITE))
