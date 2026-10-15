# Caso Auditoria: auditoria de um ano de recargas de alimentação em campo.
#
# Lê só as cinco tabelas de dados/ (nunca o gabarito do gerador) e aplica as
# seis etapas do método: preparar, conferir as regras objetivas, conferir o
# lastro, comparar com o esperado, pontuar o risco e concluir. Grava:
#   resultados/auditoria.rds       resumos que a página e o PDF leem
#   resultados/classificacao.rds   a conclusão de cada recarga
#   resultados/casos_revisar.csv   casos Indevido e Revisar, para baixar
#
# Uso, a partir da pasta do site:
#   Rscript projetos/auditoria-alimentacao/scripts/auditoria.R
#
# As marcas "## ---- nome ----" dividem o script em trechos; a página mostra
# cada etapa num bloco recolhido (knitr::read_chunk).

arquivo <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
setwd(normalizePath(file.path(dirname(arquivo), ".."), winslash = "/"))
suppressPackageStartupMessages(library(tidyverse))

## ---- regras ----
VALOR_MAX <- c("Almoço" = 52, "Jantar" = 44, "Extra" = 24)
TETO <- 120
JUSTIFICATIVAS_VALIDAS <- c("deslocamento acima de 300 km", "jornada estendida em mais de 2 horas")
TERMOS_VAGOS <- c("ajuste", "conforme combinado", "acerto", "ajuste valor")

## ---- etapa-1-preparar ----
# O que vale é o dia de referência (o dia trabalhado), e não a data em que a
# recarga foi lançada. Cada recarga é ligada ao cadastro, às ausências e à
# equipe da pessoa naquele dia no diário de campo.
recargas <- read_csv("dados/recargas.csv.gz", show_col_types = FALSE, na = "",
                     col_types = cols(justificativa = "c"))
diario <- read_csv("dados/diario_campo.csv", show_col_types = FALSE)
cadastro <- read_csv("dados/cadastro.csv", show_col_types = FALSE, na = "")
ausencias <- read_csv("dados/ausencias.csv", show_col_types = FALSE)

base_auditoria <- recargas |>
  mutate(dia = dia_referencia) |>
  left_join(cadastro |> select(matricula, equipe, admissao, desligamento), "matricula") |>
  left_join(ausencias |> select(matricula, tipo_ausencia = tipo, inicio, fim),
            join_by(matricula, between(dia, inicio, fim))) |>
  left_join(diario |> transmute(equipe, dia = data, em_campo = TRUE, pernoite = pernoite == "sim"),
            c("equipe", "dia")) |>
  mutate(em_campo = coalesce(em_campo, FALSE))

## ---- etapa-2-regras ----
# Regras objetivas: cada violação pode ser cobrada. No teto, só o excedente
# conta como indevido; ele é calculado depois de tirar o que já é indevido por
# outra regra, para não contar o mesmo real duas vezes.
normalizar <- function(x) {
  x <- tolower(iconv(coalesce(x, ""), to = "ASCII//TRANSLIT"))
  x <- gsub("([0-9])\\s*km", "\\1 km", x)
  x <- gsub("([0-9])\\s*h\\b", "\\1 horas", x)
  trimws(gsub("[^a-z0-9 ]", " ", gsub("\\s+", " ", x)))
}
# Dicionário com tolerância a erro de digitação: a justificativa vale se
# estiver a até 15% de distância (em letras) de uma das frases da regra.
classificar_justificativa <- function(x) {
  n <- normalizar(x)
  validas <- normalizar(JUSTIFICATIVAS_VALIDAS)
  dist <- adist(n, validas, partial = FALSE) / outer(nchar(n), nchar(validas), pmax)
  case_when(n == "" ~ "ausente",
            apply(dist, 1, min) <= 0.15 ~ "válida",
            TRUE ~ "vaga")
}

# Cada texto diferente é classificado uma vez só.
textos <- unique(coalesce(base_auditoria$justificativa[base_auditoria$tipo == "Extra"], ""))
classes <- classificar_justificativa(textos)

auditada <- base_auditoria |>
  mutate(justificativa_classe = if_else(tipo == "Extra", classes[match(coalesce(justificativa, ""), textos)], NA)) |>
  arrange(matricula, dia, tipo, data_recarga, id) |>
  group_by(matricula, dia, tipo) |>
  mutate(duplicidade = row_number() > 1) |>
  ungroup() |>
  mutate(
    fora_do_trabalho = dia < admissao | (!is.na(desligamento) & dia > desligamento) | !is.na(tipo_ausencia),
    jantar_sem_pernoite = tipo == "Jantar" & !coalesce(pernoite, FALSE),
    extra_sem_justificativa = tipo == "Extra" & justificativa_classe == "ausente",
    motivo_regra = case_when(duplicidade ~ "Duplicidade",
                             fora_do_trabalho ~ "Pessoa fora do trabalho",
                             jantar_sem_pernoite ~ "Jantar sem pernoite",
                             extra_sem_justificativa ~ "Extra sem justificativa"),
    valor_indevido = if_else(is.na(motivo_regra), 0, valor)
  )

