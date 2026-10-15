# Caso Auditoria: gera os dados fictícios da Fiorena Redes Elétricas S.A.
#
# Cinco tabelas em dados/, no formato em que viriam do sistema de benefícios,
# do diário de campo e do RH, para janeiro a dezembro de 2025. O gerador planta
# defeitos com tamanho conhecido e também casos que parecem erro e não são.
# O que foi plantado vai para resultados/gabarito.csv.gz, que a auditoria
# (scripts/auditoria.R) não lê; só scripts/conferir.R compara os dois.
#
# Uso, a partir da pasta do site:
#   Rscript projetos/auditoria-alimentacao/scripts/gerar_dados.R
# Semente fixa: rodar de novo gera exatamente os mesmos arquivos.

arquivo <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
setwd(normalizePath(file.path(dirname(arquivo), ".."), winslash = "/"))
suppressPackageStartupMessages(library(tidyverse))
set.seed(20251015)

## ---- regras ----
# Regras do benefício (inventadas para o caso).
VALOR <- c(almoco = 52, jantar = 44)
EXTRA_MAX <- 24
TETO <- 120
JUSTIFICATIVAS <- c("Deslocamento acima de 300 km", "Jornada estendida em mais de 2 horas")

## ---- calendario ----
ano <- seq(as.Date("2025-01-01"), as.Date("2025-12-31"), by = "day")
feriados <- as.Date(c("2025-01-01", "2025-03-03", "2025-03-04", "2025-04-18", "2025-04-21", "2025-05-01",
                      "2025-06-19", "2025-11-20", "2025-12-25"))
uteis <- ano[!format(ano, "%u") %in% c("6", "7") & !ano %in% feriados]

## ---- bases-e-equipes ----
# Oito bases; a taxa de pernoite varia com a distância das obras. A partir de
# agosto entra um contrato com obras mais longe, e os pernoites sobem.
bases <- tibble(
  base = sprintf("B%d", 1:8),
  cidade = c("Vale Claro", "Serra Alta", "Porto Brando", "Lagoa Funda", "Campina Rasa", "Morro Liso",
             "Santa Aurélia", "Barra Serena"),
  supervisor = c("Supervisor B1", "Supervisor B2", "Supervisor B3", "Supervisor B4", "Supervisor B5",
                 "Supervisor B6", "Supervisor B7", "Supervisor B8"),
  equipes = c(21, 19, 15, 18, 19, 14, 18, 19),
  pernoite = c(0.10, 0.12, 0.13, 0.11, 0.12, 0.14, 0.10, 0.12)
)
equipes <- bases |>
  select(base, equipes) |>
  uncount(equipes) |>
  mutate(equipe = sprintf("E%03d", row_number()))

## ---- cadastro ----
# Quatro vagas por equipe (um encarregado e três eletricistas). Parte das
# pessoas sai durante o ano; a vaga é ocupada por alguém admitido semanas depois.
vagas <- equipes |>
  slice(rep(seq_len(n()), each = 4)) |>
  mutate(cargo = rep(c("Encarregado", "Eletricista", "Eletricista", "Eletricista"), length.out = n()))
iniciais <- vagas |>
  mutate(admissao = as.Date("2025-01-01") - sample(60:4000, n(), replace = TRUE),
         sai = runif(n()) < 0.13,
         desligamento = if_else(sai, sample(ano[30:330], n(), replace = TRUE), as.Date(NA)))
substitutos <- iniciais |>
  filter(sai) |>
  mutate(admissao = desligamento + sample(10:40, n(), replace = TRUE), desligamento = as.Date(NA), sai = FALSE) |>
  filter(admissao <= as.Date("2025-12-15"))
cadastro <- bind_rows(iniciais, substitutos) |>
  mutate(matricula = sprintf("F%04d", sample(1000:9999, n()))) |>
  select(matricula, base, equipe, cargo, admissao, desligamento)

## ---- ausencias ----
# Férias em um, dois ou três períodos; afastamentos e licenças.
fim_ativo <- function(d) coalesce(d, as.Date("2025-12-31"))
ferias <- cadastro |>
  filter(admissao <= as.Date("2025-06-30")) |>
  mutate(periodos = sample(1:3, n(), replace = TRUE, prob = c(0.35, 0.50, 0.15))) |>
  uncount(periodos, .id = "p") |>
  group_by(matricula) |>
  mutate(dias = case_when(n() == 1 ~ 30L, n() == 2 ~ 15L, TRUE ~ 10L)) |>
  ungroup() |>
  mutate(inicio = as.Date(NA))
