# Caso Motivação de desligamento: análise da base da Cestária Supermercados.
#
# Lê só as seis tabelas de dados/ (nunca o gabarito do gerador) e grava:
#   resultados/desligamento.rds          resumos que a página e o PDF leem
#   resultados/prioridades_gerencias.csv uma linha por gerência, para baixar
#
# Uso, a partir da pasta do site:
#   Rscript projetos/motivacao-desligamento/scripts/analise.R
#
# Regras do caso: só agregados; nenhum grupo com menos de 10 pessoas aparece
# (vira "<10"); proporções sempre com intervalo de confiança de 95%;
# associação não é tratada como causa.
# As marcas "## ---- nome ----" dividem o script em trechos; a página mostra
# cada etapa num bloco recolhido (knitr::read_chunk).

arquivo <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
setwd(normalizePath(file.path(dirname(arquivo), ".."), winslash = "/"))
suppressPackageStartupMessages({
  library(tidyverse)
  library(survival)
})
set.seed(20260127)

## ---- funcoes ----
MINIMO <- 10
# Intervalo de Wilson para uma proporção (em %).
wilson <- function(x, n, lado = c("inf", "sup")) {
  lado <- match.arg(lado)
  z <- qnorm(0.975)
  p <- x / n
  centro <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  meia <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  100 * if (lado == "inf") centro - meia else centro + meia
}
# Taxa por pessoa-mês com intervalo exato de Poisson (em % ao mês).
taxa_ic <- function(x, exposicao, lado = c("inf", "sup")) {
  lado <- match.arg(lado)
  100 * if (lado == "inf") qchisq(0.025, 2 * x) / 2 / exposicao else qchisq(0.975, 2 * (x + 1)) / 2 / exposicao
}
# Soma móvel dos últimos três meses (os dois primeiros meses ficam vazios).
zoo_soma <- function(x) as.numeric(stats::filter(x, rep(1, 3), sides = 1))
VOLUNTARIOS <- c("Pedido de demissão", "Acordo")
MOTIVOS <- c("Salário e benefícios", "Proposta de outra empresa", "Liderança e gestor", "Jornada e escala",
             "Deslocamento", "Crescimento e carreira", "Ambiente e equipe", "Motivos pessoais e família")

## ---- dados ----
estrutura <- read_csv("dados/dim_estrutura.csv", show_col_types = FALSE)
colaborador <- read_csv("dados/dim_colaborador.csv", show_col_types = FALSE)
headcount <- read_csv("dados/fato_headcount_mensal.csv", show_col_types = FALSE)
deslig <- read_csv("dados/fato_desligamentos.csv", show_col_types = FALSE)
entrevista <- read_csv("dados/fato_entrevista_desligamento.csv", show_col_types = FALSE, na = "")

ordem_gerencias <- unique(estrutura$gerencia)
TROCA <- min(estrutura$vigente_de[estrutura$vigente_de > min(estrutura$vigente_de)])
gerencia_troca <- estrutura$gerencia[estrutura$vigente_de == TROCA]
FIM <- max(deslig$data_desligamento, as.Date("2025-12-31"))
JANELA_90 <- FIM - 90

saidas <- deslig |>
  left_join(estrutura |> select(id_estrutura, gerencia, unidade, area), "id_estrutura") |>
  left_join(colaborador, "id_colaborador") |>
  left_join(entrevista, "id_desligamento") |>
  mutate(ano = year(data_desligamento), ano_mes = format(data_desligamento, "%Y-%m"),
         voluntaria = tipo %in% VOLUNTARIOS,
         noite_6x1 = turno == "Noite" & escala == "6x1")

pessoa_mes <- headcount |>
  left_join(estrutura |> select(id_estrutura, gerencia, unidade, area), "id_estrutura") |>
  left_join(colaborador, "id_colaborador") |>
  mutate(ano = as.integer(substr(ano_mes, 1, 4)), peso = (ativo_inicio + ativo_fim) / 2)

