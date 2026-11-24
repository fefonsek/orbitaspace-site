"""Planilha padrão de indicadores (mini-kit). Gera duas versões: em branco e com exemplo."""
import sys
from datetime import date
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.formatting.rule import CellIsRule, FormulaRule
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.comments import Comment
from openpyxl.styles.differential import DifferentialStyle

ESCURO, AZUL, LAVANDA, CLARO = "1A1A2E", "3473C0", "CACFEE", "F6F4F1"
ENTRADA = "EEF0FA"   # células para preencher
CALC = "F6F4F1"      # células calculadas
FONTE = "Arial"
N_IND = 30           # linhas de indicadores
N_LAN = 500          # linhas de lançamentos
LIN = f"$2:${N_LAN+1}"

def f(size=10, bold=False, color="1A1A2E", italic=False):
    return Font(name=FONTE, size=size, bold=bold, color=color, italic=italic)

fill = lambda c: PatternFill("solid", start_color=c, end_color=c)
fina = Side(style="thin", color=LAVANDA)
borda = Border(left=fina, right=fina, top=fina, bottom=fina)

def cabecalho(ws, linha, nomes, larguras, cor=ESCURO):
    for i, (n, w) in enumerate(zip(nomes, larguras), start=1):
        c = ws.cell(linha, i, n)
        c.font = f(10, True, "FFFFFF")
        c.fill = fill(cor)
        c.alignment = Alignment(vertical="center", horizontal="left", wrap_text=True, indent=1)
        c.border = borda
        ws.column_dimensions[c.column_letter].width = w
    ws.row_dimensions[linha].height = 34

def corpo(c, entrada, wrap=False, fmt=None):
    c.font = f(10)
    c.fill = fill(ENTRADA if entrada else CALC)
    c.border = borda
    c.alignment = Alignment(vertical="top", wrap_text=wrap, indent=1 if not fmt else 0)
    if fmt:
        c.number_format = fmt

def semaforo(ws, rng):
    regras = [("Verde", "D9F2E0", "1E6B3A"), ("Amarelo", "FFF2C2", "7A5A00"), ("Vermelho", "F9D5D3", "9B1C1C")]
    for txt, bg, fg in regras:
        ws.conditional_formatting.add(rng, CellIsRule(operator="equal", formula=[f'"{txt}"'],
                                      fill=fill(bg), font=Font(name=FONTE, bold=True, color=fg)))

# ---------------------------------------------------------------- exemplo
EX_IND = [
    dict(id="CX", nome="Quanto do faturado virou caixa",
         serve="Estou vendendo ou estou recebendo?",
         memoria="Total recebido no mês ÷ total vendido no mês × 100. Exemplo: R$112 mil recebidos ÷ R$120 mil vendidos = 93,3%.",
         num="Total recebido no mês (extrato do banco + dinheiro)", den="Total vendido no mês (à vista e a prazo)",
         un="%", pol="Maior é melhor", per="Mensal", ta=4, tb=8,
         fonte="Extrato do banco e caderno de vendas", resp="Dono"),
    dict(id="TM", nome="Ticket médio",
         serve="Cada cliente está comprando mais ou menos?",
         memoria="Total vendido no mês ÷ número de vendas no mês. Exemplo: R$120 mil ÷ 800 vendas = R$150.",
         num="Total vendido no mês", den="Número de vendas no mês",
         un="R$", pol="Maior é melhor", per="Mensal", ta=3, tb=8,
         fonte="Caderno de vendas ou sistema do caixa", resp="Gerente"),
    dict(id="SP", nome="Saldo projetado para 30 dias",
         serve="Vou fechar o próximo mês no azul?",
         memoria="Caixa hoje + a receber nos próximos 30 dias − a pagar nos próximos 30 dias. Não é divisão: lance o saldo já somado no Numerador e deixe o Denominador vazio.",
         num="Caixa hoje + a receber em 30 dias − a pagar em 30 dias (já somado)", den="(vazio)",
         un="R$", pol="Maior é melhor", per="Mensal", ta=3000, tb=6000,
         fonte="Extrato do banco, contas a receber e contas a pagar", resp="Dono"),
]
MESES = [date(2026, m, 1) for m in range(3, 11)]
VENDIDO = [120000, 118000, 125000, 130000, 127000, 122000, 135000, 128000]
RECEBIDO = [112000, 111000, 116000, 121000, 118000, 110000, 119000, 104000]
N_VENDAS = [800, 790, 820, 840, 830, 800, 860, 850]
SALDO = [18000, 21000, 19500, 23000, 22000, 24000, 21500, 23500]
OBS = {("CX", 7): "Duas construtoras atrasaram o pagamento de outubro."}

