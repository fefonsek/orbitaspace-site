# Caso Indicadores: leitura dos arquivos de dados e checagens.
# A página só mostra números que saem daqui; nada é digitado no index.qmd.
# Se alguma checagem falhar, o render para com a mensagem da checagem.

## ---- formatos ----
num <- function(x, d = 2) formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
pct <- function(x, d = 2) paste0(num(x, d), "%")
extenso <- function(n, feminino = FALSE) {
  nomes <- c("um", "dois", "três", "quatro", "cinco", "seis", "sete", "oito", "nove", "dez")
  if (feminino) nomes[1:2] <- c("uma", "duas")
  if (n >= 1 && n <= 10) nomes[n] else num(n, 0)
}
meses_pt <- c("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho",
              "agosto", "setembro", "outubro", "novembro", "dezembro")
# "2025-06" -> "junho de 2025"
mes_extenso <- function(m) paste(meses_pt[as.integer(substr(m, 6, 7))], "de", substr(m, 1, 4))
# c("2024-01", "2024-02", "2025-09") -> "janeiro e fevereiro de 2024, setembro de 2025"
lista_meses <- function(m) {
  juntar <- function(x) if (length(x) == 1) x else paste(paste(head(x, -1), collapse = ", "), "e", tail(x, 1))
  por_ano <- split(m, substr(m, 1, 4))
  paste(vapply(names(por_ano), \(a) paste(juntar(meses_pt[as.integer(substr(por_ano[[a]], 6, 7))]), "de", a),
               character(1)), collapse = ", ")
}

## ---- leitura ----
ler_caso <- function(caso = ".") {
  arq <- function(x) file.path(caso, "dados", x)
  inventario <- read_csv(arq("inventario.csv"), show_col_types = FALSE, na = "")
  criterios <- read_csv(arq("criterios.csv"), show_col_types = FALSE)
  taxas <- read_csv(arq("taxa_tres_definicoes.csv"), show_col_types = FALSE)
  fichas <- yaml::read_yaml(arq("fichas.yml"))
  ordem_sit <- criterios$nome[criterios$grupo == "situacao"]
  ordem_dest <- criterios$nome[criterios$grupo == "destino"]
  inventario <- inventario |>
    mutate(situacao = factor(situacao, ordem_sit), destino = factor(destino, ordem_dest))

  anual <- taxas |>
    group_by(definicao, ano = substr(mes, 1, 4)) |>
    summarise(taxa = 100 * sum(numerador) / sum(denominador), .groups = "drop")
  mensal <- taxas |> select(mes, definicao, taxa) |> pivot_wider(names_from = definicao, values_from = taxa)

  ind <- list(
    inventario = inventario, criterios = criterios, fichas = fichas,
    definicoes = read_csv(arq("definicoes.csv"), show_col_types = FALSE),
    raci = read_csv(arq("raci.csv"), show_col_types = FALSE, na = ""),
    versoes = read_csv(arq("versoes.csv"), show_col_types = FALSE, col_types = cols(.default = "c")),
    taxas = taxas, mensal = mensal,
    anual = \(def, ano) anual$taxa[anual$definicao == def & anual$ano == as.character(ano)],
    mes = \(def, m) mensal[[def]][mensal$mes == m],
    n = nrow(inventario),
    n_areas = n_distinct(inventario$area),
    situacao = table(inventario$situacao),
    destino = table(inventario$destino),
    ope_acima = mensal$mes[mensal$operacao > mensal$rh]
  )
  checar(ind)
  ind
}

## ---- checagens ----
checar <- function(ind) {
  campos <- c("codigo", "indicador", "pilar", "objetivo", "pergunta", "formula", "numerador",
              "denominador", "fora", "quebras", "fonte", "periodicidade", "polaridade", "meta",
              "dono", "responsavel_calculo", "decisao", "relacionados", "versao")
  preenchida <- function(f) all(campos %in% names(f)) && all(nzchar(trimws(unlist(f[campos]))))
  codigos <- vapply(ind$fichas, \(f) f$codigo, character(1))
  diretoria <- ind$inventario |> filter(destino == "Diretoria")
  stopifnot(
    "o inventário precisa ter 40 indicadores" = ind$n == 40,
    "13 indicadores bem definidos" = ind$situacao[["Bem definido"]] == 13,
    "14 indicadores na diretoria" = ind$destino[["Diretoria"]] == 14,
    "14 indicadores na gestão da área" = ind$destino[["Gestão da área"]] == 14,
    "6 indicadores unificados" = ind$destino[["Unificado"]] == 6,
    "6 indicadores descontinuados" = ind$destino[["Descontinuado"]] == 6,
    "toda situação e todo destino do inventário precisam estar nos critérios" =
      !anyNA(ind$inventario$situacao) && !anyNA(ind$inventario$destino),
    "14 fichas" = length(ind$fichas) == 14,
    "toda ficha com todos os campos preenchidos" = all(vapply(ind$fichas, preenchida, logical(1))),
    "códigos de ficha sem repetição" = !anyDuplicated(codigos),
    "todo indicador da diretoria tem ficha" = all(diretoria$ficha %in% codigos),
    "toda ficha corresponde a um indicador da diretoria" = setequal(codigos, diretoria$ficha),
    "as três taxas com 24 meses cada" = nrow(ind$taxas) == 72 && all(table(ind$taxas$definicao) == 24),
    "a taxa do RH bate com o Radar (3,77% em 2024 e em 2025)" =
      round(ind$anual("rh", 2024), 2) == 3.77 && round(ind$anual("rh", 2025), 2) == 3.77
  )
  invisible(TRUE)
}
