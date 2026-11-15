# Caso Mentoria (Padaria Grão Dourado): planilha modelo para baixar (PT, ES, EN).
# Uso, na pasta do site: Rscript projetos/mentoria-padaria/scripts/planilha_modelo.R
#
# Grava em resultados/ uma planilha por língua, com quatro abas:
# - Lançamentos: as 12 semanas da padaria, uma linha por dia, produto e
#   fornada. Sobra, receita, custo total e margem são fórmulas de uma linha.
# - Indicadores: os três números, só com SUMIFS e divisões, sem fórmulas de
#   matriz, para funcionar igual no Excel e no Google Planilhas. O bloco 3 é a
#   participação de cada produto na margem total (a margem não desconta
#   aluguel, salários e energia).
# - Listas: produtos e fornadas, usados na validação das colunas.
# - Como usar.
# As fórmulas não guardam resultado: quem abre (Excel, Google Planilhas ou o
# LibreOffice, na conferência) calcula. scripts/conferir_planilha.R compara o
# resultado com resultados/padaria.rds.

suppressPackageStartupMessages({ library(dplyr); library(openxlsx) })
args <- commandArgs(trailingOnly = FALSE)
caso <- normalizePath(file.path(dirname(sub("^--file=", "", args[grep("^--file=", args)])), ".."))
source(file.path(caso, "scripts", "rotulos.R"))
source(file.path(caso, "scripts", "xlsx.R"))

d <- read.csv(file.path(caso, "dados", "padaria_organizada.csv"), encoding = "UTF-8") |> mutate(data = as.Date(data))
ULTIMA <- 3000  # fórmulas e validação já prontas até esta linha

