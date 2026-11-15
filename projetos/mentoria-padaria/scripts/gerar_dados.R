# Caso Mentoria (Padaria Grão Dourado): gera os dados fictícios.
# Uso, na pasta do site: Rscript projetos/mentoria-padaria/scripts/gerar_dados.R
#
# Grava:
# - dados/gabarito.csv: a base limpa, uma linha por dia, produto e fornada,
#   de 2 de março a 24 de maio de 2026 (12 semanas). É o resultado que a
#   organização da planilha (scripts/organizar.R) precisa reproduzir.
# - dados/planilha_baguncada.xlsx: a mesma informação como a padaria anota,
#   uma aba por mês, com os problemas que o encontro ensina a resolver: datas
#   em formatos misturados, produtos e fornadas escritos de jeitos diferentes,
#   a data mesclada sobre as linhas do dia, total da semana no meio da tabela,
#   preço e custo como texto com "R$" e, em abril, colunas em outra ordem.
#
# Os padrões plantados (e que a página encontra): a fornada das 17h de pão
# francês sobra muito; o sonho quase não dá lucro depois de descontar a sobra;
# o pão de queijo vende tudo em todas as fornadas.

suppressPackageStartupMessages({ library(dplyr); library(openxlsx) })
args <- commandArgs(trailingOnly = FALSE)
caso <- normalizePath(file.path(dirname(sub("^--file=", "", args[grep("^--file=", args)])), ".."))
source(file.path(caso, "scripts", "rotulos.R"))
source(file.path(caso, "scripts", "xlsx.R"))
set.seed(20260302)

# produto, fornada, quanto se produz, que parte costuma vender, preço e custo por unidade.
plano <- tribble(
  ~produto,  ~fornada, ~produzido, ~venda, ~preco, ~custo,
  "frances", "6h",     520,        0.95,   0.90,   0.34,
  "frances", "10h",    260,        0.90,   0.90,   0.34,
  "frances", "14h",    240,        0.86,   0.90,   0.34,
  "frances", "17h",    300,        0.60,   0.90,   0.34,
  "queijo",  "6h",     120,        1.25,   2.50,   0.95,
  "queijo",  "10h",    140,        1.25,   2.50,   0.95,
  "queijo",  "14h",    160,        1.20,   2.50,   0.95,
  "fuba",    "6h",      10,        0.86,  22.00,   9.00,
  "fuba",    "14h",      8,        0.82,  22.00,   9.00,
  "sonho",   "10h",     60,        0.52,   4.50,   2.10,
  "sonho",   "14h",     60,        0.48,   4.50,   2.10,
  "forma",   "6h",      30,        0.90,  12.00,   5.00,
  "salgado", "10h",     80,        0.90,   6.00,   2.40,
  "salgado", "14h",     80,        0.88,   6.00,   2.40,
  "salgado", "17h",     60,        0.80,   6.00,   2.40
)

datas <- seq(as.Date("2026-03-02"), as.Date("2026-05-24"), by = "day")
stopifnot(length(datas) == 84, format(datas[1], "%u") == "1")
# Fim de semana: manhã mais cheia; domingo à tarde mais vazio.
efeito <- function(dia, fornada) {
  fds <- dia %in% c(6, 7)
  ifelse(fds & fornada %in% c("6h", "10h"), 1.12, ifelse(dia == 7 & fornada %in% c("14h", "17h"), 0.82, 1))
}

base <- tidyr::expand_grid(data = datas, plano) |>
  mutate(dia = as.integer(format(data, "%u")),
         produzido = round(produzido * runif(n(), 0.97, 1.03)),
         procura = round(produzido * venda * efeito(dia, fornada) * exp(rnorm(n(), 0, 0.08))),
         vendido = pmin(produzido, procura)) |>
  transmute(data, dia_semana = rotulos("pt")$dias[dia], fornada, produto, produzido, vendido,
            preco_unitario = preco, custo_unitario = custo) |>
  arrange(data, match(fornada, FORNADAS), match(produto, PRODUTOS))

dir.create(file.path(caso, "dados"), showWarnings = FALSE)
write.csv(base, file.path(caso, "dados", "gabarito.csv"), row.names = FALSE, fileEncoding = "UTF-8")

