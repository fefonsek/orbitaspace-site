"""Roda depois de cada "quarto render" (post-render em _quarto.yml).

Se o Quarto foi chamado direto, e não pelo render.ps1, a renderização
apagou docs/es e docs/en (ou docs/ inteiro). Este aviso diz como refazer.
"""
import os
from pathlib import Path

if os.environ.get("ORBITA_RENDER_COMPLETO") != "1":
    docs = Path(__file__).resolve().parent.parent / "docs"
    faltam = [p for p in ("index.html", "es/index.html", "en/index.html") if not (docs / p).is_file()]
    if faltam:
        print(
            "\n" + "!" * 68 + "\n"
            "  ATENÇÃO: a pasta docs/ ficou incompleta (faltam: " + ", ".join(faltam) + ").\n"
            "  Renderizar um idioma sozinho apaga os outros. Para o site\n"
            "  completo, rode no PowerShell:   .\\render.ps1\n"
            + "!" * 68 + "\n"
        )
