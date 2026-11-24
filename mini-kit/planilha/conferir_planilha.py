"""Mini-kit: confere as fórmulas da planilha padrão com o pycel.

Uso, na pasta do site (depois de mini-kit/planilha/gerar_planilha.R):
    python mini-kit/planilha/conferir_planilha.py

Precisa do pycel e do openpyxl (pip install pycel); a pasta dos pacotes pode
vir de ORBITA_PYCEL. O pycel calcula as fórmulas como o Excel, sem abrir o
Excel. Este script refaz as mesmas regras em Python, a partir só do que foi
digitado (cards e lançamentos), e compara célula a célula:
- versão com exemplo: Indicador, Resultado, Referência, Variação e Situação de
  todos os lançamentos, e o Painel inteiro;
- versão em branco: fórmulas vazias, sem erro.
Para com erro se alguma célula não bater. A conferência no Google Planilhas
e no Excel (abrir os arquivos e olhar o Painel) complementa esta.
"""
import os
import sys
from datetime import datetime
from pathlib import Path

if os.environ.get("ORBITA_PYCEL"):
    sys.path.insert(0, os.environ["ORBITA_PYCEL"])
from openpyxl import load_workbook  # noqa: E402
from pycel import ExcelCompiler  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8")
PASTA = Path(__file__).resolve().parent
LAN, IND, PAINEL = "Lançamentos", "Indicadores", "Painel"


def vazio(v):
    return v is None or v == ""


def esperado(cards, lancs):
    """Regras da planilha, em Python: devolve as colunas calculadas por linha."""
    saida = {}
    for linha, (periodo, id_, num, den) in lancs.items():
        c = cards.get(id_)
        res = None
        if not vazio(num):
            res = num if vazio(den) else num / den * (100 if c["unidade"] == "%" else 1)
        saida[linha] = {"ind": c["nome"] if c else "ID não cadastrado", "res": res}
    # Referência: média dos até 3 lançamentos anteriores (pela data) do mesmo ID.
    for linha, (periodo, id_, num, den) in lancs.items():
        res = saida[linha]["res"]
        prev = sorted((p2, saida[l2]["res"]) for l2, (p2, i2, n2, _) in lancs.items()
                      if i2 == id_ and not vazio(n2) and p2 < periodo)
        ref = sum(r for _, r in prev[-3:]) / len(prev[-3:]) if prev and res is not None else None
        var = res - ref if ref is not None else None
        sit = None
        c = cards[id_]
        if ref is not None and not vazio(c["tol_at"]) and not vazio(c["tol_ac"]):
            piora = round(res - ref if c["pol"] == "Menor é melhor" else ref - res, 9)
            sit = "Vermelho" if piora >= c["tol_ac"] else "Amarelo" if piora > c["tol_at"] else "Verde"
        saida[linha].update(ref=ref, var=var, sit=sit)
    return saida


def ler(arquivo):
    wb = load_workbook(arquivo)
    cards = {}
    for row in wb[IND].iter_rows(min_row=2, values_only=True):
        if vazio(row[0]):
            continue
        cards[row[0]] = {"nome": row[1], "unidade": row[6], "pol": row[7], "tol_at": row[9], "tol_ac": row[10]}
    lancs = {}
    for k, row in enumerate(wb[LAN].iter_rows(min_row=2, max_col=5, values_only=True), start=2):
        if vazio(row[1]):
            continue
        lancs[k] = (row[0], row[1], row[3], row[4])
    return cards, lancs


def igual(a, b):
    if vazio(a) and vazio(b):
        return True
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(a - b) < 1e-6
    return a == b


problemas = []
# 1. Versão com exemplo.
arq = PASTA / "planilha_padrao_indicadores_exemplo.xlsx"
cards, lancs = ler(arq)
esp = esperado(cards, lancs)
xl = ExcelCompiler(filename=str(arq))
cols = {"ind": "C", "res": "F", "ref": "G", "var": "H", "sit": "I"}
for linha, e in esp.items():
    for chave, col in cols.items():
        v = xl.evaluate(f"'{LAN}'!{col}{linha}")
        if not igual(v, e[chave]):
            problemas.append(f"{LAN}!{col}{linha}: planilha {v!r}, esperado {e[chave]!r}")
# Linhas sem lançamento ficam vazias.
for linha in (max(lancs) + 1, max(lancs) + 2):
    for col in cols.values():
        v = xl.evaluate(f"'{LAN}'!{col}{linha}")
        if not vazio(v):
            problemas.append(f"{LAN}!{col}{linha} deveria estar vazia: {v!r}")

print(f"Exemplo: {len(cards)} indicadores, {len(lancs)} lançamentos conferidos.")
print("Painel (calculado pelo pycel):")
for k, id_ in enumerate(cards, start=2):
    ultimo = max(l for l, (p, i, n, d) in lancs.items() if i == id_ and not vazio(n))
    e = esp[ultimo]
    linha_p = [xl.evaluate(f"'{PAINEL}'!{c}{k}") for c in "ABCDEFGHI"]
    p_esp = [id_, cards[id_]["nome"], cards[id_]["unidade"], cards[id_]["pol"], lancs[ultimo][0],
             e["res"], e["ref"], e["var"], e["sit"]]
    for c, v, w in zip("ABCDEFGHI", linha_p, p_esp):
        if isinstance(w, datetime):
            w = (w - datetime(1899, 12, 30)).days  # data como número de série do Excel
        if not igual(v, w):
            problemas.append(f"{PAINEL}!{c}{k}: planilha {v!r}, esperado {w!r}")
    print(f"  {id_} {cards[id_]['nome']}: último {lancs[ultimo][0]:%m/%Y}, resultado {linha_p[5]:.2f}, "
          f"referência {linha_p[6]:.2f}, variação {linha_p[7]:+.2f}, situação {linha_p[8]}")
for c in "ABCDEFGHI":
    v = xl.evaluate(f"'{PAINEL}'!{c}{len(cards) + 2}")
    if not vazio(v):
        problemas.append(f"{PAINEL}!{c}{len(cards) + 2} deveria estar vazia: {v!r}")
print("Situação de cada lançamento:")
for id_ in cards:
    print(f"  {id_}: " + " ".join((esp[l]["sit"] or "-")[:2] for l in sorted(esp) if lancs[l][1] == id_))

# 2. Versão em branco: fórmulas vazias, sem erro.
arq = PASTA / "planilha_padrao_indicadores.xlsx"
xl = ExcelCompiler(filename=str(arq))
for ref in [f"'{LAN}'!{c}{l}" for c in "CFGHI" for l in (2, 3, 2001)] + \
           [f"'{PAINEL}'!{c}{l}" for c in "ABCDEFGHI" for l in (2, 51)]:
    v = xl.evaluate(ref)
    if not vazio(v):
        problemas.append(f"em branco: {ref} deveria estar vazia: {v!r}")
print("Em branco: fórmulas vazias conferidas.")

if problemas:
    print("\nPROBLEMAS:")
    for p in problemas:
        print("  " + p)
    sys.exit(1)
print("Tudo certo: as fórmulas batem com as regras.")