## ---- etapa-1-taxa ----
# Taxa de desligamento do mês: desligamentos ÷ headcount médio, em que o
# headcount médio é a média entre o quadro do primeiro e do último dia.
# A fórmula clássica de turnover usa a média entre admissões e desligamentos
# no numerador; as duas aparecem no método.
mensal <- pessoa_mes |>
  group_by(ano_mes) |>
  summarise(hc_medio = sum(peso), admissoes = sum(admitido_no_mes), .groups = "drop") |>
  left_join(saidas |> count(ano_mes, name = "desligamentos"), "ano_mes") |>
  left_join(saidas |> filter(voluntaria) |> count(ano_mes, name = "voluntarios"), "ano_mes") |>
  mutate(across(c(desligamentos, voluntarios), \(x) coalesce(x, 0L)),
         taxa = 100 * desligamentos / hc_medio, taxa_vol = 100 * voluntarios / hc_medio,
         turnover_classico = 100 * (admissoes + desligamentos) / 2 / hc_medio)

anual <- mensal |>
  group_by(ano = as.integer(substr(ano_mes, 1, 4))) |>
  summarise(exposicao = sum(hc_medio), hc_medio = exposicao / n(), desligamentos = sum(desligamentos),
            voluntarios = sum(voluntarios), involuntarios = desligamentos - voluntarios,
            admissoes = sum(admissoes), .groups = "drop") |>
  # Taxa mensal média (por pessoa-mês) e taxa do ano (desligamentos do ano ÷
  # headcount médio do ano).
  mutate(taxa_ano = 100 * desligamentos / hc_medio, taxa_vol_ano = 100 * voluntarios / hc_medio,
         taxa = 100 * desligamentos / exposicao,
         taxa_inf = taxa_ic(desligamentos, exposicao, "inf"), taxa_sup = taxa_ic(desligamentos, exposicao, "sup"),
         taxa_vol = 100 * voluntarios / exposicao,
         taxa_vol_inf = taxa_ic(voluntarios, exposicao, "inf"), taxa_vol_sup = taxa_ic(voluntarios, exposicao, "sup"),
         taxa_inv = 100 * involuntarios / exposicao,
         turnover_classico = 100 * (admissoes + desligamentos) / 2 / exposicao,
         turnover_classico_ano = 100 * (admissoes + desligamentos) / 2 / hc_medio)
teste_anos <- poisson.test(anual$desligamentos, anual$exposicao)

tipos <- saidas |> count(tipo) |> mutate(pct = 100 * n / sum(n))

## ---- etapa-2-noventa-dias ----
# Saídas voluntárias até 90 dias, entre os admitidos no período. Ficam fora os
# admitidos depois de 02/10/2025, que ainda não completaram a janela. Quem foi
# dispensado antes dos 90 dias conta como "não saiu voluntariamente".
coorte <- colaborador |>
  filter(data_admissao >= as.Date("2024-01-01")) |>
  left_join(pessoa_mes |> distinct(id_colaborador, gerencia, unidade) |> distinct(id_colaborador, .keep_all = TRUE),
            "id_colaborador") |>
  left_join(deslig |> select(id_colaborador, data_desligamento, tipo), "id_colaborador") |>
  mutate(ano_admissao = year(data_admissao),
         dias = as.integer(coalesce(data_desligamento, FIM) - data_admissao),
         vol_90 = !is.na(tipo) & tipo %in% VOLUNTARIOS & dias <= 90,
         noite_6x1 = turno == "Noite" & escala == "6x1",
         grupo = if_else(gerencia %in% c("L3 Operações", "CD Expedição"), gerencia, "Demais gerências"))
coorte_90 <- coorte |> filter(data_admissao <= JANELA_90)

noventa_ano <- coorte_90 |>
  group_by(ano_admissao) |>
  summarise(admitidos = n(), saidas = sum(vol_90), .groups = "drop") |>
  mutate(pct = 100 * saidas / admitidos, inf = wilson(saidas, admitidos, "inf"), sup = wilson(saidas, admitidos, "sup"))