# Datas de férias com mais peso em janeiro, julho e dezembro.
peso_mes <- c(3, 1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 2.5)
for (i in seq_len(nrow(ferias))) {
  janela <- ano[ano >= max(ferias$admissao[i] + 30, as.Date("2025-01-01")) &
                ano <= fim_ativo(ferias$desligamento[i]) - ferias$dias[i]]
  if (length(janela) == 0) next
  ferias$inicio[i] <- sample(janela, 1, prob = peso_mes[as.integer(format(janela, "%m"))])
}
ferias <- ferias |>
  filter(!is.na(inicio)) |>
  group_by(matricula) |> arrange(inicio, .by_group = TRUE) |>
  # períodos da mesma pessoa não se sobrepõem
  filter(is.na(lag(inicio)) | inicio > lag(inicio) + lag(dias) + 5) |>
  ungroup() |>
  transmute(matricula, tipo = "Férias", inicio, fim = inicio + dias - 1)
outras <- cadastro |>
  mutate(n_af = rbinom(n(), 1, 0.45), n_lic = rbinom(n(), 1, 0.18)) |>
  pivot_longer(c(n_af, n_lic), names_to = "qual", values_to = "tem") |>
  filter(tem == 1) |>
  mutate(tipo = if_else(qual == "n_af", "Afastamento", "Licença"),
         dias = if_else(tipo == "Afastamento", sample(c(2:15, 20, 30, 45, 60), n(), replace = TRUE), 5L),
         inicio = map2_vec(admissao, desligamento, \(a, d) {
           janela <- ano[ano >= max(a, as.Date("2025-01-01")) & ano <= fim_ativo(d) - 5]
           if (length(janela)) sample(janela, 1) else as.Date(NA)
         })) |>
  filter(!is.na(inicio)) |>
  transmute(matricula, tipo, inicio, fim = inicio + dias - 1)
ausencias <- bind_rows(ferias, outras) |>
  arrange(matricula, inicio) |>
  group_by(matricula) |>
  filter(is.na(lag(fim)) | inicio > lag(fim)) |>
  ungroup()

## ---- diario ----
# Uma linha por equipe em campo num dia útil. Parte dos pernoites é registrada
# no diário com um a três dias de atraso (caso que parece erro e não é).
diario <- crossing(equipes |> select(equipe, base), data = uteis) |>
  filter(runif(n()) < 0.925) |>
  left_join(bases |> select(base, taxa = pernoite), "base") |>
  mutate(fator = if_else(data >= as.Date("2025-08-01"), 1.6, 1),
         pernoite = runif(n()) < taxa * fator,
         municipio = sprintf("MUN-%s%02d", substr(base, 2, 2), sample(1:12, n(), replace = TRUE)),
         ordem_servico = sprintf("OS-%06d", sample(100000:999999, n())),
         atraso = if_else(pernoite & runif(n()) < 0.12, sample(1:3, n(), replace = TRUE), 0L),
         registrado_em = data + atraso) |>
  select(equipe, base, data, municipio, pernoite, ordem_servico, registrado_em, atraso)

## ---- recargas-legitimas ----
# Cada pessoa ativa, fora de férias e afastamentos, recebe almoço em cada dia
# de campo da equipe, jantar quando há pernoite e, às vezes, um extra.
presentes <- diario |>
  select(equipe, base, data, pernoite) |>
  inner_join(cadastro |> select(matricula, equipe, admissao, desligamento), "equipe",
             relationship = "many-to-many") |>
  filter(data >= admissao, is.na(desligamento) | data <= desligamento) |>
  anti_join(ausencias, join_by(matricula, between(data, inicio, fim))) |>
  select(matricula, base, equipe, dia = data, pernoite)

extras <- presentes |>
  filter(runif(n()) < if_else(pernoite, 0.16, 0.05)) |>
  mutate(tipo = "extra", valor = sample(c(12, 16, 20, 24), n(), replace = TRUE),
         justificativa = sample(JUSTIFICATIVAS, n(), replace = TRUE))
legitimas <- bind_rows(
  presentes |> mutate(tipo = "almoco", valor = VALOR[["almoco"]], justificativa = NA),
  presentes |> filter(pernoite) |> mutate(tipo = "jantar", valor = VALOR[["jantar"]], justificativa = NA),
  extras
) |>
  mutate(plantado = NA_character_)

## ---- defeitos ----
amostra <- function(d, n) d[sample(nrow(d), min(n, nrow(d))), ]
dias_campo <- diario |> select(equipe, data, pernoite)

