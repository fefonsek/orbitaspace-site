# Caso Mentoria (Padaria Grão Dourado): confere a planilha modelo.
# Uso, na pasta do site: Rscript projetos/mentoria-padaria/scripts/conferir_planilha.R
#
# Calcula as fórmulas de cada planilha (PT, ES, EN) com o pycel
# (scripts/calcular_planilha.py, sem abrir o Excel) e compara as células da
# aba de indicadores com resultados/padaria.rds (os números da página). Para
# com erro se alguma diferença passar de 1 centavo ou de 0,01 ponto
# percentual. Precisa de Python com o pycel instalado (pip install pycel); a
# pasta do pacote pode vir de ORBITA_PYCEL (vai para o PYTHONPATH).
# A conferência manual no Google Planilhas complementa esta.

suppressPackageStartupMessages({ library(dplyr); library(openxlsx) })
args <- commandArgs(trailingOnly = FALSE)
caso <- normalizePath(file.path(dirname(sub("^--file=", "", args[grep("^--file=", args)])), ".."))
source(file.path(caso, "scripts", "rotulos.R"))

res <- readRDS(file.path(caso, "resultados", "padaria.rds"))
pos <- readRDS(file.path(caso, "resultados", "planilha_posicoes.rds"))
csv_valores <- file.path(tempdir(), "planilhas_calculadas.csv")
alvos <- vapply(pos, function(p) paste(p$arquivo, p$aba_i, p$tot, sep = ":"), "")
if (nzchar(Sys.getenv("ORBITA_PYCEL"))) Sys.setenv(PYTHONPATH = Sys.getenv("ORBITA_PYCEL"))
status <- system2("python", c(shQuote(file.path(caso, "scripts", "calcular_planilha.py")), shQuote(csv_valores),
                              shQuote(alvos)))
if (status != 0) stop("O pycel não calculou as planilhas (veja acima).")
valores <- read.csv(csv_valores, encoding = "UTF-8", colClasses = "character")

problemas <- character()
for (idioma in names(pos)) {
  p <- pos[[idioma]]
  v <- valores[valores$arquivo == p$arquivo, ]
  celula <- function(l, c) suppressWarnings(as.numeric(v$valor[v$linha == l & v$coluna == c]))

  # Bloco 1: taxa de sobra (linhas 4 em diante, colunas B a E).
  for (i in seq_along(PRODUTOS)) for (j in seq_along(FORNADAS)) {
    esperado <- res$sobra$taxa[res$sobra$produto == PRODUTOS[i] & res$sobra$fornada == FORNADAS[j]]
    obtido <- celula(3 + i, 1 + j)
    if (length(esperado) == 0) {
      if (!is.na(obtido)) problemas <- c(problemas, sprintf("%s: sobra %s %s deveria estar vazia", idioma, PRODUTOS[i], FORNADAS[j]))
    } else if (is.na(obtido) || abs(100 * obtido - esperado) > 0.01) {
      problemas <- c(problemas, sprintf("%s: sobra %s %s = %s, esperado %.2f%%", idioma, PRODUTOS[i], FORNADAS[j],
                                        obtido, esperado))
    }
  }
  # Blocos 2 e 3: margem real (G) e participação (H) por produto, e o total.
  for (i in seq_along(PRODUTOS)) {
    m <- res$margem[res$margem$produto == PRODUTOS[i], ]
    linha <- p$primeira + i - 1
    if (abs(celula(linha, 7) - m$margem) > 0.01) problemas <- c(problemas, sprintf("%s: margem %s", idioma, PRODUTOS[i]))
    if (abs(100 * celula(linha, 8) - m$participacao) > 0.01) problemas <- c(problemas, sprintf("%s: participação %s", idioma, PRODUTOS[i]))
    if (abs(celula(linha, 2) - m$produzido) > 0.5 || abs(celula(linha, 3) - m$vendido) > 0.5)
      problemas <- c(problemas, sprintf("%s: produzido ou vendido de %s", idioma, PRODUTOS[i]))
  }
  if (abs(celula(p$tot, 7) - res$lucro_total) > 0.01) problemas <- c(problemas, sprintf("%s: margem total", idioma))
  cat(sprintf("%s: %s calculada com pycel; margem total R$ %.2f\n", idioma, basename(p$arquivo), celula(p$tot, 7)))
}
if (length(problemas)) stop("A planilha não bate com a página:\n", paste(problemas, collapse = "\n"))
cat("Planilhas conferidas: as fórmulas batem com os números da página nas três línguas.\n")