# Teto diário: soma do que não é indevido por outra regra; o excedente sai
# primeiro do extra, depois do jantar.
ordem_corte <- c("Extra" = 1, "Jantar" = 2, "Almoço" = 3)
auditada <- auditada |>
  mutate(restante = valor - valor_indevido, corte = ordem_corte[tipo]) |>
  group_by(matricula, dia) |>
  mutate(excedente_dia = pmax(sum(restante) - TETO, 0)) |>
  arrange(corte, .by_group = TRUE) |>
  mutate(antes = cumsum(restante) - restante,
         acima_do_teto = pmin(restante, pmax(excedente_dia - antes, 0))) |>
  ungroup() |>
  mutate(valor_indevido = valor_indevido + acima_do_teto,
         motivo_regra = if_else(is.na(motivo_regra) & acima_do_teto > 0, "Acima do teto", motivo_regra),
         regra = !is.na(motivo_regra)) |>
  select(-restante, -corte, -excedente_dia, -antes)

## ---- etapa-3-lastro ----
# A equipe estava em campo naquele dia? A justificativa do extra é válida,
# vaga ou ausente?
auditada <- auditada |>
  mutate(sem_lastro = !em_campo,
         justificativa_fraca = tipo == "Extra" & justificativa_classe %in% c("vaga", "ausente"))

## ---- etapa-4-esperado ----
# Valor pago por dia de equipe em campo, por base e mês. Como o nível geral
# muda de um mês para outro (mais pernoites no segundo semestre), cada base é
# comparada com a mediana das bases no mesmo mês; a faixa esperada desse
# índice vem do critério de Tukey sobre todos os grupos com pelo menos 15 dias
# de equipe em campo. Como a auditoria procura pagamento a mais, só ficar
# acima da faixa conta como sinal de risco; abaixo dela, o grupo só é anotado.
dias_campo <- diario |>
  mutate(mes = format(data, "%Y-%m")) |>
  count(base, mes, name = "dias_equipe")
base_mes <- auditada |>
  mutate(mes = format(dia, "%Y-%m")) |>
  group_by(base, mes) |>
  summarise(valor = sum(valor), .groups = "drop") |>
  left_join(dias_campo, c("base", "mes")) |>
  mutate(valor_dia = valor / dias_equipe) |>
  group_by(mes) |>
  mutate(mediana_mes = median(valor_dia), indice = valor_dia / mediana_mes) |>
  ungroup()
validos <- base_mes |> filter(dias_equipe >= 15)
q <- quantile(validos$indice, c(0.25, 0.75))
faixa <- c(q[[1]] - 1.5 * diff(q), q[[2]] + 1.5 * diff(q))
base_mes <- base_mes |>
  mutate(faixa_min = faixa[1] * mediana_mes, faixa_max = faixa[2] * mediana_mes,
         abaixo_da_faixa = dias_equipe >= 15 & indice < faixa[1],
         fora_da_faixa = dias_equipe >= 15 & indice > faixa[2])
auditada <- auditada |>
  mutate(mes = format(dia, "%Y-%m")) |>
  left_join(base_mes |> select(base, mes, fora_da_faixa), c("base", "mes")) |>
  mutate(fora_da_faixa = coalesce(fora_da_faixa, FALSE))

## ---- etapa-5-score ----
# Um ponto para cada sinal, de 0 a 4.
auditada <- auditada |>
  mutate(score = regra + sem_lastro + justificativa_fraca + fora_da_faixa,
         score_sem_regra = score - regra)

## ---- etapa-6-concluir ----
# Indevido: violou uma regra objetiva. Revisar: sem regra violada, mas sem
# lastro de campo ou com score de 2 ou mais. Atenção: score 1. Regular: 0.
# Numa recarga que passou do teto só em parte, o excedente é Indevido e o
# resto recebe a conclusão que teria sem essa regra.
concluir <- function(sem_lastro, score) {
  case_when(sem_lastro | score >= 2 ~ "Revisar", score == 1 ~ "Atenção", TRUE ~ "Regular")
}
auditada <- auditada |>
  mutate(conclusao = if_else(regra, "Indevido", concluir(sem_lastro, score)),
         conclusao_resto = concluir(sem_lastro, score_sem_regra),
         valor_resto = valor - valor_indevido)