# 1. Jantar sem pernoite: duas bases, três meses cada, parte dos presentes
#    recebe jantar em dia sem pernoite.
meses_jantar <- tibble(base = c("B3", "B3", "B3", "B6", "B6", "B6"), mes = c(8, 9, 10, 5, 11, 12))
jantar_sem <- presentes |>
  filter(!pernoite) |>
  mutate(mes = as.integer(format(dia, "%m"))) |>
  semi_join(meses_jantar, c("base", "mes")) |>
  filter(runif(n()) < 0.40) |>
  mutate(tipo = "jantar", valor = VALOR[["jantar"]], justificativa = NA, plantado = "jantar_sem_pernoite") |>
  select(-mes)

# 2. Acima do teto: extra acima de R$ 24 em dia com almoço e jantar.
teto <- presentes |>
  filter(pernoite) |>
  anti_join(extras, c("matricula", "dia")) |>
  amostra(1500) |>
  mutate(tipo = "extra", valor = sample(c(36, 40, 44, 48), n(), replace = TRUE),
         justificativa = sample(JUSTIFICATIVAS, n(), replace = TRUE), plantado = "acima_do_teto")

# 3. Justificativa vaga ou ausente em extras de valor normal.
vagas_just <- presentes |>
  anti_join(extras, c("matricula", "dia")) |>
  anti_join(teto, c("matricula", "dia")) |>
  amostra(1300) |>
  mutate(tipo = "extra", valor = sample(c(12, 16, 20, 24), n(), replace = TRUE),
         ausente = runif(n()) < 0.3,
         justificativa = if_else(ausente, NA_character_, sample(c("ajuste", "conforme combinado", "Ajuste valor", "acerto"), n(), replace = TRUE)),
         plantado = if_else(ausente, "justificativa_ausente", "justificativa_vaga")) |>
  select(-ausente)

# 4. Pessoa fora do trabalho: o cadastro chega à base com atraso, e a recarga
#    sai nos primeiros dias de férias e afastamentos, ou depois do desligamento.
fora_ausencia <- ausencias |>
  filter(runif(n()) < if_else(tipo == "Férias", 0.55, 0.35)) |>
  mutate(k = sample(1:5, n(), replace = TRUE, prob = c(0.3, 0.25, 0.2, 0.15, 0.1))) |>
  rowwise() |> mutate(dia = list(seq(inicio, min(fim, inicio + k - 1), by = "day"))) |> ungroup() |>
  unnest(dia) |>
  select(matricula, dia)
fora_deslig <- cadastro |>
  filter(!is.na(desligamento)) |>
  filter(runif(n()) < 0.6) |>
  mutate(k = sample(1:6, n(), replace = TRUE)) |>
  rowwise() |> mutate(dia = list(desligamento + seq_len(k))) |> ungroup() |>
  unnest(dia) |>
  select(matricula, dia)
fora <- bind_rows(fora_ausencia, fora_deslig) |>
  left_join(cadastro |> select(matricula, base, equipe), "matricula") |>
  inner_join(dias_campo, c("equipe", "dia" = "data")) |>
  mutate(tipo = "almoco", valor = VALOR[["almoco"]], justificativa = NA, plantado = "fora_do_trabalho")
fora <- bind_rows(fora, fora |> filter(pernoite) |> mutate(tipo = "jantar", valor = VALOR[["jantar"]]))

# 5. Sem lastro de campo: recarga num dia útil em que a equipe não está no diário.
sem_lastro <- cadastro |>
  filter(is.na(desligamento)) |>
  select(matricula, base, equipe) |>
  crossing(dia = uteis) |>
  anti_join(dias_campo, c("equipe", "dia" = "data")) |>
  anti_join(ausencias, join_by(matricula, between(dia, inicio, fim))) |>
  inner_join(cadastro |> select(matricula, admissao), "matricula") |>
  filter(dia >= admissao) |>
  amostra(4500) |>
  mutate(pernoite = FALSE, tipo = "almoco", valor = VALOR[["almoco"]], justificativa = NA, plantado = "sem_lastro") |>
  select(-admissao)

recargas <- bind_rows(legitimas, jantar_sem, teto, vagas_just, fora, sem_lastro)

# 6. Duplicidade: a mesma recarga lançada duas vezes. Quase não acontece até
#    julho; a partir da troca do sistema de recarga, em agosto, fica comum.
dup <- recargas |>
  filter(is.na(plantado), tipo != "extra") |>
  filter(runif(n()) < if_else(dia >= as.Date("2025-08-01"), 0.037, 0.0015)) |>
  mutate(plantado = "duplicidade", segunda = TRUE)
