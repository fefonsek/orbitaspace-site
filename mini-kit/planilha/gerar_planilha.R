# Mini-kit: planilha padrão de indicadores, em duas versões.
# Uso, na pasta do site:
#   Rscript mini-kit/planilha/gerar_planilha.R
#
# Grava em mini-kit/planilha/ (os .xlsx ficam fora do Git; o link oficial é o
# do Google Drive, no campo link_planilha de mini-kit/index.qmd):
#   planilha_padrao_indicadores.xlsx          em branco
#   planilha_padrao_indicadores_exemplo.xlsx  3 indicadores gerais com meses
#                                             de exemplo (dados fictícios)
#
# Abas: Leia-me, Indicadores (uma linha por card), Lançamentos (formato longo,
# uma linha por período e indicador) e Painel (último resultado de cada
# indicador, com a cor da situação).
#
# Fórmulas: só funções comuns (SE, ÍNDICE/CORRESP, SOMASES, MÉDIASES,
# CONT.SES, MÁXIMOSES), sem fórmulas de matriz, para funcionar igual no Excel
# (2019 ou mais recente, ou Microsoft 365, por causa do MÁXIMOSES) e no Google
# Planilhas. As fórmulas não guardam resultado: quem abre calcula.
# mini-kit/planilha/conferir_planilha.py confere as contas com o pycel.
#
# Regras das contas:
# - Resultado: Numerador ÷ Denominador; com a Unidade "%", vezes 100 (92 =
#   92%). Com o Denominador vazio, o Resultado é o próprio Numerador
#   (indicador que não é divisão, como o saldo projetado).
# - Referência: média dos até 3 lançamentos anteriores do mesmo ID, pela data
#   do Período (a 1ª, a 2ª e a 3ª data anteriores vêm de MÁXIMOSES aninhados).
# - Variação: Resultado − Referência, na unidade do indicador.
# - Situação: a piora é Referência − Resultado ("Maior é melhor") ou
#   Resultado − Referência ("Menor é melhor"). Vermelho quando a piora chega à
#   Tolerância de ação; Amarelo quando passa da Tolerância de atenção; Verde no
#   resto. Vazia sem referência ou sem as duas tolerâncias.

suppressPackageStartupMessages(library(openxlsx))
args <- commandArgs(trailingOnly = FALSE)
pasta <- normalizePath(dirname(sub("^--file=", "", args[grep("^--file=", args)])))
site <- normalizePath(file.path(pasta, "..", ".."))
# salvar_xlsx() e xlsx_valido(): corrigem as relações que o openxlsx grava
# para arquivos ausentes (o mesmo problema da planilha da padaria).
source(file.path(site, "projetos", "mentoria-padaria", "scripts", "xlsx.R"))

ABA_LEIA <- "Leia-me"; ABA_IND <- "Indicadores"; ABA_LAN <- "Lançamentos"; ABA_PAINEL <- "Painel"
ULT_IND <- 51     # cards: linhas 2 a 51 (até 50 indicadores)
ULT_LAN <- 2001   # lançamentos: fórmulas e validação prontas até esta linha
LIN_PAINEL <- 2:ULT_IND

COLS_IND <- c("ID", "Indicador", "Para que serve", "Memória de cálculo", "Numerador", "Denominador",
              "Unidade", "Polaridade", "Periodicidade", "Tolerância de atenção", "Tolerância de ação",
              "Fonte do dado", "Responsável", "Meta")
COLS_LAN <- c("Período", "ID", "Indicador", "Numerador", "Denominador", "Resultado", "Referência",
              "Variação", "Situação", "Observação")
COLS_PAINEL <- c("ID", "Indicador", "Unidade", "Polaridade", "Último período", "Resultado", "Referência",
                 "Variação", "Situação")
POLARIDADES <- c("Maior é melhor", "Menor é melhor")
PERIODICIDADES <- c("Diária", "Semanal", "Mensal")