noventa_gerencia <- coorte_90 |>
  group_by(gerencia, ano_admissao) |>
  summarise(admitidos = n(), saidas = sum(vol_90), .groups = "drop") |>
  mutate(pct = 100 * saidas / admitidos, inf = wilson(saidas, admitidos, "inf"), sup = wilson(saidas, admitidos, "sup"),
         gerencia = factor(gerencia, ordem_gerencias))
# Diferença 2025 menos 2024 em cada gerência: as duas que mais sobem.
subida_90 <- noventa_gerencia |>
  select(gerencia, ano_admissao, pct, admitidos) |>
  pivot_wider(names_from = ano_admissao, values_from = c(pct, admitidos)) |>
  mutate(diferenca = pct_2025 - pct_2024) |>
  arrange(desc(diferenca))
noventa_grupo <- coorte_90 |>
  group_by(grupo, ano_admissao) |>
  summarise(admitidos = n(), saidas = sum(vol_90), .groups = "drop") |>
  mutate(pct = 100 * saidas / admitidos, inf = wilson(saidas, admitidos, "inf"), sup = wilson(saidas, admitidos, "sup"))

## ---- etapa-3-motivos ----
# Motivo declarado: só quem pediu para sair (pedido ou acordo) e respondeu.
# Pareto geral e entre quem deu nota 1 ou 2 ao gestor.
respondentes <- saidas |> filter(voluntaria, respondeu == "Sim", !is.na(motivo_principal))
pareto <- function(d) {
  d |>
    count(motivo = motivo_principal) |>
    complete(motivo = MOTIVOS, fill = list(n = 0)) |>
    mutate(total = sum(n), pct = 100 * n / total, inf = wilson(n, total, "inf"), sup = wilson(n, total, "sup")) |>
    arrange(desc(n))
}
pareto_geral <- pareto(respondentes)
nota_baixa <- respondentes |> filter(nota_gestor <= 2)
pareto_nota_baixa <- pareto(nota_baixa)
# Quem declarou salário e deu nota baixa ao gestor: quantos põem a liderança
# como motivo secundário.
salario_nota_baixa <- nota_baixa |>
  filter(motivo_principal == "Salário e benefícios") |>
  summarise(n = n(), lideranca_secundario = sum(motivo_secundario %in% "Liderança e gestor")) |>
  mutate(pct = 100 * lideranca_secundario / n, inf = wilson(lideranca_secundario, n, "inf"),
         sup = wilson(lideranca_secundario, n, "sup"))
# Liderança citada como motivo principal ou secundário.
lideranca_qualquer <- respondentes |>
  mutate(nota_baixa = nota_gestor <= 2,
         lideranca = motivo_principal == "Liderança e gestor" | motivo_secundario %in% "Liderança e gestor") |>
  group_by(nota_baixa) |>
  summarise(n = n(), x = sum(lideranca), .groups = "drop") |>
  mutate(pct = 100 * x / n, inf = wilson(x, n, "inf"), sup = wilson(x, n, "sup"))

## ---- etapa-4-resposta ----
# Taxa de resposta da entrevista e ponderação pela inversa da taxa de resposta.
resposta_tipo <- saidas |>
  group_by(voluntaria) |>
  summarise(saidas = n(), responderam = sum(respondeu == "Sim"), .groups = "drop") |>
  mutate(pct = 100 * responderam / saidas, inf = wilson(responderam, saidas, "inf"),
         sup = wilson(responderam, saidas, "sup"))
resposta_unidade <- saidas |>
  group_by(unidade) |>
  summarise(saidas = n(), responderam = sum(respondeu == "Sim"), .groups = "drop") |>
  mutate(pct = 100 * responderam / saidas, inf = wilson(responderam, saidas, "inf"),
         sup = wilson(responderam, saidas, "sup"),
         unidade = factor(unidade, unique(estrutura$unidade)))
# Peso de cada resposta voluntária: saídas voluntárias da unidade ÷ respostas
# voluntárias da unidade. Supõe que, dentro de cada unidade, quem respondeu é
# parecido com quem não respondeu.
pesos <- saidas |>
  filter(voluntaria) |>
  group_by(unidade) |>
  summarise(peso = n() / sum(respondeu == "Sim" & !is.na(motivo_principal)), .groups = "drop")
