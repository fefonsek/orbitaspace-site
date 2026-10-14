"""Passo final do render.ps1.

1. Junta os sitemaps dos três perfis em docs/sitemap.xml.
2. Confere se cada página de _traducoes.yml existe em docs/ e no sitemap.
3. Avisa em vermelho se algum marcador provisório ([VÍDEO AQUI],
   [LINK DO REPOSITÓRIO]) ainda aparece em docs/: o site não deve ser
   publicado com eles.
4. Põe um sufixo de versão nas imagens (foto.jpg?v=<hash>), para que uma
   imagem trocada apareça atualizada mesmo com o cache do navegador.

Uso: python scripts/pos_render.py <pasta com sitemap-pt.xml, sitemap-es.xml, sitemap-en.xml>
"""
import hashlib
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent
DOCS = SITE / "docs"
NS = "http://www.sitemaps.org/schemas/sitemap/0.9"
URL_SITE = "https://orbitaspace.com.br"
# Com e sem acento, para pegar também uma digitação sem "Í".
MARCADORES = re.compile(r"V[ÍI]DEO AQUI|LINK DO REPOSIT[ÓO]RIO", re.IGNORECASE)
VERMELHO, NORMAL = "\033[91m", "\033[0m"


def juntar_sitemaps(pasta: Path) -> set[str]:
    ET.register_namespace("", NS)
    raiz = ET.Element(f"{{{NS}}}urlset")
    vistos: set[str] = set()
    for idioma in ("pt", "es", "en"):
        arvore = ET.parse(pasta / f"sitemap-{idioma}.xml")
        for url in arvore.getroot().findall(f"{{{NS}}}url"):
            loc = url.findtext(f"{{{NS}}}loc")
            if loc and loc not in vistos:
                vistos.add(loc)
                raiz.append(url)
    ET.indent(raiz)
    ET.ElementTree(raiz).write(DOCS / "sitemap.xml", encoding="utf-8", xml_declaration=True)
    return vistos


def paginas_esperadas() -> list[str]:
    texto = (SITE / "_traducoes.yml").read_text(encoding="utf-8")
    return re.findall(r"^\s+(?:pt|es|en):\s*(/\S+)", texto, flags=re.MULTILINE)


def marcadores_pendentes() -> list[str]:
    achados = []
    for arquivo in sorted(DOCS.rglob("*")):
        if arquivo.suffix not in (".html", ".xml") or "site_libs" in arquivo.parts:
            continue
        texto = arquivo.read_text(encoding="utf-8", errors="ignore")
        for marcador in sorted({m.group(0) for m in MARCADORES.finditer(texto)}):
            achados.append(f"{arquivo.relative_to(DOCS).as_posix()}: [{marcador}]")
    return achados


SUFIXO_QUARTO = " – Orbita Space"  # o Quarto junta o título do site com meia-risca
TITULOS = re.compile(
    r'(<title>)(.*?)(</title>)|(<meta (?:property|name)="(?:og|twitter):title" content=")(.*?)(")',
    re.DOTALL,
)


def corrigir_titulos() -> int:
    """Troca o separador "–" que o Quarto põe no título da aba por "·"."""
    alterados = 0

    def trocar(m: re.Match) -> str:
        abre, texto, fecha = (m.group(1), m.group(2), m.group(3)) if m.group(1) else (m.group(4), m.group(5), m.group(6))
        if texto.endswith(SUFIXO_QUARTO):
            base = texto[: -len(SUFIXO_QUARTO)]
            texto = base if "Orbita Space" in base else base + " · Orbita Space"
        return abre + texto + fecha

    for arquivo in DOCS.rglob("*.html"):
        if "site_libs" in arquivo.parts:
            continue
        original = arquivo.read_text(encoding="utf-8")
        novo = TITULOS.sub(trocar, original)
        if novo != original:
            arquivo.write_text(novo, encoding="utf-8")
            alterados += 1
    return alterados


# Imagens citadas em atributos do HTML e do RSS (src, href do lightbox,
# og:image, srcset, url do <media:content> do feed...). Um "?v=..." que já exista é substituído, então rodar
# o script de novo não acumula sufixos.
IMAGEM_EM_ATRIBUTO = re.compile(
    r'(?P<attr>\b(?:src|href|content|srcset|data-src|url)=)(?P<q>["\'])'
    r'(?P<url>[^"\'?#\s]+\.(?:jpe?g|png|webp|gif|svg|ico))'
    r'(?:\?v=[0-9a-f]+)?(?P=q)',
    re.IGNORECASE,
)