LEIA_ME <- c(
  "Planilha padrão de indicadores",
  "",
  "Funciona no Google Planilhas e no Excel 2019 ou mais recente (inclusive Microsoft 365).",
  "",
  "1. Indicadores: uma linha por card. Polaridade e Periodicidade vêm de uma lista. A Meta fica vazia até você ter 12 meses de histórico.",
  "2. Lançamentos: uma linha por período e indicador. Você digita só Período, ID, Numerador e Denominador (e uma Observação, se quiser). O resto calcula sozinho.",
  "3. Período é uma data: o dia (diária), a segunda-feira da semana (semanal) ou o dia 1 do mês (mensal).",
  "4. Indicador que não é divisão: deixe o Denominador vazio, e o Resultado é o próprio Numerador. Exemplo: saldo projetado = caixa + a receber − a pagar, já somados no Numerador.",
  "5. Unidade \"%\": o Resultado sai em pontos (92 quer dizer 92%), e as tolerâncias também são em pontos.",
  "6. Referência: a média dos até 3 lançamentos anteriores do mesmo indicador. Variação: Resultado menos Referência.",
  "7. Situação: compara o Resultado com a Referência, respeitando a polaridade. Amarelo quando piora mais que a Tolerância de atenção; Vermelho quando a piora chega à Tolerância de ação; Verde no resto.",
  "8. Painel: o último resultado de cada indicador, com a cor da situação.",
  "9. Cabeçalho azul-escuro: coluna que você digita. Cabeçalho azul: coluna que calcula sozinha (não digite nela).",
  "10. Não crie, não renomeie, não apague e não mude a ordem das abas e das colunas: as fórmulas dependem delas."
)

# Exemplo: 3 indicadores gerais, de março a outubro de 2026 (dados fictícios).
EXEMPLO_IND <- data.frame(
  ID = c("IND01", "IND02", "IND03"),
  Indicador = c("Quanto do faturado virou caixa", "Ticket médio", "Saldo projetado para 30 dias"),
  serve = c("Estou vendendo ou estou recebendo?", "Cada cliente está comprando mais ou menos?",
            "Vou fechar o próximo mês no azul?"),
  memoria = c("Total recebido no mês ÷ total vendido no mês, em %. Exemplo: recebi R$74 mil e vendi R$80 mil: 92,5%.",
              "Total vendido no mês ÷ número de vendas no mês. Exemplo: R$80 mil em 640 vendas: R$125.",
              "Caixa hoje + a receber em 30 dias − a pagar em 30 dias, já somados no Numerador. Exemplo: R$18 mil + R$40 mil − R$45 mil = R$13 mil."),
  num = c("Total recebido no mês", "Total vendido no mês", "Caixa + a receber − a pagar em 30 dias"),
  den = c("Total vendido no mês", "Número de vendas no mês", ""),
  unidade = c("%", "R$", "R$"),
  polaridade = c("Maior é melhor", "Maior é melhor", "Maior é melhor"),
  periodicidade = c("Mensal", "Mensal", "Mensal"),
  tol_atencao = c(3, 5, 3000),
  tol_acao = c(8, 12, 8000),
  fonte = c("Extrato do banco e relatório de vendas", "Sistema de vendas ou caderno",
            "Extrato do banco, contas a receber e contas a pagar"),
  responsavel = c("Dono", "Gerente", "Dono"),
  meta = NA,
  stringsAsFactors = FALSE
)