montar <- function(idioma) {
  tx <- rotulos(idioma)
  pl <- tx$planilha
  aba_l <- pl$abas[1]; aba_i <- pl$abas[2]; aba_li <- pl$abas[3]; aba_c <- pl$abas[4]
  ref <- function(col) sprintf("'%s'!$%s$2:$%s$%d", aba_l, col, col, ULTIMA)

  wb <- createWorkbook()
  cab <- createStyle(textDecoration = "bold", fgFill = "#1a1a2e", fontColour = "#ffffff", halign = "center")
  titulo <- createStyle(textDecoration = "bold", fontColour = "#1a1a2e", fontSize = 12)
  dinheiro <- createStyle(numFmt = "\"R$\" #,##0.00")
  porcento <- createStyle(numFmt = "0.0%")
  inteiro <- createStyle(numFmt = "#,##0")
  data_fmt <- createStyle(numFmt = "dd/mm/yyyy")

  ## Lançamentos
  addWorksheet(wb, aba_l)
  base <- d |> transmute(data, dia_semana = tx$dias[as.integer(format(data, "%u"))],
                         fornada = unname(tx$fornadas[fornada]),
                         produto = unname(tx$produtos[produto]), produzido, vendido, preco_unitario, custo_unitario)
  names(base) <- pl$colunas[1:8]
  writeData(wb, aba_l, base, headerStyle = cab)
  writeData(wb, aba_l, t(pl$colunas[9:12]), startCol = 9, startRow = 1, colNames = FALSE)
  addStyle(wb, aba_l, cab, rows = 1, cols = 9:12, gridExpand = TRUE)
  linhas <- 2:ULTIMA
  writeFormula(wb, aba_l, sprintf('IF(E%d="","",E%d-F%d)', linhas, linhas, linhas), startCol = 9, startRow = 2)
  writeFormula(wb, aba_l, sprintf('IF(E%d="","",F%d*G%d)', linhas, linhas, linhas), startCol = 10, startRow = 2)
  writeFormula(wb, aba_l, sprintf('IF(E%d="","",E%d*H%d)', linhas, linhas, linhas), startCol = 11, startRow = 2)
  writeFormula(wb, aba_l, sprintf('IF(E%d="","",J%d-K%d)', linhas, linhas, linhas), startCol = 12, startRow = 2)
  addStyle(wb, aba_l, data_fmt, rows = linhas, cols = 1, gridExpand = TRUE)
  addStyle(wb, aba_l, dinheiro, rows = linhas, cols = c(7, 8, 10, 11, 12), gridExpand = TRUE)
  setColWidths(wb, aba_l, cols = 1:12, widths = c(12, 12, 10, 18, 11, 10, 14, 14, 10, 12, 12, 12))
  freezePane(wb, aba_l, firstRow = TRUE)

  ## Listas e validação
  addWorksheet(wb, aba_li)
  writeData(wb, aba_li, data.frame(x = unname(tx$produtos[PRODUTOS])) |> setNames(pl$colunas[4]), headerStyle = cab)
  writeData(wb, aba_li, data.frame(x = unname(tx$fornadas[FORNADAS])) |> setNames(pl$colunas[3]), startCol = 2,
            headerStyle = cab)
  setColWidths(wb, aba_li, cols = 1:2, widths = c(20, 12))
  dataValidation(wb, aba_l, cols = 4, rows = linhas, type = "list",
                 value = sprintf("'%s'!$A$2:$A$%d", aba_li, length(PRODUTOS) + 1))
  dataValidation(wb, aba_l, cols = 3, rows = linhas, type = "list",
                 value = sprintf("'%s'!$B$2:$B$%d", aba_li, length(FORNADAS) + 1))

  ## Indicadores
  addWorksheet(wb, aba_i)
  ind <- pl$ind
  nomes <- unname(tx$produtos[PRODUTOS])
  n <- length(nomes)
  # Bloco 1: taxa de sobra, produto nas linhas e fornada nas colunas.
  writeData(wb, aba_i, ind$t1, startRow = 1); addStyle(wb, aba_i, titulo, rows = 1, cols = 1)
  writeData(wb, aba_i, t(c(ind$produto, unname(tx$fornadas[FORNADAS]))), startRow = 3, colNames = FALSE)
  addStyle(wb, aba_i, cab, rows = 3, cols = 1:(1 + length(FORNADAS)), gridExpand = TRUE)
  writeData(wb, aba_i, nomes, startRow = 4)
  for (j in seq_along(FORNADAS)) {
    col <- int2col(j + 1)
    f <- sprintf('IF(SUMIFS(%1$s,%2$s,$A%4$d,%3$s,%5$s$3)=0,"",SUMIFS(%6$s,%2$s,$A%4$d,%3$s,%5$s$3)/SUMIFS(%1$s,%2$s,$A%4$d,%3$s,%5$s$3))',
                 ref("E"), ref("D"), ref("C"), 4:(3 + n), col, ref("I"))
    writeFormula(wb, aba_i, f, startCol = j + 1, startRow = 4)
  }
  addStyle(wb, aba_i, porcento, rows = 4:(3 + n), cols = 2:(1 + length(FORNADAS)), gridExpand = TRUE)

  # Bloco 2: margem real por produto. Bloco 3: participação no lucro (coluna H).
  l2 <- 5 + n
  writeData(wb, aba_i, ind$t2, startRow = l2); addStyle(wb, aba_i, titulo, rows = l2, cols = 1)
  writeData(wb, aba_i, paste(ind$t3, "→", ind$participacao), startRow = l2 + 1)
  cabec2 <- c(ind$produto, ind$produzido, ind$vendido, ind$sobra, ind$receita, ind$custo, ind$margem, ind$participacao)
  writeData(wb, aba_i, t(cabec2), startRow = l2 + 2, colNames = FALSE)
  addStyle(wb, aba_i, cab, rows = l2 + 2, cols = 1:8, gridExpand = TRUE)
  primeira <- l2 + 3; ult <- primeira + n - 1; tot <- ult + 1
  writeData(wb, aba_i, nomes, startRow = primeira)
  colunas <- c(B = "E", C = "F", D = "I", E = "J", F = "K", G = "L")
  for (k in names(colunas)) {
    writeFormula(wb, aba_i, sprintf("SUMIFS(%s,%s,$A%d)", ref(colunas[[k]]), ref("D"), primeira:ult),
                 startCol = col2int(k), startRow = primeira)
    writeFormula(wb, aba_i, sprintf("SUM(%s%d:%s%d)", k, primeira, k, ult), startCol = col2int(k), startRow = tot)
  }
  writeFormula(wb, aba_i, sprintf("G%d/$G$%d", primeira:ult, tot), startCol = 8, startRow = primeira)
  writeFormula(wb, aba_i, sprintf("SUM(H%d:H%d)", primeira, ult), startCol = 8, startRow = tot)
  writeData(wb, aba_i, ind$total, startRow = tot)
  addStyle(wb, aba_i, createStyle(textDecoration = "bold"), rows = tot, cols = 1:8, gridExpand = TRUE, stack = TRUE)
  addStyle(wb, aba_i, inteiro, rows = primeira:tot, cols = 2:4, gridExpand = TRUE, stack = TRUE)
  addStyle(wb, aba_i, dinheiro, rows = primeira:tot, cols = 5:7, gridExpand = TRUE, stack = TRUE)
  addStyle(wb, aba_i, porcento, rows = primeira:tot, cols = 8, gridExpand = TRUE, stack = TRUE)
  setColWidths(wb, aba_i, cols = 1:8, widths = c(20, 12, 12, 12, 16, 16, 16, 14))

  ## Como usar
  addWorksheet(wb, aba_c)
  writeData(wb, aba_c, pl$como)
  addStyle(wb, aba_c, titulo, rows = 1, cols = 1)
  setColWidths(wb, aba_c, cols = 1, widths = 120)

  worksheetOrder(wb) <- c(4, 1, 3, 2)  # Como usar, Lançamentos, Indicadores, Listas
  activeSheet(wb) <- 1
  arquivo <- file.path(caso, "resultados", pl$arquivo)
  salvar_xlsx(wb, arquivo)
  stopifnot(xlsx_valido(arquivo))
  # Posições das células, para a conferência.
  list(arquivo = arquivo, aba_i = aba_i, n = n, primeira = primeira, tot = tot, nomes = nomes)
}

posicoes <- lapply(setNames(c("pt", "es", "en"), c("pt", "es", "en")), montar)
saveRDS(posicoes, file.path(caso, "resultados", "planilha_posicoes.rds"))
cat("Planilhas modelo:", paste(basename(vapply(posicoes, `[[`, "", "arquivo")), collapse = ", "), "\n")
