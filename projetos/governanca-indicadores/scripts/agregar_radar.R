# Caso Indicadores: as três taxas de absenteísmo da Vallora, mês a mês.
#
# Lê a base do Radar de Absenteísmo (pasta data/raw do projeto do painel, só
# leitura) e grava dados/taxa_tres_definicoes.csv: 24 meses x 3 definições,
# 72 linhas, só com somas da empresa inteira. Nenhuma linha por pessoa,
# equipe ou unidade sai daqui, e nenhum arquivo do Radar é copiado.
#
# O projeto do painel é procurado na pasta "radar-absenteismo-powerbi" ao lado
# da pasta do site, ou no caminho da variável ORBITA_ORIGEM_PAINEL (a mesma do
# scripts/preparar_imagens.py). Nunca lê _privado/.
#
# Uso, a partir da pasta do site:
#   Rscript projetos/governanca-indicadores/scripts/agregar_radar.R
# O render.ps1 faz isso sozinho quando a base do Radar ou este script mudam.

arquivo <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
setwd(normalizePath(file.path(dirname(arquivo), ".."), winslash = "/"))

suppressPackageStartupMessages(library(tidyverse))

origem <- Sys.getenv("ORBITA_ORIGEM_PAINEL")
if (origem == "") origem <- "../../../radar-absenteismo-powerbi"
raw <- file.path(origem, "data", "raw")
if (!dir.exists(raw)) stop("Base do Radar não encontrada em ", normalizePath(raw, mustWork = FALSE))

ler <- function(tabela) {
  read_delim(file.path(raw, paste0(tabela, ".csv")), delim = ";", show_col_types = FALSE,
             locale = locale(decimal_mark = ",", encoding = "UTF-8"))
}

## ---- leitura ----
# Os mesmos tratamentos do Power Query do Radar: cadastro sem duplicados,
# ausências sem linhas repetidas nem horas negativas, só funcionários com
# cadastro, e datas de evento invertidas de volta.
tipos <- ler("Dim_TipoAusencia")
cadastro <- ler("Dim_Funcionario") |> distinct(id_funcionario)
eventos <- ler("Fato_EventoAusencia") |>
  semi_join(cadastro, "id_funcionario") |>
  mutate(across(c(data_inicio, data_fim), dmy), inicio = pmin(data_inicio, data_fim)) |>
  select(id_evento, inicio, dias_corridos)
ausencias <- ler("Fato_AusenciaDiaria") |>
  distinct() |>
  filter(horas_ausencia > 0) |>
  semi_join(cadastro, "id_funcionario") |>
  mutate(data = dmy(data)) |>
  left_join(select(tipos, id_tipo_ausencia, considera_taxa), "id_tipo_ausencia") |>
  left_join(eventos, "id_evento") |>
  mutate(dia_do_evento = as.integer(data - inicio) + 1, mes = floor_date(data, "month"))
jornada <- ler("Fato_Jornada") |>
  semi_join(cadastro, "id_funcionario") |>
  mutate(data = dmy(data), mes = floor_date(data, "month"))

## ---- definicoes ----
# Tipos da base: 1 atestado médico, 2 consulta ou exame (parcial), 3 acidente
# de trabalho, 4 afastamento do INSS, 5 falta injustificada, 6 atraso ou saída
# antecipada, 7 licença legal (CLT art. 473), 8 acompanhamento de dependente,
# 9 licença maternidade/paternidade (dias já fora da jornada no Radar).
# RH: horas de ausência dos tipos que contam no Radar ÷ horas previstas.
rh <- ausencias |> filter(considera_taxa == 1)

# Operação: dias escalados com qualquer ausência (atraso ou saída antecipada só
# acima de 10 minutos) ÷ dias escalados. Quem está afastado há mais de 15 dias
# (do 16º dia de um evento longo em diante) sai da escala, no numerador e no
# denominador.
afastado <- ausencias |> filter(dias_corridos > 15, dia_do_evento > 15) |> distinct(id_funcionario, data)
escala <- jornada |> anti_join(afastado, c("id_funcionario", "data"))
dias_com_ausencia <- escala |>
  semi_join(filter(ausencias, id_tipo_ausencia != 6 | horas_ausencia * 60 > 10), c("id_funcionario", "data"))

# Financeiro: horas pagas pela empresa ÷ horas previstas. Entram atestados e
# acidentes de até 15 dias, consultas, licenças legais e os 15 primeiros dias
# dos afastamentos longos por doença ou acidente (tipos 1, 3 e 4), que a empresa
# paga por lei. Ficam fora faltas e atrasos (descontados), o que o INSS paga e
# o acompanhamento de dependente.
pagas <- ausencias |>
  filter(id_tipo_ausencia == 7 |
           (id_tipo_ausencia %in% c(1, 2, 3) & dias_corridos <= 15) |
           (id_tipo_ausencia %in% c(1, 3, 4) & dias_corridos > 15 & dia_do_evento <= 15))

## ---- agregacao ----
por_mes <- function(d, definicao, unidade, numerador, denominador) {
  full_join(d |> group_by(mes) |> summarise(numerador = {{ numerador }}),
            denominador, "mes") |>
    mutate(definicao = definicao, unidade = unidade, numerador = coalesce(numerador, 0))
}
horas_previstas <- jornada |> group_by(mes) |> summarise(denominador = sum(horas_previstas))
dias_escalados <- escala |> count(mes, name = "denominador")

taxas <- bind_rows(
  por_mes(rh, "rh", "horas", sum(horas_ausencia), horas_previstas),
  por_mes(dias_com_ausencia, "operacao", "dias", n(), dias_escalados),
  por_mes(pagas, "financeiro", "horas", sum(horas_ausencia), horas_previstas)
) |>
  transmute(mes = format(mes, "%Y-%m"), definicao, unidade,
            numerador = round(numerador, 2), denominador = round(denominador, 2),
            taxa = round(100 * numerador / denominador, 4)) |>
  arrange(definicao, mes)

## ---- checagens ----
anual <- taxas |>
  group_by(definicao, ano = substr(mes, 1, 4)) |>
  summarise(taxa = 100 * sum(numerador) / sum(denominador), .groups = "drop")
taxa_rh <- anual |> filter(definicao == "rh") |> pull(taxa, name = ano)
stopifnot(
  "o CSV precisa ter 72 linhas (24 meses x 3 definições)" = nrow(taxas) == 72,
  "cada definição precisa ter os 24 meses" = all(count(taxas, definicao)$n == 24),
  "a taxa do RH precisa bater com o Radar (3,77% em 2024 e em 2025)" =
    identical(unname(round(taxa_rh, 2)), c(3.77, 3.77))
)

write_csv(taxas, "dados/taxa_tres_definicoes.csv")
message("Caso Indicadores: dados/taxa_tres_definicoes.csv gravado (", nrow(taxas), " linhas).")
print(anual |> mutate(taxa = round(taxa, 2)) |> pivot_wider(names_from = ano, values_from = taxa))
