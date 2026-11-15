# Caso Mentoria (Padaria Grão Dourado): organiza a planilha bagunçada.
# Uso, na pasta do site: Rscript projetos/mentoria-padaria/scripts/organizar.R
#
# É o passo que o encontro ensina, feito em código para conferir: lê as três
# abas de dados/planilha_baguncada.xlsx, desfaz a data mesclada, tira os
# totais do meio da tabela, põe as colunas na mesma ordem, padroniza nomes de
# produtos e fornadas, converte datas e valores e grava
# dados/padaria_organizada.csv (uma linha por dia, produto e fornada).
# No fim, compara com dados/gabarito.csv: se uma linha não bater, para com erro.

suppressPackageStartupMessages({ library(dplyr); library(openxlsx) })
args <- commandArgs(trailingOnly = FALSE)
caso <- normalizePath(file.path(dirname(sub("^--file=", "", args[grep("^--file=", args)])), ".."))
source(file.path(caso, "scripts", "rotulos.R"))

arquivo <- file.path(caso, "dados", "planilha_baguncada.xlsx")
meses_pt <- c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez")

sem_acento <- function(x) tolower(iconv(x, "UTF-8", "ASCII//TRANSLIT"))
produto_padrao <- function(x) {
  x <- sem_acento(x)
  case_when(grepl("queijo", x) ~ "queijo", grepl("frances", x) ~ "frances", grepl("fuba", x) ~ "fuba",
            grepl("sonho", x) ~ "sonho", grepl("forma", x) ~ "forma", grepl("salg", x) ~ "salgado")
}
fornada_padrao <- function(x) paste0(as.integer(sub("^\\s*(\\d+).*$", "\\1", x)), "h")
valor <- function(x) as.numeric(sub(",", ".", gsub("R\\$|\\s", "", x)))
data_padrao <- function(x) {
  x <- trimws(as.character(x))
  out <- rep(as.Date(NA), length(x))
  serial <- grepl("^\\d{5}$", x)
  out[serial] <- as.Date(as.numeric(x[serial]), origin = "1899-12-30")
  iso <- grepl("^\\d{4}-\\d{2}-\\d{2}$", x)
  out[iso] <- as.Date(x[iso])
  barra <- grepl("^\\d{1,2}/\\d{1,2}$", x)
  out[barra] <- as.Date(paste0("2026/", sub("^(\\d+)/(\\d+)$", "\\2/\\1", x[barra])), "%Y/%m/%d")
  extenso <- grepl("^\\d{1,2} [a-z]{3}$", x)
  partes <- strsplit(x[extenso], " ")
  out[extenso] <- as.Date(sprintf("2026-%02d-%02d", match(vapply(partes, `[`, "", 2), meses_pt),
                                  as.integer(vapply(partes, `[`, "", 1))))
  out
}

ler_aba <- function(aba) {
  bruto <- read.xlsx(arquivo, sheet = aba, startRow = 3, colNames = TRUE, fillMergedCells = TRUE,
                     detectDates = FALSE)
  names(bruto) <- sem_acento(names(bruto))
  bruto |>
    filter(!grepl("TOTAL", data, ignore.case = TRUE), !is.na(produto)) |>
    transmute(data = data_padrao(data), fornada = fornada_padrao(fornada), produto = produto_padrao(produto),
              produzido = as.integer(produzido), vendido = as.integer(vendido),
              preco_unitario = valor(preco), custo_unitario = valor(custo))
}

organizada <- bind_rows(lapply(getSheetNames(arquivo), ler_aba)) |>
  mutate(dia_semana = rotulos("pt")$dias[as.integer(format(data, "%u"))], .after = data) |>
  arrange(data, match(fornada, FORNADAS), match(produto, PRODUTOS))
stopifnot(!anyNA(organizada))
write.csv(organizada, file.path(caso, "dados", "padaria_organizada.csv"), row.names = FALSE, fileEncoding = "UTF-8")

gabarito <- read.csv(file.path(caso, "dados", "gabarito.csv"), encoding = "UTF-8") |> mutate(data = as.Date(data))
diferencas <- anti_join(gabarito, organizada, by = names(gabarito))
if (nrow(organizada) != nrow(gabarito) || nrow(diferencas) > 0) {
  print(head(diferencas))
  stop("A planilha organizada não bate com o gabarito: ", nrow(diferencas), " linhas diferentes.")
}
cat("Organizada:", nrow(organizada), "linhas; igual ao gabarito.\n")
