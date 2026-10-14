"""Prepara as imagens do site a partir do projeto do painel.

Uso: python scripts/preparar_imagens.py
Lê apenas assets/marca e screenshots do projeto de origem (nunca _privado).

O projeto do painel é procurado na pasta "radar-absenteismo-powerbi" ao lado
da pasta do site. Se ele estiver em outro lugar, defina a variável de
ambiente ORBITA_ORIGEM_PAINEL com o caminho, por exemplo no PowerShell:
    $env:ORBITA_ORIGEM_PAINEL = "D:\\projetos\\radar-absenteismo-powerbi"
"""
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps

SITE = Path(__file__).resolve().parent.parent
ORIGEM = Path(os.environ.get("ORBITA_ORIGEM_PAINEL") or SITE.parent / "radar-absenteismo-powerbi")
IMG = SITE / "assets" / "img"
SHOTS = SITE / "projetos" / "radar-absenteismo" / "img"

AZUL_PROFUNDO = (26, 26, 46, 255)


def recortar(img: Image.Image) -> Image.Image:
    """Remove a margem transparente em volta do logo."""
    return img.crop(img.getchannel("A").getbbox())


def logos() -> None:
    IMG.mkdir(parents=True, exist_ok=True)
    marca = ORIGEM / "assets" / "marca"
    for origem, destino, lado in [
        ("logo_fefonsek_branco.png", "logo-branco.png", 128),
        # Detalhe ao fundo da página inicial. Depois do recorte o logo tem
        # 317 px, então este limite não chega a reduzir nada (thumbnail não amplia).
        ("logo_fefonsek_original.png", "logo-original.png", 480),
    ]:
        img = recortar(Image.open(marca / origem).convert("RGBA"))
        img.thumbnail((lado, lado), Image.LANCZOS)
        img.save(IMG / destino, optimize=True)


def _icone(espessura: int) -> Image.Image:
    """Logo branco sobre quadrado arredondado azul profundo.

    As linhas do logo são finas; engrossamos antes de reduzir para que
    continuem visíveis em 16 e 32 px.
    """
    base = 512
    logo = recortar(Image.open(ORIGEM / "assets" / "marca" / "logo_fefonsek_branco.png").convert("RGBA"))
    logo = logo.resize((int(base * 0.78),) * 2, Image.LANCZOS)
    alfa = logo.getchannel("A").filter(ImageFilter.MaxFilter(espessura))
    branco = Image.new("RGBA", logo.size, (255, 255, 255, 255))
    branco.putalpha(alfa)

    fundo = Image.new("RGBA", (base, base), (0, 0, 0, 0))
    ImageDraw.Draw(fundo).rounded_rectangle((0, 0, base - 1, base - 1), radius=96, fill=AZUL_PROFUNDO)
    margem = (base - logo.size[0]) // 2
    fundo.alpha_composite(branco, (margem, margem))

    return fundo