pareto_ponderado <- respondentes |>
  left_join(pesos, "unidade") |>
  group_by(motivo = motivo_principal) |>
  summarise(peso = sum(peso), .groups = "drop") |>
  mutate(pct = 100 * peso / sum(peso)) |>
  right_join(pareto_geral |> select(motivo, pct_sem_peso = pct), "motivo") |>
  mutate(pct = coalesce(pct, 0), diferenca = pct - pct_sem_peso) |>
  arrange(desc(pct))

## ---- etapa-5-motivo-gerencia ----
# Motivo × gerência: qui-quadrado com p por simulação (mesmo agrupando, há
# células com frequência esperada pequena) e resíduos ajustados. Os três
# motivos menos citados viram "Outros motivos". Só |resíduo| >= 3 é destaque,
# por causa das muitas comparações.
MOTIVOS_QUI <- c(MOTIVOS[1:4], "Crescimento e carreira", "Outros motivos")
motivo_qui <- if_else(respondentes$motivo_principal %in% MOTIVOS_QUI, respondentes$motivo_principal, "Outros motivos")
tabela_mg <- table(factor(respondentes$gerencia, ordem_gerencias), factor(motivo_qui, MOTIVOS_QUI))
qui <- suppressWarnings(chisq.test(tabela_mg, simulate.p.value = TRUE, B = 20000))
qui_assint <- suppressWarnings(chisq.test(tabela_mg))
residuos <- as_tibble(as.table(qui$stdres), .name_repair = ~ c("gerencia", "motivo", "residuo")) |>
  left_join(as_tibble(tabela_mg, .name_repair = ~ c("gerencia", "motivo", "n")), c("gerencia", "motivo")) |>
  mutate(destaque = abs(residuo) >= 3)

## ---- etapa-6-incidencia ----
# Incidência acumulada da saída voluntária com a involuntária como risco
# competitivo (Aalen-Johansen), entre os admitidos no período, até 180 dias.
coorte_ce <- coorte |>
  mutate(evento = factor(case_when(is.na(tipo) ~ "censura", tipo %in% VOLUNTARIOS ~ "voluntária",
                                   TRUE ~ "involuntária"), c("censura", "voluntária", "involuntária")),
         dias = pmax(dias, 0.5))
aj <- survfit(Surv(dias, evento) ~ grupo + ano_admissao, data = coorte_ce)
incidencia <- {
  s <- summary(aj, times = 0:180, extend = TRUE)
  col <- which(s$states == "voluntária")
  tibble(estrato = as.character(s$strata), dias = s$time, inc = 100 * s$pstate[, col],
         inf = 100 * s$lower[, col], sup = 100 * s$upper[, col]) |>
    mutate(grupo = str_match(estrato, "grupo=([^,]+)")[, 2],
           ano_admissao = as.integer(str_match(estrato, "ano_admissao=(\\d+)")[, 2]))
}
incidencia_90 <- incidencia |> filter(dias == 90)
# Cox causa-específico (a saída involuntária vira censura): teste global da
# gerência, no lugar do log-rank, e razão de riscos dos dois grupos em 2025.
cox_global <- coxph(Surv(dias, evento == "voluntária") ~ gerencia, data = coorte_ce)
teste_gerencia <- anova(cox_global)
cox_2025 <- coxph(Surv(dias, evento == "voluntária") ~ relevel(factor(grupo), "Demais gerências"),
                  data = filter(coorte_ce, ano_admissao == 2025))
hr_2025 <- broom::tidy(cox_2025, exponentiate = TRUE, conf.int = TRUE) |>
  mutate(grupo = sub(".*\\)", "", term)) |>
  select(grupo, hr = estimate, inf = conf.low, sup = conf.high, p = p.value)

