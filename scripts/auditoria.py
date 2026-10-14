"""Auditoria do site gerado em docs/ (só lê; não altera nada).

Uso: python scripts/auditoria.py

Confere:
1. peso de todas as imagens publicadas;
2. og:title e título da aba de cada página;
3. links internos quebrados (arquivos e âncoras #id);
4. hreflang: cada página aponta para as três versões, as versões existem
   e apontam de volta para ela (reciprocidade).
"""
import re
import sys
from collections import defaultdict
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

DOCS = Path(__file__).resolve().parent.parent / "docs"
URL_SITE = "https://orbitaspace.com.br"
LIMITE_KB = 250  # acima disso a imagem é listada como "pesada"


class Coletor(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.links: list[tuple[str, str]] = []  # (atributo, valor)
        self.ids: set[str] = set()
        self.hreflang: dict[str, str] = {}
        self.og_title = ""
        self.titulo = ""
        self._no_titulo = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.add(a["id"])
        if tag == "link" and a.get("rel") == "alternate" and a.get("hreflang"):
            self.hreflang[a["hreflang"]] = a.get("href", "")
            return
        if tag == "meta" and a.get("property") == "og:title":
            self.og_title = a.get("content", "")
        if tag == "title":
            self._no_titulo = True
        for attr in ("href", "src"):
            if a.get(attr):
                self.links.append((attr, a[attr]))

    def handle_endtag(self, tag):
        if tag == "title":
            self._no_titulo = False

    def handle_data(self, data):
        if self._no_titulo:
            self.titulo += data


def paginas() -> list[Path]:
    return sorted(p for p in DOCS.rglob("*.html") if "site_libs" not in p.parts)


def rel(p: Path) -> str:
    return p.relative_to(DOCS).as_posix()


def idioma(p: Path) -> str:
    topo = rel(p).split("/")[0]
    return topo if topo in ("es", "en") else "pt"


def main() -> int:
    problemas: list[str] = []
    dados = {}
    for p in paginas():
        c = Coletor()
        c.feed(p.read_text(encoding="utf-8"))
        dados[p] = c

    # 1. Peso das imagens
    print("== 1. Imagens publicadas ==")
    imagens = sorted((q for q in DOCS.rglob("*") if q.suffix.lower() in (".jpg", ".jpeg", ".png", ".ico", ".svg", ".webp")
                      and "site_libs" not in q.parts), key=lambda q: -q.stat().st_size)
    total = sum(q.stat().st_size for q in imagens)
    for q in imagens:
        kb = q.stat().st_size / 1024
        marca = "  <- pesada" if kb > LIMITE_KB else ""
        print(f"  {kb:7.1f} KB  {rel(q)}{marca}")
    print(f"  Total: {len(imagens)} imagens, {total / 1024:.0f} KB")

    # 2. Títulos
    print("\n== 2. Título da aba e og:title ==")
    for lang in ("pt", "es", "en"):
        print(f"  [{lang}]")
        for p, c in dados.items():
            if idioma(p) != lang:
                continue
            igual = "" if c.og_title.strip() == c.titulo.strip() else f"   (aba: {c.titulo.strip()})"
            print(f"    {rel(p):48} {c.og_title}{igual}")
            if not c.og_title:
                problemas.append(f"sem og:title: {rel(p)}")

    # 3. Links internos
    print("\n== 3. Links internos ==")
    verificados = 0
    for p, c in dados.items():
        for attr, valor in c.links:
            partes = urlsplit(valor)
            if partes.scheme in ("mailto", "tel", "data", "javascript"):
                continue
            if partes.scheme in ("http", "https"):
                if not valor.startswith(URL_SITE):
                    continue  # link externo
                caminho = partes.path
                alvo = DOCS / unquote(caminho).lstrip("/")
            elif partes.path.startswith("/"):
                alvo = DOCS / unquote(partes.path).lstrip("/")
            elif partes.path == "":
                alvo = p  # âncora na própria página
            else:
                alvo = (p.parent / unquote(partes.path)).resolve()
            if alvo.is_dir():
                alvo = alvo / "index.html"
            verificados += 1
            if not alvo.is_file():
                problemas.append(f"link quebrado em {rel(p)}: {attr}=\"{valor}\"")
                continue
            if partes.fragment and alvo.suffix == ".html":
                ids = dados[alvo.resolve()].ids if alvo.resolve() in dados else set()
                if unquote(partes.fragment) not in ids:
                    problemas.append(f"âncora inexistente em {rel(p)}: {valor}")
    print(f"  {verificados} links e recursos internos verificados.")

    # 4. hreflang
    print("\n== 4. hreflang ==")
    por_url = {URL_SITE + "/" + rel(p): p for p in dados}
    com_hreflang = 0
    for p, c in dados.items():
        if not c.hreflang:
            print(f"  sem hreflang (esperado só em post sem tradução): {rel(p)}")
            continue
        com_hreflang += 1
        proprio = URL_SITE + "/" + rel(p)
        codigos = set(c.hreflang)
        if codigos != {"pt-BR", "es", "en", "x-default"}:
            problemas.append(f"hreflang incompleto em {rel(p)}: {sorted(codigos)}")
        if proprio not in c.hreflang.values():
            problemas.append(f"hreflang de {rel(p)} não inclui a própria página")
        for codigo, url in c.hreflang.items():
            destino = por_url.get(url)
            if destino is None:
                problemas.append(f"hreflang {codigo} de {rel(p)} aponta para página inexistente: {url}")
                continue
            if proprio not in dados[destino].hreflang.values():
                problemas.append(f"hreflang sem volta: {rel(p)} -> {rel(destino)}")
    print(f"  {com_hreflang} páginas com hreflang; reciprocidade conferida.")

    print("\n== Resultado ==")
    if problemas:
        print("\n".join(f"  - {x}" for x in problemas))
        return 1
    print("  Nenhum problema encontrado.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
