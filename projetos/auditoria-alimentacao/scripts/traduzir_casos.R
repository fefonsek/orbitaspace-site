# Caso Auditoria: gera os CSVs de casos para revisar em espanhol e inglês.
#
# Lê resultados/casos_revisar.csv (gravado por scripts/auditoria.R) e grava
# resultados/casos_revisar_es.csv e casos_revisar_en.csv, com os nomes das
# colunas, o tipo, a conclusão e o motivo traduzidos (scripts/rotulos.R). Os
# números e as datas não mudam: ponto decimal e datas ISO nas três línguas,
# para o arquivo abrir em qualquer programa. A justificativa fica como foi
# digitada na base, em português.
#
# Uso, a partir da pasta do site:
#   Rscript projetos/auditoria-alimentacao/scripts/traduzir_casos.R

arquivo <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
setwd(normalizePath(file.path(dirname(arquivo), ".."), winslash = "/"))
suppressPackageStartupMessages(library(tidyverse))
source("scripts/rotulos.R")

casos <- read_csv("resultados/casos_revisar.csv", show_col_types = FALSE, na = "",
                  col_types = cols(.default = "c"))

for (idioma in c("es", "en")) {
  tx <- rotulos(idioma)
  traduzido <- casos |>
    mutate(tipo = traduzir(tipo, tx$tipos), conclusao = traduzir(conclusao, tx$conclusoes),
           motivo = traduzir(motivo, tx$motivos))
  stopifnot("todo motivo tem tradução" = all(casos$motivo %in% names(tx$motivos)),
            "todo tipo tem tradução" = all(casos$tipo %in% names(tx$tipos)),
            "todas as colunas têm tradução" = setequal(names(casos), names(tx$csv_colunas)))
  names(traduzido) <- unname(tx$csv_colunas[names(traduzido)])
  write_csv(traduzido, sprintf("resultados/casos_revisar_%s.csv", idioma), na = "")
}
message("Caso Auditoria: casos_revisar_es.csv e casos_revisar_en.csv gravados.")