recargas <- bind_rows(recargas |> mutate(segunda = FALSE), dup) |>
  mutate(chave = row_number())

## ---- casos-falsos ----
# Parecem erro e não são: lançamento um ou dois dias depois do dia trabalhado e
# justificativas válidas com erro de digitação. (O pernoite registrado com
# atraso está no diário, na coluna registrado_em.)
digita <- c("Deslocamento acima de 300 km" = "deslocamneto acima de 300km",
            "Jornada estendida em mais de 2 horas" = "jornada extendida em mais de 2h")
recargas <- recargas |>
  mutate(
    lancado_depois = is.na(plantado) & runif(n()) < 0.12,
    atraso = if_else(lancado_depois, sample(1:2, n(), replace = TRUE), 0L)
  ) |>
  # a cópia duplicada sai no mesmo dia da original ou um dia depois
  group_by(matricula, dia, tipo) |>
  mutate(atraso = if_else(segunda, max(atraso[!segunda], 0L) + sample(0:1, n(), replace = TRUE), atraso)) |>
  ungroup() |>
  mutate(
    data_recarga = dia + atraso,
    typo = is.na(plantado) & tipo == "extra" & runif(n()) < 0.15,
    justificativa = if_else(typo, unname(digita[justificativa]), justificativa)
  ) |>
  arrange(data_recarga, base, matricula, chave) |>
  mutate(id = sprintf("R%06d", row_number())) |>
  left_join(bases |> select(base, aprovador = supervisor), "base")

## ---- gabarito ----
pernoite_atrasado <- diario |>
  filter(atraso > 0) |>
  select(equipe, dia = data)
gabarito <- recargas |>
  left_join(cadastro |> select(matricula, equipe_cad = equipe), "matricula") |>
  left_join(pernoite_atrasado |> mutate(pa = TRUE), c("equipe_cad" = "equipe", "dia")) |>
  transmute(id, plantado,
            falso = case_when(!is.na(plantado) ~ NA_character_,
                              typo ~ "digitacao",
                              tipo == "jantar" & coalesce(pa, FALSE) ~ "pernoite_atrasado",
                              lancado_depois ~ "lancado_depois"))

## ---- gravacao ----
dir.create("dados", showWarnings = FALSE)
dir.create("resultados", showWarnings = FALSE)
tipos_pt <- c(almoco = "Almoço", jantar = "Jantar", extra = "Extra")
recargas |>
  transmute(id, matricula, base, data_recarga, dia_referencia = dia, tipo = tipos_pt[tipo], valor,
            justificativa = coalesce(justificativa, ""), aprovador) |>
  write_csv("dados/recargas.csv.gz", na = "")
diario |>
  transmute(equipe, base, data, municipio, pernoite = if_else(pernoite, "sim", "não"), ordem_servico, registrado_em) |>
  write_csv("dados/diario_campo.csv")
write_csv(cadastro |> arrange(matricula), "dados/cadastro.csv", na = "")
write_csv(ausencias, "dados/ausencias.csv")
write_csv(bases |> select(base, cidade, supervisor), "dados/bases.csv")
write_csv(gabarito, "resultados/gabarito.csv.gz", na = "")

## ---- conferencia ----
# Os defeitos plantados têm o tamanho que o roteiro pede?
total <- sum(recargas$valor)
peso <- recargas |>
  filter(!is.na(plantado)) |>
  group_by(plantado) |>
  summarise(n = n(), valor = sum(valor), .groups = "drop") |>
  mutate(pct = 100 * valor / total)
cat(sprintf("Recargas: %d | valor: R$ %s | pessoas: %d | diário: %d | ausências: %d\n",
            nrow(recargas), format(round(total), big.mark = ".", decimal.mark = ","), nrow(cadastro), nrow(diario), nrow(ausencias)))
print(peso)
alvo <- c(duplicidade = 1.5, fora_do_trabalho = 1.0, jantar_sem_pernoite = 1.0, sem_lastro = 3.0)
stopifnot(
  "valor pago perto de R$ 8 milhões" = abs(total / 8e6 - 1) < 0.08,
  "defeitos plantados perto do peso-alvo" =
    all(abs(peso$pct[match(names(alvo), peso$plantado)] - alvo) < 0.35)
)
message("Caso Auditoria: dados gerados em dados/ e gabarito em resultados/gabarito.csv.gz.")