## ---- etapa-7-troca-gestor ----
# L5 Vendas troca de gestor em julho de 2025. Comparação de antes e depois com
# as outras sete gerências de Vendas como controle: saídas voluntárias por
# pessoa-mês, com modelo binomial negativo (diferença em diferenças).
vendas <- pessoa_mes |>
  filter(area == "Vendas") |>
  group_by(gerencia, ano_mes) |>
  summarise(hc = sum(peso), .groups = "drop") |>
  left_join(saidas |> filter(voluntaria, area == "Vendas") |> count(gerencia, ano_mes, name = "vol"),
            c("gerencia", "ano_mes")) |>
  mutate(vol = coalesce(vol, 0L), depois = as.Date(paste0(ano_mes, "-01")) >= TROCA,
         troca = gerencia == gerencia_troca, troca_depois = troca & depois)
# Poisson primeiro; se a dispersão passar de 1,2, binomial negativo.
formula_troca <- vol ~ gerencia + depois + troca_depois + offset(log(hc))
modelo_troca <- glm(formula_troca, family = poisson, data = vendas)
dispersao <- sum(residuals(modelo_troca, type = "pearson")^2) / df.residual(modelo_troca)
if (dispersao > 1.2) modelo_troca <- MASS::glm.nb(formula_troca, data = vendas)
rr_troca <- {
  b <- coef(summary(modelo_troca))["troca_depoisTRUE", ]
  tibble(rr = exp(b[["Estimate"]]), inf = exp(b[["Estimate"]] - 1.96 * b[["Std. Error"]]),
         sup = exp(b[["Estimate"]] + 1.96 * b[["Std. Error"]]), p = b[[4]], dispersao = dispersao,
         modelo = if (dispersao > 1.2) "binomial negativo" else "Poisson")
}
troca_taxas <- vendas |>
  group_by(grupo = if_else(troca, gerencia_troca, "Outras gerências de Vendas"), depois) |>
  summarise(vol = sum(vol), exposicao = sum(hc), .groups = "drop") |>
  mutate(taxa = 100 * vol / exposicao, inf = taxa_ic(vol, exposicao, "inf"), sup = taxa_ic(vol, exposicao, "sup"))
troca_mensal <- vendas |>
  group_by(grupo = if_else(troca, gerencia_troca, "Outras gerências de Vendas"), ano_mes) |>
  summarise(vol = sum(vol), hc = sum(hc), .groups = "drop") |>
  arrange(grupo, ano_mes) |>
  group_by(grupo) |>
  # Média móvel de três meses: a taxa de uma gerência só oscila muito mês a mês.
  mutate(taxa_mm3 = 100 * zoo_soma(vol) / zoo_soma(hc)) |>
  ungroup()
troca_lideranca <- respondentes |>
  filter(gerencia == gerencia_troca) |>
  group_by(depois = data_desligamento >= TROCA) |>
  summarise(n = n(), x = sum(motivo_principal == "Liderança e gestor"), .groups = "drop") |>
  mutate(pct = 100 * x / n, inf = wilson(x, n, "inf"), sup = wilson(x, n, "sup"))

## ---- etapa-8-jornada ----
# Escala 6x1 no turno da noite: participação de "jornada e escala" entre os
# motivos e taxa de saída voluntária, contra as outras combinações.
grupo_jornada <- function(turno, escala) {
  case_when(turno == "Noite" & escala == "6x1" ~ "Noite, 6x1", turno == "Noite" ~ "Noite, outras escalas",
            escala == "6x1" ~ "Dia, 6x1", TRUE ~ "Dia, outras escalas")
}
ordem_jornada <- c("Noite, 6x1", "Noite, outras escalas", "Dia, 6x1", "Dia, outras escalas")
jornada <- respondentes |>
  group_by(grupo = factor(grupo_jornada(turno, escala), ordem_jornada)) |>
  summarise(n = n(), x = sum(motivo_principal == "Jornada e escala"), .groups = "drop") |>
  mutate(pct = 100 * x / n, inf = wilson(x, n, "inf"), sup = wilson(x, n, "sup")) |>
  left_join(pessoa_mes |>
              group_by(grupo = factor(grupo_jornada(turno, escala), ordem_jornada)) |>
              summarise(exposicao = sum(peso), pessoas = n_distinct(id_colaborador), .groups = "drop") |>
              left_join(saidas |> filter(voluntaria) |>
                          count(grupo = factor(grupo_jornada(turno, escala), ordem_jornada), name = "vol"), "grupo") |>
              mutate(taxa_vol = 100 * vol / exposicao, taxa_inf = taxa_ic(vol, exposicao, "inf"),
                     taxa_sup = taxa_ic(vol, exposicao, "sup")),
            "grupo")

