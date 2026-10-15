# Análise do caso TCC. Roda uma vez e grava resultados/analise.rds, que as
# páginas em português, espanhol e inglês leem. Nada aqui depende de idioma:
# os textos dos gráficos e das tabelas ficam em scripts/rotulos.R.
#
# Uso, a partir da pasta do site:
#   Rscript projetos/caso-tcc-rotatividade/scripts/analise.R
# O render.ps1 faz isso sozinho quando os dados ou este script mudam.
#
# As marcas "## ---- nome ----" dividem o script em trechos; cada página
# mostra o trecho certo no "Ver o código R" (knitr::read_chunk).

arquivo <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
setwd(normalizePath(file.path(dirname(arquivo), ".."), winslash = "/"))

## ---- pacotes ----
suppressPackageStartupMessages({
  library(tidyverse)
  library(psych)
  library(rstatix)
  library(sandwich)
  library(lmtest)
  library(car)
})

## ---- leitura ----
bruto <- read_csv("dados/respostas_brutas.csv", show_col_types = FALSE)
dic <- read_csv("dados/dicionario.csv", show_col_types = FALSE)

# O Forms exporta o texto inteiro da pergunta como nome da coluna;
# o dicionário troca cada um por um código curto (LID1, REC2...).
names(bruto) <- dic$codigo[match(names(bruto), dic$coluna)]
itens <- filter(dic, construto != "Perfil") |>
  mutate(enunciado = str_match(coluna, "\\[(.*)\\]$")[, 2])
cod <- itens$codigo
blocos <- split(cod, substr(cod, 1, 3))

brancos <- function(df) rowSums(is.na(select(df, all_of(cod))))
iguais <- function(df) apply(select(df, all_of(cod)), 1, sd, na.rm = TRUE) == 0

passo1 <- filter(bruto, aceite == "Sim")
passo2 <- filter(passo1, brancos(passo1) <= 4)      # até 20% dos 20 itens em branco
passo3 <- filter(passo2, !iguais(passo2))           # mesma resposta nos 20 itens

excluidas <- c(sem_aceite = nrow(bruto) - nrow(passo1), brancos = nrow(passo1) - nrow(passo2),
               iguais = nrow(passo2) - nrow(passo3))
celulas_brancas <- sum(is.na(select(passo3, all_of(cod))))

## ---- faixa-etaria ----
padronizar_faixa <- function(x) {
  case_when(str_detect(x, "18") ~ "18 a 24",
            str_detect(x, "25") ~ "25 a 34",
            str_detect(x, "35") ~ "35 a 44",
            str_detect(x, "45") ~ "45 ou mais")
}
grafias <- passo3 |>
  mutate(padronizada = padronizar_faixa(faixa_etaria)) |>
  group_by(padronizada) |>
  summarise(escritas = list(sort(unique(faixa_etaria))), pessoas = n())

# Base final: faixa padronizada, item invertido recodificado (1 vira 5, 2 vira 4...).
d <- passo3 |>
  mutate(faixa_etaria = padronizar_faixa(faixa_etaria),
         LID3 = 6L - LID3,
         turno_grupo = if_else(turno == "Noite", "Noturno", "Diurno"),
         tempo_casa = factor(tempo_casa, c("Até 1 ano", "De 1 a 3 anos", "De 3 a 5 anos", "Mais de 5 anos")))
stopifnot(!anyNA(d$faixa_etaria))

## ---- confiabilidade ----
confiab <- function(cols) {
  x <- select(d, all_of(cols))
  c(alfa = suppressWarnings(psych::alpha(x)$total$raw_alpha),
    omega = suppressMessages(suppressWarnings(psych::omega(x, nfactors = 1, plot = FALSE)$omega.tot)))
}
rem_sem4 <- c("REM1", "REM2", "REM3")
conf <- bind_rows(
  lapply(names(blocos), function(b) c(bloco = b, itens = length(blocos[[b]]), confiab(blocos[[b]]))),
  c(bloco = "REM_sem4", itens = 3, confiab(rem_sem4))
) |>
  mutate(across(c(itens, alfa, omega), as.numeric)) |>
  arrange(match(bloco, c("LID", "REC", "REM", "REM_sem4", "EQU", "INT")))

# Correlação de cada item de Remuneração com o total dos outros três.
r_rem <- psych::alpha(select(d, all_of(blocos$REM)))$item.stats$r.drop
names(r_rem) <- blocos$REM

## ---- fatorial ----
x_itens <- select(d, all_of(cod))
pc <- suppressWarnings(polychoric(x_itens)$rho)
kmo <- KMO(pc)$MSA
bartlett <- cortest.bartlett(pc, n = nrow(d))
fe <- suppressWarnings(fa(x_itens, nfactors = 5, cor = "poly", rotate = "oblimin", fm = "minres"))

cargas <- unclass(fe$loadings)
# Dá a cada fator o código do bloco cujos itens carregam mais nele.
dominante <- sapply(seq_len(ncol(cargas)), function(f) {
  names(which.max(tapply(abs(cargas[, f]), substr(rownames(cargas), 1, 3), mean)))
})
colnames(cargas) <- dominante
cargas <- cargas[, c("LID", "REC", "REM", "EQU", "INT")]
carga_rem4 <- max(abs(cargas["REM4", ]))