NIVEIS <- c("Indevido", "Revisar", "Atenção", "Regular")

## ---- resumos ----
total <- sum(auditada$valor)
conclusoes <- bind_rows(
  auditada |> filter(valor_indevido > 0) |> transmute(conclusao = "Indevido", valor = valor_indevido),
  auditada |> filter(valor_resto > 0) |> transmute(conclusao = conclusao_resto, valor = valor_resto)
) |>
  count(conclusao = factor(conclusao, NIVEIS), wt = valor, name = "valor", .drop = FALSE) |>
  left_join(auditada |> count(conclusao = factor(conclusao, NIVEIS), name = "recargas", .drop = FALSE), "conclusao") |>
  mutate(pct = 100 * valor / total)

por_defeito <- auditada |>
  filter(valor_indevido > 0) |>
  count(motivo = motivo_regra, wt = valor_indevido, name = "valor") |>
  left_join(auditada |> filter(valor_indevido > 0) |> count(motivo = motivo_regra, name = "recargas"), "motivo") |>
  mutate(pct = 100 * valor / total) |>
  arrange(desc(valor))

dias_mes <- diario |> count(mes = format(data, "%Y-%m"), name = "dias_equipe")
mensal <- auditada |>
  group_by(mes) |>
  summarise(valor = sum(valor), indevido = sum(valor_indevido), recargas = n(),
            jantar_regular = sum(valor_resto[tipo == "Jantar"]),
            duplicidade = sum(valor_indevido[motivo_regra %in% "Duplicidade"]), .groups = "drop") |>
  left_join(dias_mes, "mes") |>
  mutate(valor_dia = valor / dias_equipe)

# O valor por dia de equipe depende de quantas pessoas cada equipe leva a
# campo. Para explicar as quedas do gráfico mensal: pessoas por dia de equipe,
# valor por pessoa em campo e pessoas de férias por dia útil, mês a mês.
uteis <- diario |> distinct(data)
ferias_mes <- ausencias |>
  filter(tipo == "Férias") |>
  inner_join(uteis, join_by(between(y$data, x$inicio, x$fim))) |>
  count(mes = format(data, "%Y-%m"), name = "pessoas_ferias")
mensal <- mensal |>
  left_join(auditada |> distinct(mes, matricula, dia) |> count(mes, name = "pessoas_dia"), "mes") |>
  left_join(ferias_mes, "mes") |>
  left_join(uteis |> count(mes = format(data, "%Y-%m"), name = "dias_uteis"), "mes") |>
  mutate(pessoas_por_equipe = pessoas_dia / dias_equipe, valor_pessoa = valor / pessoas_dia,
         ferias_por_dia = pessoas_ferias / dias_uteis)

# O salto do custo por dia em campo do 1º para o 2º semestre, separado em
# indevido, jantares legítimos (mais pernoites) e o resto.
semestre <- mensal |>
  mutate(semestre = if_else(mes <= "2025-06", "1", "2")) |>
  group_by(semestre) |>
  summarise(across(c(valor, indevido, jantar_regular, dias_equipe), sum), .groups = "drop") |>
  mutate(por_dia = valor / dias_equipe, indevido_dia = indevido / dias_equipe,
         jantar_dia = jantar_regular / dias_equipe,
         outros_dia = por_dia - indevido_dia - jantar_dia)
pernoite_sem <- diario |>
  mutate(semestre = if_else(data <= as.Date("2025-06-30"), "1", "2")) |>
  group_by(semestre) |>
  summarise(pernoite = mean(pernoite == "sim"), .groups = "drop")
salto <- with(semestre, list(
  h1 = por_dia[1], h2 = por_dia[2], total = por_dia[2] - por_dia[1], pct = 100 * (por_dia[2] / por_dia[1] - 1),
  indevido = indevido_dia[2] - indevido_dia[1], jantar = jantar_dia[2] - jantar_dia[1],
  outros = outros_dia[2] - outros_dia[1], pernoite_h1 = pernoite_sem$pernoite[1], pernoite_h2 = pernoite_sem$pernoite[2]))

## ---- achados ----
dup_mes <- auditada |>
  filter(duplicidade) |>
  count(mes, wt = valor, name = "valor")
ferias_dia <- auditada |>
  filter(fora_do_trabalho, tipo_ausencia %in% "Férias") |>
  mutate(dia_do_periodo = as.integer(dia - inicio) + 1) |>
  count(dia_do_periodo)
jantar_base <- auditada |>
  filter(jantar_sem_pernoite) |>
  count(base, wt = valor, name = "valor") |>
  arrange(desc(valor)) |>
  left_join(base_mes |> group_by(base) |> summarise(meses_fora = sum(fora_da_faixa)), "base")