def favicon() -> None:
    pequeno = _icone(9)
    pequeno.save(IMG / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
    pequeno.resize((32, 32), Image.LANCZOS).save(IMG / "favicon-32.png", optimize=True)
    _icone(5).resize((180, 180), Image.LANCZOS).save(IMG / "apple-touch-icon.png", optimize=True)


def compartilhamento_site() -> None:
    """Imagem padrão de compartilhamento (1200x630): logo branco sobre azul profundo.

    O nome aparece no título do cartão de cada rede social; a imagem fica só
    com a marca, sem texto, para não depender de fontes instaladas.
    """
    largura, altura = 1200, 630
    fundo = Image.new("RGBA", (largura, altura), AZUL_PROFUNDO)
    logo = recortar(Image.open(ORIGEM / "assets" / "marca" / "logo_fefonsek_branco.png").convert("RGBA"))
    logo = logo.resize((380, 380), Image.LANCZOS)
    fundo.alpha_composite(logo, ((largura - 380) // 2, (altura - 380) // 2))
    fundo.convert("RGB").save(IMG / "compartilhamento-site.jpg", quality=88, optimize=True)


def foto() -> None:
    """Retrato quadrado: 800 px (Sobre) e 240 px (Contato).

    Medidas feitas à mão na foto original (1024 x 1024), com uma grade de 25 px:
    centro horizontal do rosto em x = 467 (entre o nariz e os limites das
    bochechas; a cabeça está levemente inclinada) e linha dos olhos em y = 422.
    O recorte põe o rosto no centro horizontal e os olhos a 40% da altura.
    Se a foto mudar, meça de novo e ajuste ROSTO_X e OLHOS_Y.
    """
    ROSTO_X, OLHOS_Y, ALTURA_OLHOS = 467 / 1024, 422 / 1024, 0.40
    original = ImageOps.exif_transpose(Image.open(IMG / "felipe-original.jpeg")).convert("RGB")
    largura, altura = original.size

    def recorte(lado: int, altura_olhos: float = ALTURA_OLHOS) -> Image.Image:
        x0 = ROSTO_X * largura - lado / 2
        y0 = OLHOS_Y * altura - altura_olhos * lado
        x0 = min(max(x0, 0), largura - lado)
        y0 = min(max(y0, 0), altura - lado)
        return original.crop((round(x0), round(y0), round(x0 + lado), round(y0 + lado)))

    # Lados em pixels da foto de 1024 px. Sobre: 0,54 da largura, olhos a 40%.
    # O recorte (553 px) é ampliado para 800 px; no site a foto aparece com
    # cerca de 208 px (416 px em telas retina), então a ampliação não aparece.
    recorte(round(0.54 * largura)).resize((800, 800), Image.LANCZOS).save(
        IMG / "felipe-800.jpg", quality=84, optimize=True, progressive=True)
    # Contato (avatar redondo): olhos a 44% para sobrar respiro entre o topo do
    # cabelo (y ~ 232 na original) e a borda do círculo.
    recorte(round(0.54 * largura), altura_olhos=0.44).resize((240, 240), Image.LANCZOS).save(
        IMG / "felipe-240.jpg", quality=84, optimize=True, progressive=True)


def screenshots() -> None:
    """Versões web das telas do painel: 1600 px para o lightbox e miniaturas.

    As miniaturas da galeria têm 640 px (aparecem com ~260 a 340 px). A da capa
    fica com 800 px porque também é a imagem do "Em destaque" no Início, onde
    aparece com ~550 px no desktop.
    """
    SHOTS.mkdir(parents=True, exist_ok=True)
    for png in sorted((ORIGEM / "screenshots").glob("*.png")):
        img = Image.open(png).convert("RGB")
        grande = img.copy()
        grande.thumbnail((1600, 1600), Image.LANCZOS)
        grande.save(SHOTS / f"{png.stem}.jpg", quality=85, optimize=True, progressive=True)
        mini = img.copy()
        lado = 800 if png.stem == "00_capa" else 640
        mini.thumbnail((lado, lado), Image.LANCZOS)
        mini.save(SHOTS / f"{png.stem}_mini.jpg", quality=82, optimize=True, progressive=True)
    # Imagem de compartilhamento (Open Graph): 1200x675, mesma proporção 16:9.
    capa = Image.open(ORIGEM / "screenshots" / "00_capa.png").convert("RGB")
    capa.resize((1200, 675), Image.LANCZOS).save(SHOTS / "compartilhamento.jpg", quality=85, optimize=True)


if __name__ == "__main__":
    if not (ORIGEM / "screenshots").is_dir():
        raise SystemExit(
            f"Projeto do painel não encontrado em {ORIGEM}.\n"
            "Coloque a pasta radar-absenteismo-powerbi ao lado da pasta do site "
            "ou defina ORBITA_ORIGEM_PAINEL com o caminho dela."
        )
    logos()
    favicon()
    compartilhamento_site()
    foto()
    screenshots()
    print("Imagens prontas.")
