# Caso Motivação de desligamento: grava o CSV de prioridades em espanhol e inglês.
#
# Lê resultados/prioridades_gerencias.csv (gravado por scripts/analise.R) e
# grava resultados/prioridades_gerencias_es.csv e _en.csv, com os nomes das
# colunas, das gerências, das prioridades e dos sinais traduzidos
# (scripts/rotulos.R). Os números não mudam: ponto decimal nas três línguas,
# para o arquivo abrir em qualquer programa; "<10" continua "<10".
#
# Uso, a partir da pasta do site:
#   Rscript projetos/motivacao-desligamento/scripts/traduzir_prioridades.R

arquivo <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
setwd(normalizePath(file.path(dirname(arquivo), ".."), winslash = "/"))
suppressPackageStartupMessages(library(tidyverse))
source("scripts/rotulos.R")

prioridades <- read_csv("resultados/prioridades_gerencias.csv", show_col_types = FALSE, na = "",
                        col_types = cols(.default = "c"))

for (idioma in c("es", "en")) {
  tx <- rotulos(idioma)
  traduzido <- prioridades |>
    mutate(gerencia = tx$gerencia(gerencia), unidade = tx$unidade(unidade),
           prioridade = traduzir(prioridade, tx$prioridades),
           sinais = vapply(strsplit(coalesce(sinais, ""), "; "), \(s) paste(tx$sinal(s), collapse = "; "), ""),
           sinais = na_if(sinais, ""))
  stopifnot("toda prioridade tem tradução" = all(prioridades$prioridade %in% names(tx$prioridades)),
            "todas as colunas têm tradução" = setequal(names(prioridades), names(tx$csv_colunas)),
            "toda gerência foi traduzida" = !any(traduzido$gerencia == prioridades$gerencia &
                                                  grepl("Vendas|Operações|Expedição|Recebimento|Administrativo",
                                                        prioridades$gerencia)))
  names(traduzido) <- unname(tx$csv_colunas[names(traduzido)])
  write_csv(traduzido, sprintf("resultados/prioridades_gerencias_%s.csv", idioma), na = "")
}
message("Caso Motivação de desligamento: prioridades_gerencias_es.csv e _en.csv gravados.")