## ---- casos ----
casos <- auditada |>
  filter(conclusao %in% c("Indevido", "Revisar")) |>
  mutate(motivo = case_when(!is.na(motivo_regra) ~ motivo_regra,
                            sem_lastro ~ "Sem lastro de campo",
                            justificativa_fraca & fora_da_faixa ~ "Justificativa vaga em base e mês acima da faixa",
                            TRUE ~ "Score 2 ou mais"),
         valor_em_risco = if_else(conclusao == "Indevido", valor_indevido, valor)) |>
  arrange(factor(conclusao, NIVEIS), desc(score), desc(valor_em_risco), id) |>
  select(id, matricula, base, dia_referencia = dia, data_recarga, tipo, valor, valor_indevido,
         conclusao, motivo, score, justificativa)
# Os casos de maior valor, por pessoa: as 5 com mais valor Indevido e as 5
# com mais valor a Revisar. Recarga a recarga os valores empatam (R$ 52 ou
# R$ 44), e quem revisa olha a pessoa e o período. No Indevido, o valor é só a
# parte indevida.
top_revisar <- casos |>
  mutate(valor_caso = if_else(conclusao == "Indevido", valor_indevido, valor)) |>
  group_by(conclusao, matricula, base) |>
  summarise(recargas = n(), valor = sum(valor_caso), primeiro = min(dia_referencia), ultimo = max(dia_referencia),
            motivo = names(sort(table(motivo), decreasing = TRUE))[1], .groups = "drop") |>
  arrange(factor(conclusao, NIVEIS), desc(valor), matricula) |>
  group_by(conclusao) |>
  slice_head(n = 5) |>
  ungroup()

# Do que ficou em Atenção (score 1, sem regra violada): quanto é só o ponto
# de base e mês acima da faixa, e quanto é justificativa vaga.
atencao <- auditada |>
  filter(conclusao_resto == "Atenção", valor_resto > 0) |>
  mutate(sinal = if_else(justificativa_fraca, "Justificativa vaga", "Base e mês acima da faixa")) |>
  group_by(sinal) |>
  summarise(recargas = n(), valor = sum(valor_resto), .groups = "drop")

# Do que ficou em Revisar: sem lastro de campo ou só por score de 2 ou mais.
revisar <- auditada |>
  filter(conclusao_resto == "Revisar", valor_resto > 0) |>
  mutate(sinal = if_else(sem_lastro, "Sem lastro de campo", "Score 2 ou mais")) |>
  group_by(sinal) |>
  summarise(recargas = n(), valor = sum(valor_resto), .groups = "drop")

# Indevido por defeito e semestre, para separar o efeito da troca de sistema.
indevido_semestre <- auditada |>
  filter(valor_indevido > 0) |>
  mutate(semestre = if_else(mes <= "2025-06", "1", "2")) |>
  count(motivo = motivo_regra, semestre, wt = valor_indevido, name = "valor")

## ---- checagens ----
stopifnot(
  "toda recarga tem uma conclusão" = !anyNA(auditada$conclusao),
  "as quatro conclusões somam o total pago" = isTRUE(all.equal(sum(conclusoes$valor), total)),
  "o indevido nunca passa do valor da recarga" = all(auditada$valor_indevido <= auditada$valor + 1e-9),
  "uma linha por recarga" = nrow(auditada) == nrow(recargas)
)

## ---- gravacao ----
write_csv(casos, "resultados/casos_revisar.csv", na = "")
saveRDS(auditada |> select(id, conclusao, motivo_regra, valor_indevido, sem_lastro, justificativa_fraca,
                           fora_da_faixa, score),
        "resultados/classificacao.rds")
saveRDS(list(
  total = total, recargas = nrow(auditada), pessoas = n_distinct(auditada$matricula),
  dias_equipe = nrow(diario), bases = n_distinct(diario$base),
  conclusoes = conclusoes, por_defeito = por_defeito, mensal = mensal, semestre = semestre, salto = salto,
  base_mes = base_mes, faixa = faixa, dup_mes = dup_mes, ferias_dia = ferias_dia, jantar_base = jantar_base,
  top_revisar = top_revisar, casos = nrow(casos), atencao = atencao, revisar = revisar, indevido_semestre = indevido_semestre,
  regras = list(valor = VALOR_MAX, teto = TETO, justificativas = JUSTIFICATIVAS_VALIDAS)
), "resultados/auditoria.rds")

cat(sprintf("Total pago: R$ %.0f em %d recargas\n", total, nrow(auditada)))
print(conclusoes)
print(por_defeito)