exemplo_lancamentos <- function() {
  meses <- seq(as.Date("2026-03-01"), as.Date("2026-10-01"), by = "month")
  vendido <- c(78000, 82000, 80000, 85000, 79000, 83000, 86000, 84000)
  recebido_pct <- c(93, 92, 94, 91, 92, 93, 91, 82)
  ticket <- c(124, 126, 123, 127, 125, 128, 126, 119)
  saldo <- c(12000, 15000, 9000, 14000, 16000, 13000, 15000, 14500)
  obs <- rep("", length(meses)); obs[8] <- "Duas construtoras atrasaram o pagamento."
  linhas <- list()
  for (i in seq_along(meses)) {
    linhas[[length(linhas) + 1]] <- data.frame(p = meses[i], id = "IND01", num = vendido[i] * recebido_pct[i] / 100,
                                               den = vendido[i], obs = obs[i])
    linhas[[length(linhas) + 1]] <- data.frame(p = meses[i], id = "IND02", num = vendido[i],
                                               den = round(vendido[i] / ticket[i]), obs = "")
    linhas[[length(linhas) + 1]] <- data.frame(p = meses[i], id = "IND03", num = saldo[i], den = NA, obs = "")
  }
  do.call(rbind, linhas)
}

# O openxlsx grava a fonte do texto do comentário como <name val=...>; no
# padrão do Excel, dentro do comentário, ela é <rFont val=...>. Sem a troca,
# o openpyxl (e o pycel) recusam o arquivo.
corrigir_comentarios <- function(arquivo) {
  pasta_zip <- tempfile("xlsx_")
  dir.create(pasta_zip)
  on.exit(unlink(pasta_zip, recursive = TRUE), add = TRUE)
  utils::unzip(arquivo, exdir = pasta_zip)
  for (f in list.files(file.path(pasta_zip, "xl"), pattern = "^comments.*\\.xml$", full.names = TRUE)) {
    xml <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "")
    writeLines(enc2utf8(gsub("<name val=", "<rFont val=", xml, fixed = TRUE)), f, useBytes = TRUE)
  }
  arquivos <- list.files(pasta_zip, recursive = TRUE, all.files = TRUE)
  unlink(arquivo)
  zip::zip(arquivo, files = arquivos, root = pasta_zip, mode = "mirror")
}