## ---- etapa-9-regressao ----
# Regressão logística da saída voluntária até 90 dias, entre os admitidos até
# 02/10/2025.
modelo_90 <- glm(vol_90 ~ relevel(factor(grupo), "Demais gerências") * factor(ano_admissao) + noite_6x1 +
                   relevel(factor(faixa_etaria), "35 a 44"),
                 family = binomial, data = coorte_90)
or_90 <- broom::tidy(modelo_90, exponentiate = TRUE, conf.int = TRUE, conf.method = "Wald") |>
  filter(term != "(Intercept)") |>
  select(termo = term, or = estimate, inf = conf.low, sup = conf.high, p = p.value)

# Confundimento: a faixa etária parece importar, mas deixa de ter efeito
# quando o tempo de casa entra no modelo. Unidade: pessoa-mês.
pm <- pessoa_mes |>
  filter(ativo_inicio == 1) |>
  left_join(saidas |> filter(voluntaria) |> transmute(id_colaborador, ano_mes, saiu = 1L),
            c("id_colaborador", "ano_mes")) |>
  mutate(saiu = coalesce(saiu, 0L), faixa_etaria = relevel(factor(faixa_etaria), "35 a 44"),
         tempo_casa = cut(tempo_casa_meses, c(-Inf, 2, 11, 35, Inf),
                          c("Até 3 meses", "3 a 11 meses", "1 a 3 anos", "Mais de 3 anos")))
idade_bruto <- glm(saiu ~ faixa_etaria, family = binomial, data = pm)
idade_ajustado <- glm(saiu ~ faixa_etaria + tempo_casa, family = binomial, data = pm)
or_idade <- bind_rows(
  broom::tidy(idade_bruto, exponentiate = TRUE, conf.int = TRUE, conf.method = "Wald") |> mutate(modelo = "Bruto"),
  broom::tidy(idade_ajustado, exponentiate = TRUE, conf.int = TRUE, conf.method = "Wald") |> mutate(modelo = "Ajustado")) |>
  filter(str_detect(term, "faixa_etaria")) |>
  transmute(modelo, faixa = sub("faixa_etaria", "", term), or = estimate, inf = conf.low, sup = conf.high, p = p.value)
teste_idade_ajustado <- anova(update(idade_ajustado, . ~ tempo_casa), idade_ajustado, test = "LRT")
idade_tempo <- pm |>
  count(faixa_etaria, tempo_casa) |>
  group_by(faixa_etaria) |>
  mutate(pct = 100 * n / sum(n)) |>
  ungroup()