## ---- planilha bagunçada ----
# Como cada produto aparece escrito na planilha da padaria.
variantes <- list(
  frances = c("Pão francês", "pão francês", "Pao Frances", "francês", "PÃO FRANCÊS"),
  queijo = c("Pão de queijo", "pão de queijo", "Pao de Queijo", "p. queijo"),
  fuba = c("Bolo de fubá", "bolo fubá", "Bolo de Fuba"),
  sonho = c("Sonho", "sonho", "SONHO", "Sonho (creme)"),
  forma = c("Pão de forma", "pão de forma caseiro", "Pao de Forma"),
  salgado = c("Salgado assado", "salgado", "Salgado Assado", "salg. assado")
)
fornadas_txt <- list(`6h` = c("6h", "06:00", "6 h"), `10h` = c("10h", "10:00", "10 h"),
                     `14h` = c("14h", "14:00", "14 h"), `17h` = c("17h", "17:00", "17 h"))
meses_pt <- c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez")
data_txt <- function(d) {
  switch(sample(4, 1),
         format(d, "%d/%m"),
         format(d, "%Y-%m-%d"),
         paste(as.integer(format(d, "%d")), meses_pt[as.integer(format(d, "%m"))]),
         d)  # data de verdade do Excel
}
dinheiro <- function(x) if (runif(1) < 0.4) paste0("R$ ", formatC(x, format = "f", digits = 2, decimal.mark = ",")) else x

wb <- createWorkbook()
negrito <- createStyle(textDecoration = "bold")
for (m in 3:5) {
  aba <- c("Março", "Abril", "Maio")[m - 2]
  addWorksheet(wb, aba)
  abril <- m == 4
  cabecalho <- if (abril) c("Data", "Produto", "Fornada", "Vendido", "Produzido", "Preço", "Custo")
               else c("Data", "Fornada", "Produto", "Produzido", "Vendido", "Preço", "Custo")
  writeData(wb, aba, paste("VENDAS PADARIA GRÃO DOURADO ·", toupper(aba), "2026"), startRow = 1)
  addStyle(wb, aba, negrito, rows = 1, cols = 1)
  writeData(wb, aba, t(cabecalho), startRow = 3, colNames = FALSE)
  addStyle(wb, aba, negrito, rows = 3, cols = 1:7, gridExpand = TRUE)
  linha <- 4
  do_mes <- base |> filter(as.integer(format(data, "%m")) == m)
  for (d in unique(do_mes$data)) {
    d <- as.Date(d, origin = "1970-01-01")
    dia <- do_mes |> filter(data == d)
    inicio <- linha
    for (i in seq_len(nrow(dia))) {
      r <- dia[i, ]
      valores <- list(produto = sample(variantes[[r$produto]], 1), fornada = sample(fornadas_txt[[r$fornada]], 1),
                      produzido = r$produzido, vendido = r$vendido,
                      preco = dinheiro(r$preco_unitario), custo = dinheiro(r$custo_unitario))
      ordem <- if (abril) valores[c("produto", "fornada", "vendido", "produzido", "preco", "custo")]
               else valores[c("fornada", "produto", "produzido", "vendido", "preco", "custo")]
      for (j in seq_along(ordem)) writeData(wb, aba, ordem[[j]], startRow = linha, startCol = j + 1)
      linha <- linha + 1
    }
    # A data vai uma vez só, mesclada sobre as linhas do dia.
    writeData(wb, aba, data_txt(d), startRow = inicio, startCol = 1)
    mergeCells(wb, aba, cols = 1, rows = inicio:(linha - 1))
    # Domingo: total da semana no meio da tabela.
    if (format(d, "%u") == "7") {
      semana <- base |> filter(data > d - 7, data <= d)
      tot <- if (abril) c("TOTAL DA SEMANA", "", "", sum(semana$vendido), sum(semana$produzido))
             else c("TOTAL DA SEMANA", "", "", sum(semana$produzido), sum(semana$vendido))
      writeData(wb, aba, t(tot), startRow = linha, colNames = FALSE)
      addStyle(wb, aba, negrito, rows = linha, cols = 1:7, gridExpand = TRUE)
      linha <- linha + 1
    }
  }
  setColWidths(wb, aba, cols = 1:7, widths = c(12, 16, 22, 11, 11, 10, 10))
}
salvar_xlsx(wb, file.path(caso, "dados", "planilha_baguncada.xlsx"))
stopifnot(xlsx_valido(file.path(caso, "dados", "planilha_baguncada.xlsx")))
cat("Gerados:", nrow(base), "linhas em dados/gabarito.csv e dados/planilha_baguncada.xlsx\n")