montar <- function(exemplo) {
  wb <- createWorkbook(creator = "Orbita Space")
  modifyBaseFont(wb, fontSize = 11, fontName = "Arial")
  # Cabeçalhos: #1a1a2e nas colunas que a pessoa digita; #3473C0 nas que
  # calculam sozinhas (Lançamentos: Indicador, Resultado, Referência, Variação
  # e Situação; o Painel inteiro).
  cab <- createStyle(textDecoration = "bold", fgFill = "#1a1a2e", fontColour = "#ffffff",
                     halign = "left", valign = "center", wrapText = TRUE)
  cab_calc <- createStyle(textDecoration = "bold", fgFill = "#3473C0", fontColour = "#ffffff",
                          halign = "left", valign = "center", wrapText = TRUE)
  calc <- createStyle(fgFill = "#eef0f8")     # colunas que calculam sozinhas
  texto <- createStyle(wrapText = TRUE, valign = "top")
  numero <- createStyle(numFmt = "#,##0.00")
  variacao <- createStyle(numFmt = "+#,##0.00;-#,##0.00;0.00")
  data_fmt <- createStyle(numFmt = "dd/mm/yyyy")
  verde <- createStyle(bgFill = "#d9ead3", fontColour = "#1e4620")
  amarelo <- createStyle(bgFill = "#fff2cc", fontColour = "#5c4400")
  vermelho <- createStyle(bgFill = "#f4cccc", fontColour = "#6b1414")

  ## Leia-me
  addWorksheet(wb, ABA_LEIA, gridLines = FALSE)
  writeData(wb, ABA_LEIA, LEIA_ME, colNames = FALSE)
  addStyle(wb, ABA_LEIA, createStyle(textDecoration = "bold", fontSize = 14, fontColour = "#1a1a2e"), rows = 1, cols = 1)
  addStyle(wb, ABA_LEIA, createStyle(wrapText = TRUE, valign = "top"), rows = 2:length(LEIA_ME), cols = 1)
  setColWidths(wb, ABA_LEIA, cols = 1, widths = 110)

  ## Indicadores
  addWorksheet(wb, ABA_IND)
  writeData(wb, ABA_IND, t(COLS_IND), colNames = FALSE)
  addStyle(wb, ABA_IND, cab, rows = 1, cols = seq_along(COLS_IND), gridExpand = TRUE)
  if (exemplo) {
    writeData(wb, ABA_IND, EXEMPLO_IND, startRow = 2, colNames = FALSE, keepNA = FALSE)
  }
  addStyle(wb, ABA_IND, texto, rows = 2:ULT_IND, cols = seq_along(COLS_IND), gridExpand = TRUE)
  dataValidation(wb, ABA_IND, cols = 8, rows = 2:ULT_IND, type = "list",
                 value = sprintf('"%s"', paste(POLARIDADES, collapse = ",")))
  dataValidation(wb, ABA_IND, cols = 9, rows = 2:ULT_IND, type = "list",
                 value = sprintf('"%s"', paste(PERIODICIDADES, collapse = ",")))
  writeComment(wb, ABA_IND, col = 14, row = 1,
               comment = createComment("Definir depois de 12 meses de histórico.", author = "Orbita Space",
                                       visible = FALSE))
  setColWidths(wb, ABA_IND, cols = seq_along(COLS_IND),
               widths = c(8, 26, 30, 44, 24, 22, 9, 16, 14, 12, 12, 28, 16, 12))
  setRowHeights(wb, ABA_IND, rows = 1, heights = 32)
  freezePane(wb, ABA_IND, firstActiveRow = 2, firstActiveCol = 3)

  ## Lançamentos
  addWorksheet(wb, ABA_LAN)
  writeData(wb, ABA_LAN, t(COLS_LAN), colNames = FALSE)
  addStyle(wb, ABA_LAN, cab, rows = 1, cols = seq_along(COLS_LAN), gridExpand = TRUE)
  addStyle(wb, ABA_LAN, cab_calc, rows = 1, cols = c(3, 6:9), gridExpand = TRUE)
  if (exemplo) {
    d <- exemplo_lancamentos()
    writeData(wb, ABA_LAN, d$p, startCol = 1, startRow = 2)
    writeData(wb, ABA_LAN, d$id, startCol = 2, startRow = 2)
    writeData(wb, ABA_LAN, d[, c("num", "den")], startCol = 4, startRow = 2, colNames = FALSE, keepNA = FALSE)
    writeData(wb, ABA_LAN, d$obs, startCol = 10, startRow = 2)
  }
  r <- 2:ULT_LAN
  faixa <- function(col) sprintf("$%s$2:$%s$%d", col, col, ULT_LAN)
  ind <- function(col) sprintf("INDEX(%s!$%s$2:$%s$%d,MATCH($B%d,%s!$A$2:$A$%d,0))",
                               ABA_IND, col, col, ULT_IND, r, ABA_IND, ULT_IND)
  # k-ésima data anterior do mesmo ID, com Numerador preenchido.
  # O critério do ID vai como $B2&"": no Excel e no Google dá no mesmo, e o
  # pycel (conferência) não aceita critério vindo de célula vazia.
  anterior <- function(limite) sprintf('_xlfn.MAXIFS(%s,%s,$B%d&"",%s,"<>",%s,"<"&%s)',
                                       faixa("A"), faixa("B"), r, faixa("D"), faixa("A"), limite)
  p1 <- anterior(sprintf("$A%d", r)); p2 <- anterior(p1); p3 <- anterior(p2)
  f_ind <- sprintf('IF($B%1$d="","",IFERROR(%2$s,"ID não cadastrado"))', r, ind("B"))
  f_res <- sprintf('IF(OR($B%1$d="",$D%1$d=""),"",IF($E%1$d="",$D%1$d,IFERROR($D%1$d/$E%1$d*IF(IFERROR(%2$s,"")="%%",100,1),"")))',
                   r, ind("G"))
  f_ref <- sprintf('IF(OR($F%1$d="",$A%1$d=""),"",IFERROR(AVERAGEIFS(%2$s,%3$s,$B%1$d&"",%4$s,"<>",%5$s,"<"&$A%1$d,%5$s,">="&%6$s),""))',
                   r, faixa("F"), faixa("B"), faixa("D"), faixa("A"), p3)
  f_var <- sprintf('IF(OR($F%1$d="",$G%1$d=""),"",$F%1$d-$G%1$d)', r)
  piora <- sprintf('ROUND(IF(%2$s="Menor é melhor",$F%1$d-$G%1$d,$G%1$d-$F%1$d),9)', r, ind("H"))
  f_sit <- sprintf('IF(OR($F%1$d="",$G%1$d=""),"",IFERROR(IF(OR(%2$s="",%3$s=""),"",IF(%4$s>=%3$s,"Vermelho",IF(%4$s>%2$s,"Amarelo","Verde"))),""))',
                   r, ind("J"), ind("K"), piora)
  writeFormula(wb, ABA_LAN, f_ind, startCol = 3, startRow = 2)
  writeFormula(wb, ABA_LAN, f_res, startCol = 6, startRow = 2)
  writeFormula(wb, ABA_LAN, f_ref, startCol = 7, startRow = 2)
  writeFormula(wb, ABA_LAN, f_var, startCol = 8, startRow = 2)
  writeFormula(wb, ABA_LAN, f_sit, startCol = 9, startRow = 2)
  addStyle(wb, ABA_LAN, data_fmt, rows = r, cols = 1, gridExpand = TRUE)
  addStyle(wb, ABA_LAN, numero, rows = r, cols = 4:5, gridExpand = TRUE)
  addStyle(wb, ABA_LAN, createStyle(numFmt = "#,##0.00", fgFill = "#eef0f8"), rows = r, cols = 6:7, gridExpand = TRUE)
  addStyle(wb, ABA_LAN, createStyle(numFmt = "+#,##0.00;-#,##0.00;0.00", fgFill = "#eef0f8"), rows = r, cols = 8,
           gridExpand = TRUE)
  addStyle(wb, ABA_LAN, calc, rows = r, cols = c(3, 9), gridExpand = TRUE)
  dataValidation(wb, ABA_LAN, cols = 2, rows = r, type = "list",
                 value = sprintf("%s!$A$2:$A$%d", ABA_IND, ULT_IND))
  for (s in list(list("Verde", verde), list("Amarelo", amarelo), list("Vermelho", vermelho))) {
    conditionalFormatting(wb, ABA_LAN, cols = 9, rows = r, type = "expression",
                          rule = sprintf('$I2="%s"', s[[1]]), style = s[[2]])
  }
  setColWidths(wb, ABA_LAN, cols = seq_along(COLS_LAN), widths = c(12, 8, 30, 14, 14, 13, 13, 12, 11, 40))
  setRowHeights(wb, ABA_LAN, rows = 1, heights = 20)
  freezePane(wb, ABA_LAN, firstRow = TRUE)

  ## Painel
  addWorksheet(wb, ABA_PAINEL)
  writeData(wb, ABA_PAINEL, t(COLS_PAINEL), colNames = FALSE)
  addStyle(wb, ABA_PAINEL, cab_calc, rows = 1, cols = seq_along(COLS_PAINEL), gridExpand = TRUE)
  p <- LIN_PAINEL
  lan <- function(col) sprintf("'%s'!$%s$2:$%s$%d", ABA_LAN, col, col, ULT_LAN)
  icel <- function(col) sprintf("%s!$%s%d", ABA_IND, col, p)
  ant_p <- function(limite) sprintf('_xlfn.MAXIFS(%s,%s,$A%d,%s,"<>",%s,"<"&%s)',
                                    lan("A"), lan("B"), p, lan("D"), lan("A"), limite)
  q3 <- ant_p(ant_p(ant_p(sprintf("$E%d", p))))
  writeFormula(wb, ABA_PAINEL, sprintf('IF(%1$s="","",%1$s)', icel("A")), startCol = 1, startRow = 2)
  writeFormula(wb, ABA_PAINEL, sprintf('IF($A%1$d="","",%2$s&"")', p, icel("B")), startCol = 2, startRow = 2)
  writeFormula(wb, ABA_PAINEL, sprintf('IF($A%1$d="","",%2$s&"")', p, icel("G")), startCol = 3, startRow = 2)
  writeFormula(wb, ABA_PAINEL, sprintf('IF($A%1$d="","",%2$s&"")', p, icel("H")), startCol = 4, startRow = 2)
  writeFormula(wb, ABA_PAINEL,
               sprintf('IF($A%1$d="","",IF(COUNTIFS(%2$s,$A%1$d,%3$s,"<>")=0,"",_xlfn.MAXIFS(%4$s,%2$s,$A%1$d,%3$s,"<>")))',
                       p, lan("B"), lan("D"), lan("A")), startCol = 5, startRow = 2)
  writeFormula(wb, ABA_PAINEL, sprintf('IF($E%1$d="","",SUMIFS(%2$s,%3$s,$A%1$d,%4$s,$E%1$d))',
                                       p, lan("F"), lan("B"), lan("A")), startCol = 6, startRow = 2)
  writeFormula(wb, ABA_PAINEL,
               sprintf('IF($E%1$d="","",IFERROR(AVERAGEIFS(%2$s,%3$s,$A%1$d,%4$s,"<>",%5$s,"<"&$E%1$d,%5$s,">="&%6$s),""))',
                       p, lan("F"), lan("B"), lan("D"), lan("A"), q3), startCol = 7, startRow = 2)
  writeFormula(wb, ABA_PAINEL, sprintf('IF(OR($F%1$d="",$G%1$d=""),"",$F%1$d-$G%1$d)', p), startCol = 8, startRow = 2)
  piora_p <- sprintf('ROUND(IF($D%1$d="Menor é melhor",$F%1$d-$G%1$d,$G%1$d-$F%1$d),9)', p)
  writeFormula(wb, ABA_PAINEL,
               sprintf('IF(OR($F%1$d="",$G%1$d="",%2$s="",%3$s=""),"",IF(%4$s>=%3$s,"Vermelho",IF(%4$s>%2$s,"Amarelo","Verde")))',
                       p, icel("J"), icel("K"), piora_p), startCol = 9, startRow = 2)
  addStyle(wb, ABA_PAINEL, data_fmt, rows = p, cols = 5, gridExpand = TRUE)
  addStyle(wb, ABA_PAINEL, numero, rows = p, cols = 6:7, gridExpand = TRUE)
  addStyle(wb, ABA_PAINEL, variacao, rows = p, cols = 8, gridExpand = TRUE)
  addStyle(wb, ABA_PAINEL, createStyle(textDecoration = "bold"), rows = p, cols = 9, gridExpand = TRUE)
  for (s in list(list("Verde", verde), list("Amarelo", amarelo), list("Vermelho", vermelho))) {
    conditionalFormatting(wb, ABA_PAINEL, cols = 1:9, rows = p, type = "expression",
                          rule = sprintf('$I2="%s"', s[[1]]), style = s[[2]])
  }
  setColWidths(wb, ABA_PAINEL, cols = seq_along(COLS_PAINEL), widths = c(8, 30, 9, 16, 14, 13, 13, 12, 11))
  setRowHeights(wb, ABA_PAINEL, rows = 1, heights = 20)
  freezePane(wb, ABA_PAINEL, firstRow = TRUE)

  activeSheet(wb) <- 1
  nome <- if (exemplo) "planilha_padrao_indicadores_exemplo.xlsx" else "planilha_padrao_indicadores.xlsx"
  arquivo <- file.path(pasta, nome)
  salvar_xlsx(wb, arquivo)
  corrigir_comentarios(arquivo)
  stopifnot(xlsx_valido(arquivo))
  arquivo
}

feitos <- vapply(c(FALSE, TRUE), montar, "")
cat("Planilhas:", paste(basename(feitos), collapse = ", "), "\n")