## ---- etapa-10-prioridades ----
# Prioridades por gerência, em 2025. Alta: a taxa voluntária ou as saídas até
# 90 dias ficam acima da empresa mesmo no limite inferior do intervalo.
# Média: as duas acima da empresa na estimativa, ou um motivo (liderança e
# gestor, jornada e escala) acima da empresa no limite inferior do intervalo.
# Acompanhar: o resto.
ano_ref <- 2025
empresa_vol <- with(filter(anual, ano == ano_ref), taxa_vol)
empresa_90 <- with(filter(noventa_ano, ano_admissao == ano_ref), pct)
empresa_motivo <- function(m) 100 * mean(respondentes$motivo_principal[respondentes$ano == ano_ref] == m)
prior <- pessoa_mes |>
  filter(ano == ano_ref) |>
  group_by(gerencia, unidade) |>
  summarise(exposicao = sum(peso), .groups = "drop") |>
  mutate(hc_medio = exposicao / 12) |>
  left_join(saidas |> filter(ano == ano_ref) |>
              group_by(gerencia) |>
              summarise(vol = sum(voluntaria), saidas = n(), responderam = sum(respondeu == "Sim"),
                        nota_gestor = mean(nota_gestor, na.rm = TRUE), .groups = "drop"), "gerencia") |>
  left_join(respondentes |> filter(ano == ano_ref) |>
              group_by(gerencia) |>
              summarise(resp_vol = n(), lideranca = sum(motivo_principal == "Liderança e gestor"),
                        jornada = sum(motivo_principal == "Jornada e escala"), .groups = "drop"), "gerencia") |>
  left_join(noventa_gerencia |> filter(ano_admissao == ano_ref) |> mutate(gerencia = as.character(gerencia)) |>
              select(gerencia, admitidos, saidas_90 = saidas), "gerencia") |>
  mutate(across(c(vol, saidas, responderam, resp_vol, lideranca, jornada, admitidos, saidas_90), \(x) coalesce(x, 0L)),
         taxa_vol = 100 * vol / exposicao, taxa_inf = taxa_ic(vol, exposicao, "inf"),
         taxa_sup = taxa_ic(vol, exposicao, "sup"),
         pct_90 = 100 * saidas_90 / admitidos, pct_90_inf = wilson(saidas_90, admitidos, "inf"),
         pct_90_sup = wilson(saidas_90, admitidos, "sup"),
         resposta = 100 * responderam / saidas,
         pct_lideranca = 100 * lideranca / resp_vol, lid_inf = wilson(lideranca, resp_vol, "inf"),
         pct_jornada = 100 * jornada / resp_vol, jor_inf = wilson(jornada, resp_vol, "inf"),
         excesso = vol - exposicao * empresa_vol / 100,
         sinal_lideranca = resp_vol >= MINIMO & lid_inf > empresa_motivo("Liderança e gestor"),
         sinal_jornada = resp_vol >= MINIMO & jor_inf > empresa_motivo("Jornada e escala"),
         alta = taxa_inf > empresa_vol | pct_90_inf > empresa_90,
         media = !alta & ((taxa_vol > empresa_vol & pct_90 > empresa_90) | sinal_lideranca | sinal_jornada),
         prioridade = case_when(alta ~ "Alta", media ~ "Média", TRUE ~ "Acompanhar"),
         estimativa = !alta & taxa_vol > empresa_vol & pct_90 > empresa_90) |>
  # Destaques do cruzamento motivo × gerência (2024 e 2025) também viram sinal,
  # mesmo quando não mudam a prioridade.
  left_join(residuos |> filter(destaque, residuo > 0) |>
              group_by(gerencia) |>
              summarise(motivos_residuo = paste(motivo, collapse = "; "), .groups = "drop"), "gerencia") |>
  mutate(sinais = pmap_chr(list(taxa_inf > empresa_vol, pct_90_inf > empresa_90, estimativa, sinal_lideranca,
                                sinal_jornada, motivos_residuo),
                           \(a, b, e, l, j, r) {
                             s <- c(if (a) "Taxa voluntária", if (b) "Saídas até 90 dias",
                                    if (e) c("Taxa voluntária (na estimativa)", "Saídas até 90 dias (na estimativa)"),
                                    if (l) "Liderança e gestor", if (j) "Jornada e escala")
                             if (!is.na(r)) {
                               novos <- setdiff(strsplit(r, "; ")[[1]], s)
                               if (length(novos)) s <- c(s, paste(novos, "(cruzamento com a gerência)"))
                             }
                             paste(s, collapse = "; ")
                           })) |>
  arrange(factor(prioridade, c("Alta", "Média", "Acompanhar")), desc(excesso)) |>
  mutate(ordem = row_number())