def gerar(caminho, exemplo):
    wb = Workbook()

    # ============================================================ Leia-me
    ws = wb.active
    ws.title = "Leia-me"
    ws.sheet_view.showGridLines = False
    ws.column_dimensions["A"].width = 3
    ws.column_dimensions["B"].width = 26
    ws.column_dimensions["C"].width = 92
    r = 2
    ws.cell(r, 2, "Planilha padrão de indicadores").font = f(18, True)
    r += 1
    ws.cell(r, 2, "Versão com exemplo fictício" if exemplo else "Versão em branco, para os seus indicadores").font = f(11, False, AZUL)
    r += 2
    blocos = [
        ("Como usar", None),
        ("1. Indicadores", "Cadastre cada indicador numa linha, como um card: o que ele mede, como é calculado, de onde vem o dado e como ler. Use um ID curto (ex.: CX, TM)."),
        ("2. Lançamentos", "A cada período, lance uma linha por indicador: a data do período, o ID, o numerador e o denominador. O resto a planilha calcula."),
        ("3. Painel", "Mostra o último resultado de cada indicador, a referência e a situação: verde, amarelo ou vermelho."),
        ("Cores das células", None),
        ("Lavanda", "Você preenche."),
        ("Bege", "A planilha calcula. Não digite por cima."),
        ("Regras", None),
        ("Colunas", "Não crie, não apague, não renomeie e não mude a ordem das colunas. Se um indicador não couber, adapte o jeito de lançar o dado, não a planilha. É essa estrutura fixa que permite transformar a planilha num painel depois."),
        ("Indicador sem divisão", "Se o indicador não for uma divisão (ex.: saldo projetado), lance o valor já calculado no Numerador e deixe o Denominador vazio."),
        ("Indicador em %", "Com Unidade \"%\", o resultado sai de 0 a 100 e as tolerâncias são em pontos (ex.: de 92 para 88 são 4 pontos)."),
        ("Período", "Digite uma data: para indicadores mensais, o dia 1 do mês (ex.: 01/03/2026). Uma linha por indicador e período."),
        ("Glossário do card", None),
        ("Polaridade", "Maior é melhor (vendas, caixa) ou Menor é melhor (prazo de recebimento, inadimplência)."),
        ("Periodicidade", "De quanto em quanto tempo o indicador é medido: diária, semanal ou mensal."),
        ("Referência", "A média dos até 3 lançamentos anteriores do mesmo indicador. É com ela que o número de hoje é comparado enquanto não há meta."),
        ("Tolerância de atenção", "Quanto o número pode piorar em relação à referência antes de virar amarelo. Na mesma unidade do indicador."),
        ("Tolerância de ação", "A partir de quanto de piora ele vira vermelho e pede ação imediata."),
        ("Meta", "Fica vazia neste começo. Com pelo menos 12 meses de lançamentos, dá para ver o padrão da empresa, os meses fortes e os fracos, e definir metas por período com base no quanto você quer crescer no ano seguinte."),
        ("Funciona em", None),
        ("", "Excel e Google Planilhas. No Google, faça o upload do arquivo no Drive e abra com o Google Planilhas."),
    ]
    for rot, txt in blocos:
        if txt is None:
            r += 1
            c = ws.cell(r, 2, rot)
            c.font = f(12, True, AZUL)
            r += 1
            continue
        a = ws.cell(r, 2, rot)
        a.font = f(10, True)
        a.alignment = Alignment(vertical="top")
        b = ws.cell(r, 3, txt)
        b.font = f(10)
        b.alignment = Alignment(vertical="top", wrap_text=True)
        if rot == "Lavanda":
            a.fill = fill(ENTRADA)
        if rot == "Bege":
            a.fill = fill(CALC)
        ws.row_dimensions[r].height = 15 * max(1, -(-len(txt) // 100))
        r += 1
    r += 2
    ws.cell(r, 2, "Felipe Fonseca · Orbita Space · orbitaspace.com.br").font = f(9, False, "7A90C4")
    if exemplo:
        r += 1
        ws.cell(r, 2, "Os números deste exemplo são fictícios.").font = f(9, False, "7A90C4", italic=True)

    # ============================================================ Indicadores
    wi = wb.create_sheet("Indicadores")
    cols_i = ["ID", "Indicador", "Para que serve", "Memória de cálculo", "Numerador", "Denominador",
              "Unidade", "Polaridade", "Periodicidade", "Tolerância de atenção", "Tolerância de ação",
              "Fonte do dado", "Responsável", "Meta"]
    larg_i = [8, 26, 30, 46, 30, 26, 10, 16, 14, 13, 13, 28, 16, 12]
    cabecalho(wi, 1, cols_i, larg_i)
    notas = {
        "ID": "Código curto e único (ex.: CX). É ele que liga o card aos lançamentos.",
        "Para que serve": "A pergunta que o indicador responde.",
        "Memória de cálculo": "A conta, de onde vem cada número e um exemplo.",
        "Numerador": "O que entra em cima da divisão.",
        "Denominador": "O que entra embaixo. Vazio se o indicador não for uma divisão.",
        "Unidade": "%, R$, dias, unidades ou número.",
        "Tolerância de atenção": "Quanto pode piorar em relação à referência antes de virar amarelo. Mesma unidade do indicador.",
        "Tolerância de ação": "A partir de quanto de piora vira vermelho. Mesma unidade do indicador.",
        "Meta": "Deixe vazia por enquanto. Definir depois de 12 meses de histórico.",
    }
    for i, n in enumerate(cols_i, start=1):
        if n in notas:
            cm = Comment(notas[n], "Planilha padrão")
            cm.width, cm.height = 260, 80
            wi.cell(1, i).comment = cm
    for row in range(2, N_IND + 2):
        for col in range(1, len(cols_i) + 1):
            c = wi.cell(row, col)
            fmt = "#,##0.##" if col in (10, 11, 14) else None
            corpo(c, True, wrap=col in (2, 3, 4, 5, 6, 12), fmt=fmt)
            if fmt:
                c.alignment = Alignment(vertical="top", horizontal="right")
    if exemplo:
        for k, d in enumerate(EX_IND):
            vals = [d["id"], d["nome"], d["serve"], d["memoria"], d["num"], d["den"], d["un"], d["pol"],
                    d["per"], d["ta"], d["tb"], d["fonte"], d["resp"], None]
            for j, v in enumerate(vals, start=1):
                wi.cell(2 + k, j, v)
            wi.row_dimensions[2 + k].height = 64
    wi.freeze_panes = "C2"
    for col, opcoes in (("G", "%,R$,dias,unidades,número"), ("H", "Maior é melhor,Menor é melhor"),
                        ("I", "Diária,Semanal,Mensal")):
        dv = DataValidation(type="list", formula1=f'"{opcoes}"', allow_blank=True)
        dv.error, dv.errorTitle = "Escolha uma opção da lista.", "Valor fora da lista"
        wi.add_data_validation(dv)
        dv.add(f"{col}2:{col}{N_IND+1}")
    dv = DataValidation(type="decimal", operator="greaterThanOrEqual", formula1="0", allow_blank=True)
    dv.error, dv.errorTitle = "Use um número maior ou igual a zero.", "Tolerância"
    wi.add_data_validation(dv)
    dv.add(f"J2:K{N_IND+1}")

    # ============================================================ Lançamentos
    wl = wb.create_sheet("Lançamentos")
    cols_l = ["Período", "ID", "Indicador", "Numerador", "Denominador", "Resultado", "Referência",
              "Variação", "Situação", "Observação"]
    larg_l = [12, 8, 30, 15, 15, 13, 13, 12, 12, 40]
    cabecalho(wl, 1, cols_l, larg_l)
    for i, n in enumerate(cols_l, start=1):
        if i in (3, 6, 7, 8, 9):
            wl.cell(1, i).fill = fill(AZUL)
    I = "'Indicadores'!"
    m = f"MATCH($B{{r}},{I}$A$2:$A${N_IND+1},0)"
    def campo(col, r):
        return f"INDEX({I}${col}$2:${col}${N_IND+1},{m.format(r=r)})"
    ex_linhas = []
    if exemplo:
        for k, mes in enumerate(MESES):
            ex_linhas.append((mes, "CX", RECEBIDO[k], VENDIDO[k], OBS.get(("CX", k))))
            ex_linhas.append((mes, "TM", VENDIDO[k], N_VENDAS[k], None))
            ex_linhas.append((mes, "SP", SALDO[k], None, None))
    rngB, rngA, rngF = f"$B$2:$B${N_LAN+1}", f"$A$2:$A${N_LAN+1}", f"$F$2:$F${N_LAN+1}"
    for r in range(2, N_LAN + 2):
        corpo(wl.cell(r, 1), True, fmt="dd/mm/yyyy")
        wl.cell(r, 1).alignment = Alignment(vertical="top", horizontal="center")
        corpo(wl.cell(r, 2), True)
        corpo(wl.cell(r, 4), True, fmt="#,##0.##")
        corpo(wl.cell(r, 5), True, fmt="#,##0.##")
        corpo(wl.cell(r, 10), True)
        wl.cell(r, 3).value = (f'=IF($B{r}="","",IFERROR({campo("B", r)},"ID não cadastrado"))')
        wl.cell(r, 6).value = (f'=IF(OR($B{r}="",$D{r}=""),"",IF($E{r}="",$D{r},IF($E{r}=0,"",'
                               f'$D{r}/$E{r}*IF(IFERROR({campo("G", r)},"")="%",100,1))))')
        cnt = f'COUNTIFS({rngB},$B{r},{rngA},"<"&$A{r})'
        corte = f'SUMPRODUCT(LARGE(({rngB}=$B{r})*({rngA}<$A{r})*{rngA},MIN(3,{cnt})))'
        wl.cell(r, 7).value = (f'=IF(OR($F{r}="",$A{r}=""),"",IF({cnt}=0,"",'
                               f'IFERROR(AVERAGEIFS({rngF},{rngB},$B{r},{rngA},"<"&$A{r},{rngA},">="&{corte}),"")))')
        wl.cell(r, 8).value = f'=IF(OR($F{r}="",$G{r}=""),"",$F{r}-$G{r})'
        piora = f'IF({campo("H", r)}="Menor é melhor",$F{r}-$G{r},$G{r}-$F{r})'
        wl.cell(r, 9).value = (f'=IF(OR($F{r}="",$G{r}=""),"",IFERROR(IF(OR({campo("H", r)}="",'
                               f'{campo("J", r)}="",{campo("K", r)}=""),"",'
                               f'IF({piora}>={campo("K", r)},"Vermelho",IF({piora}>{campo("J", r)},"Amarelo","Verde"))),""))')
        for col, fmt in ((3, None), (6, "#,##0.0"), (7, "#,##0.0"), (8, "+#,##0.0;-#,##0.0;0.0"), (9, None)):
            corpo(wl.cell(r, col), False, fmt=fmt)
        if r - 2 < len(ex_linhas):
            mes, iid, num, den, obs = ex_linhas[r - 2]
            wl.cell(r, 1, mes); wl.cell(r, 2, iid); wl.cell(r, 4, num)
            if den is not None:
                wl.cell(r, 5, den)
            if obs:
                wl.cell(r, 10, obs)
    semaforo(wl, f"I2:I{N_LAN+1}")
    dv = DataValidation(type="list", formula1=f"{I}$A$2:$A${N_IND+1}", allow_blank=True)
    dv.error, dv.errorTitle = "Use um ID cadastrado na aba Indicadores.", "ID não cadastrado"
    wl.add_data_validation(dv)
    dv.add(f"B2:B{N_LAN+1}")
    dv = DataValidation(type="date", operator="greaterThan", formula1="36526", allow_blank=True)
    dv.error, dv.errorTitle = "Digite uma data, por exemplo 01/03/2026.", "Período"
    wl.add_data_validation(dv)
    dv.add(f"A2:A{N_LAN+1}")
    wl.freeze_panes = "D2"
    wl.auto_filter.ref = f"A1:J{N_LAN+1}"

    # ============================================================ Painel
    wp = wb.create_sheet("Painel")
    wp.sheet_view.showGridLines = False
    wp.cell(1, 1, "Painel de indicadores").font = f(16, True)
    wp.cell(2, 1, "Último lançamento de cada indicador, comparado com a média dos até 3 anteriores.").font = f(10, False, AZUL)
    wp.row_dimensions[1].height = 26
    # resumo
    for k, (txt, bg, fg) in enumerate((("Verde", "D9F2E0", "1E6B3A"), ("Amarelo", "FFF2C2", "7A5A00"), ("Vermelho", "F9D5D3", "9B1C1C"))):
        c = wp.cell(4, 2 + 2 * k, txt)
        c.font = Font(name=FONTE, bold=True, color=fg); c.fill = fill(bg); c.border = borda
        c.alignment = Alignment(horizontal="center")
        v = wp.cell(4, 3 + 2 * k, f'=COUNTIF($I$7:$I${N_IND+6},"{txt}")')
        v.font = f(12, True); v.alignment = Alignment(horizontal="center"); v.border = borda
    cols_p = ["ID", "Indicador", "Unidade", "Polaridade", "Último período", "Resultado", "Referência",
              "Variação", "Situação", "Lançamentos"]
    larg_p = [8, 32, 10, 16, 14, 13, 13, 12, 12, 14]
    cabecalho(wp, 6, cols_p, larg_p)
    L = "'Lançamentos'!"
    lB, lA = f"{L}$B$2:$B${N_LAN+1}", f"{L}$A$2:$A${N_LAN+1}"
    for k in range(N_IND):
        r, ri = 7 + k, 2 + k
        wp.cell(r, 1).value = f'=IF({I}$A{ri}="","",{I}$A{ri})'
        wp.cell(r, 2).value = f'=IF($A{r}="","",{I}$B{ri})'
        wp.cell(r, 3).value = f'=IF($A{r}="","",IF({I}$G{ri}="","",{I}$G{ri}))'
        wp.cell(r, 4).value = f'=IF($A{r}="","",IF({I}$H{ri}="","",{I}$H{ri}))'
        wp.cell(r, 10).value = f'=IF($A{r}="","",COUNTIFS({lB},$A{r},{L}$D$2:$D${N_LAN+1},"<>"))'
        wp.cell(r, 5).value = (f'=IF($A{r}="","",IF(COUNTIFS({lB},$A{r},{L}$F$2:$F${N_LAN+1},">-1E+300")=0,"",'
                               f'SUMPRODUCT(MAX(({lB}=$A{r})*ISNUMBER({L}$F$2:$F${N_LAN+1})*{lA}))))')
        linha = f'SUMPRODUCT(MAX(({lB}=$A{r})*({lA}=$E{r})*ROW({lB})))'
        for col, lc in ((6, "F"), (7, "G"), (8, "H"), (9, "I")):
            wp.cell(r, col).value = f'=IF($E{r}="","",INDEX({L}${lc}:${lc},{linha}))'
        for col in range(1, 11):
            fmt = {5: "mm/yyyy", 6: "#,##0.0", 7: "#,##0.0", 8: "+#,##0.0;-#,##0.0;0.0", 10: "0"}.get(col)
            corpo(wp.cell(r, col), False, fmt=fmt)
    semaforo(wp, f"I7:I{N_IND+6}")
    wp.freeze_panes = "A7"

    for w in (wi, wl, wp):
        w.sheet_properties.tabColor = AZUL
    ws.sheet_properties.tabColor = ESCURO
    wb.active = 0
    wb.save(caminho)

if __name__ == "__main__":
    out = sys.argv[1]
    gerar(f"{out}/planilha_padrao_indicadores.xlsx", exemplo=False)
    gerar(f"{out}/planilha_padrao_indicadores_exemplo.xlsx", exemplo=True)
    print("ok")