## ---- escores ----
escore <- function(cols) {
  m <- as.matrix(select(d, all_of(cols)))
  if_else(rowSums(is.na(m)) <= 1, rowMeans(m, na.rm = TRUE), NA_real_)
}
d <- d |>
  mutate(LID = escore(blocos$LID), REC = escore(blocos$REC), REM = escore(rem_sem4),
         EQU = escore(blocos$EQU), INT = escore(blocos$INT))

## ---- comparacoes ----
mw <- wilcox_test(d, INT ~ turno_grupo)
mw_r <- wilcox_effsize(d, INT ~ turno_grupo)
kw <- kruskal_test(d, INT ~ tempo_casa)
kw_e <- kruskal_effsize(d, INT ~ tempo_casa)
dunn <- dunn_test(d, INT ~ tempo_casa, p.adjust.method = "holm")
dunn_novato <- filter(dunn, group1 == "Até 1 ano", p.adj < 0.05)

resumo_grupos <- function(var) {
  d |> group_by(grupo = as.character(.data[[var]])) |>
    summarise(n = n(), mediana = median(INT), q1 = quantile(INT, .25), q3 = quantile(INT, .75))
}
grupos <- bind_rows(resumo_grupos("turno_grupo"), resumo_grupos("tempo_casa"))

## ---- correlacoes ----
ct <- corr.test(select(d, LID, REC, REM, EQU, INT), method = "spearman", adjust = "none")
rho <- ct$r
p_int <- ct$p["INT", c("LID", "REC", "REM", "EQU")]

## ---- regressao ----
dm <- d |>
  transmute(INT = INT, LID = LID, REC = REC, REM = REM, EQU = EQU,
            noturno = as.numeric(turno == "Noite"),
            novato = as.numeric(tempo_casa == "Até 1 ano"),
            feminino = as.numeric(sexo == "Feminino")) |>
  drop_na() |>
  mutate(across(c(INT, LID, REC, REM, EQU), \(v) as.numeric(scale(v))))
modelo <- lm(INT ~ LID + REC + REM + EQU + noturno + novato + feminino, data = dm)

# Pressupostos
vifs <- vif(modelo)
bp <- bptest(modelo)
sw <- shapiro.test(residuals(modelo))
cook_max <- max(cooks.distance(modelo))

# Erros-padrão robustos (HC3): protegem os testes se a variância dos resíduos não for constante.
v_hc3 <- vcovHC(modelo, type = "HC3")
rob <- coeftest(modelo, vcov. = v_hc3)
ic <- coefci(modelo, vcov. = v_hc3)
resultado <- tibble(termo = rownames(rob), beta = rob[, 1], ep = rob[, 2], p = rob[, 4],
                    li = ic[, 1], ls = ic[, 2]) |>
  filter(termo != "(Intercept)")
ajuste <- summary(modelo)

## ---- igualdade ----
# H3 diz que o efeito da remuneração é menor: testa se os coeficientes são iguais.
igual_lid <- linearHypothesis(modelo, "REM = LID", vcov. = v_hc3)
igual_rec <- linearHypothesis(modelo, "REM = REC", vcov. = v_hc3)
teste <- function(h) c(F = h$F[2], gl1 = h$Df[2], gl2 = h$Res.Df[2], p = h$`Pr(>F)`[2])
menor_confirmado <- igual_lid$`Pr(>F)`[2] < 0.05 && igual_rec$`Pr(>F)`[2] < 0.05
# O texto das páginas foi escrito para o caso em que a diferença não se confirma.
stopifnot(!menor_confirmado)

# H3 tem duas partes: reduz (testada pelo β) e com efeito menor (testada acima).
hipoteses <- tibble(termo = c("LID", "REC", "REM", "EQU")) |>
  left_join(resultado, by = "termo") |>
  mutate(decisao = case_when(!(beta < 0 & p < 0.05) ~ "nao",
                             termo == "REM" & !menor_confirmado ~ "parcial",
                             TRUE ~ "sim"))

## ---- gravar ----
dir.create("resultados", showWarnings = FALSE)
saveRDS(list(
  n_bruto = nrow(bruto), excluidas = excluidas, n_validas = nrow(passo3),
  celulas_brancas = celulas_brancas, grafias = grafias,
  itens = select(itens, codigo, invertido, enunciado),
  respostas = select(passo3, all_of(cod)), d = d,
  conf = conf, r_rem = r_rem,
  kmo = kmo, bartlett = bartlett[c("chisq", "df", "p.value")], cargas = cargas, carga_rem4 = carga_rem4,
  mw = c(p = mw$p, r = unname(mw_r$effsize)),
  kw = c(H = unname(kw$statistic), gl = unname(kw$df), p = kw$p, eps2 = unname(kw_e$effsize)),
  dunn_novato = dunn_novato$group2, grupos = grupos,
  rho = rho, p_int = p_int,
  n_modelo = nrow(dm), vif_max = max(vifs), bp_p = bp$p.value, sw_p = sw$p.value, cook_max = cook_max,
  resultado = resultado, r2 = ajuste$r.squared, r2a = ajuste$adj.r.squared,
  f = c(ajuste$fstatistic, p = pf(ajuste$fstatistic[["value"]], ajuste$fstatistic[["numdf"]],
                                  ajuste$fstatistic[["dendf"]], lower.tail = FALSE)),
  igual_lid = teste(igual_lid), igual_rec = teste(igual_rec), hipoteses = hipoteses
), "resultados/analise.rds")
cat("Análise gravada em resultados/analise.rds\n")