def versionar_imagens() -> tuple[int, list[str]]:
    """Acrescenta ?v=<8 primeiros caracteres do md5 do arquivo> a cada imagem local.

    O hash só muda quando o conteúdo da imagem muda; imagens iguais mantêm o
    mesmo endereço e continuam aproveitando o cache.
    """
    hashes: dict[Path, str] = {}
    nao_encontradas: set[str] = set()
    trocas = 0

    def hash_de(caminho: Path) -> str:
        if caminho not in hashes:
            hashes[caminho] = hashlib.md5(caminho.read_bytes()).hexdigest()[:8]
        return hashes[caminho]

    for arquivo in sorted(DOCS.rglob("*")):
        if arquivo.suffix not in (".html", ".xml") or "site_libs" in arquivo.parts:
            continue

        def trocar(m: re.Match) -> str:
            nonlocal trocas
            url = m.group("url")
            if url.startswith(URL_SITE + "/"):
                local = DOCS / url[len(URL_SITE) + 1:]
            elif url.startswith("/"):
                local = DOCS / url.lstrip("/")
            elif "://" in url or url.startswith("data:"):
                return m.group(0)  # imagem de outro site: não mexe
            else:
                local = arquivo.parent / url
            local = local.resolve()
            if not local.is_file():
                nao_encontradas.add(f"{arquivo.relative_to(DOCS).as_posix()}: {url}")
                return m.group(0)
            trocas += 1
            q = m.group("q")
            return f'{m.group("attr")}{q}{url}?v={hash_de(local)}{q}'

        original = arquivo.read_text(encoding="utf-8")
        novo = IMAGEM_EM_ATRIBUTO.sub(trocar, original)
        if novo != original:
            arquivo.write_text(novo, encoding="utf-8")
    return trocas, sorted(nao_encontradas)


def travessoes_no_site() -> list[str]:
    """Procura — e – no texto visível e nos metadados (title, description), fora de <script> e <style>."""
    achados = []
    for arquivo in sorted(DOCS.rglob("*")):
        if arquivo.suffix not in (".html", ".xml") or "site_libs" in arquivo.parts:
            continue
        texto = arquivo.read_text(encoding="utf-8", errors="ignore")
        texto = re.sub(r"<(script|style)\b.*?</\1>", "", texto, flags=re.DOTALL | re.IGNORECASE)
        for m in re.finditer(r".{0,40}[—–].{0,40}", texto):
            achados.append(f"{arquivo.relative_to(DOCS).as_posix()}: ...{m.group(0).strip()}...")
    return achados


def main() -> int:
    os.system("")  # liga as cores ANSI no console do Windows
    no_sitemap = juntar_sitemaps(Path(sys.argv[1]))
    faltando = []
    for caminho in paginas_esperadas():
        if not (DOCS / caminho.lstrip("/")).is_file():
            faltando.append(f"arquivo ausente: docs{caminho}")
        if URL_SITE + caminho not in no_sitemap:
            faltando.append(f"fora do sitemap: {caminho}")

    contagem = {
        "docs/ (PT)": sum(1 for p in DOCS.rglob("*.html") if p.relative_to(DOCS).parts[0] not in ("es", "en", "site_libs")),
        "docs/es": sum(1 for _ in (DOCS / "es").rglob("*.html")),
        "docs/en": sum(1 for _ in (DOCS / "en").rglob("*.html")),
    }
    print("\nPáginas HTML geradas:", ", ".join(f"{k}: {v}" for k, v in contagem.items()))
    print(f"Sitemap: {len(no_sitemap)} endereços.")

    print(f"Títulos corrigidos (separador do Quarto): {corrigir_titulos()} páginas.")
    versionadas, sem_arquivo = versionar_imagens()
    print(f"Imagens com sufixo de versão (?v=hash): {versionadas} referências.")
    faltando += [f"imagem citada mas não encontrada em docs/: {s}" for s in sem_arquivo]
    travessoes = travessoes_no_site()
    if travessoes:
        print(f"\n{VERMELHO}TRAVESSÃO (— ou –) NO TEXTO DO SITE:")
        print("\n".join(f"  - {t}" for t in travessoes[:20]) + NORMAL)

    pendentes = marcadores_pendentes()
    if pendentes:
        print(f"\n{VERMELHO}MARCADORES PROVISÓRIOS NO SITE: NÃO PUBLIQUE ASSIM.")
        print("\n".join(f"  - {p}" for p in pendentes) + NORMAL)

    # No render comum o marcador só avisa; ao publicar (publicar.ps1) é erro.
    if os.environ.get("ORBITA_PUBLICAR") == "1":
        faltando += [f"marcador provisório: {p}" for p in pendentes]
    faltando += [f"travessão: {t}" for t in travessoes]
    # A foto original fica só na pasta de origem; o site usa os recortes.
    faltando += [f"foto original não deve ir ao ar: {p.relative_to(DOCS).as_posix()}"
                 for p in DOCS.rglob("felipe-original*")]
    if faltando:
        print("\nPROBLEMAS:")
        print("\n".join(f"  - {f}" for f in faltando))
        return 1
    if pendentes:
        print("Estrutura certa (todas as páginas existem e estão no sitemap), mas troque os marcadores acima antes de publicar.")
    else:
        print("Tudo certo: todas as páginas dos três idiomas existem e estão no sitemap.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