# CSV para baixar: só agregados; contagens e percentuais de grupos com menos
# de 10 pessoas viram "<10".
# Mesmo formato do CSV da Auditoria: vírgula separa colunas e ponto separa decimais.
fmt <- function(x, d = 1) formatC(x, format = "f", digits = d)
mascara <- function(valor, n, d = 1) if_else(n < MINIMO, "<10", fmt(valor, d))
prioridades_csv <- prior |>
  transmute(ordem, gerencia, unidade, prioridade, sinais = na_if(sinais, ""),
            headcount_medio = fmt(hc_medio, 0),
            saidas_voluntarias = if_else(vol < MINIMO, "<10", as.character(vol)),
            taxa_voluntaria_mensal_pct = fmt(taxa_vol, 2),
            taxa_ic95_inf = fmt(taxa_inf, 2), taxa_ic95_sup = fmt(taxa_sup, 2),
            admitidos = if_else(admitidos < MINIMO, "<10", as.character(admitidos)),
            saidas_ate_90_dias_pct = mascara(pct_90, admitidos), saidas_90_ic95_inf = mascara(pct_90_inf, admitidos),
            saidas_90_ic95_sup = mascara(pct_90_sup, admitidos),
            taxa_resposta_pct = mascara(resposta, saidas),
            lideranca_gestor_pct = mascara(pct_lideranca, resp_vol),
            jornada_escala_pct = mascara(pct_jornada, resp_vol),
            nota_media_gestor = mascara(nota_gestor, responderam))
dir.create("resultados", showWarnings = FALSE)
write_csv(prioridades_csv, "resultados/prioridades_gerencias.csv", na = "")

## ---- gravar ----
# Nenhum grupo com menos de 10 pessoas nas visões.
stopifnot("todo grupo das visões tem pelo menos 10 pessoas" =
            min(c(noventa_gerencia$admitidos, resposta_unidade$saidas, jornada$n, troca_lideranca$n,
                  pareto_nota_baixa$total, salario_nota_baixa$n)) >= MINIMO)
res <- list(
  periodo = c("2024-01", "2025-12"), gerencias = ordem_gerencias, troca = TROCA, gerencia_troca = gerencia_troca,
  pessoas = n_distinct(pessoa_mes$id_colaborador), hc_medio = mean(mensal$hc_medio),
  lojas = sum(grepl("^L", unique(estrutura$unidade))), saidas_total = nrow(saidas),
  saidas_vol = sum(saidas$voluntaria), tipos = tipos,
  mensal = mensal, anual = anual, teste_anos = teste_anos,
  coorte = c(admitidos = nrow(coorte), admitidos_90 = nrow(coorte_90)), janela_90 = JANELA_90,
  noventa_ano = noventa_ano, noventa_gerencia = noventa_gerencia, subida_90 = subida_90, noventa_grupo = noventa_grupo,
  respondentes = nrow(respondentes), pareto_geral = pareto_geral, pareto_nota_baixa = pareto_nota_baixa,
  salario_nota_baixa = salario_nota_baixa, lideranca_qualquer = lideranca_qualquer,
  resposta_tipo = resposta_tipo, resposta_unidade = resposta_unidade, pareto_ponderado = pareto_ponderado,
  qui = list(estatistica = unname(qui_assint$statistic), gl = unname(qui_assint$parameter), p = qui$p.value,
             p_assint = qui_assint$p.value, esperado_menor_5 = mean(qui_assint$expected < 5)),
  residuos = residuos,
  incidencia = incidencia, incidencia_90 = incidencia_90,
  teste_gerencia = list(chi = teste_gerencia$Chisq[2], gl = teste_gerencia$Df[2], p = teste_gerencia$`Pr(>|Chi|)`[2]),
  hr_2025 = hr_2025,
  rr_troca = rr_troca, troca_taxas = troca_taxas, troca_mensal = troca_mensal, troca_lideranca = troca_lideranca,
  jornada = jornada, or_90 = or_90, or_idade = or_idade,
  idade_p_ajustado = teste_idade_ajustado$`Pr(>Chi)`[2], idade_tempo = idade_tempo,
  prioridades = prior, empresa_vol = empresa_vol, empresa_90 = empresa_90,
  modelos = list(n_90 = nrow(coorte_90), n_pm = nrow(pm)))
saveRDS(res, "resultados/desligamento.rds")
cat("Análise gravada: resultados/desligamento.rds e resultados/prioridades_gerencias.csv\n")
