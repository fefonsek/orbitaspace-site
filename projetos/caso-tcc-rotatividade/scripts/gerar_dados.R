# Gera os dados fictícios do caso "Liderança, reconhecimento e intenção de
# rotatividade em funcionários de supermercados do Centro-Oeste mineiro".
#
# Nada aqui vem de pessoas reais. As respostas são simuladas a partir de um
# modelo com efeitos programados (veja "Padrões programados") e depois
# recebem problemas comuns em questionários online (veja "Problemas plantados").
#
# Uso, a partir da pasta do site:
#   Rscript projetos/caso-tcc-rotatividade/scripts/gerar_dados.R
#
# Saída: dados/respostas_brutas.csv (como uma exportação do Google Forms) e
# dados/dicionario.csv. No fim, o script confere se os padrões aparecem nos
# dados limpos e para com erro se algum não aparecer, em vez de gravar dados
# que contradizem o texto da página.

suppressPackageStartupMessages({
  library(MASS)      # mvrnorm
  library(dplyr)
  library(readr)
})

SEMENTE <- 11
set.seed(SEMENTE)

arquivo <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
PASTA <- normalizePath(file.path(dirname(arquivo), ".."), winslash = "/")
DADOS <- file.path(PASTA, "dados")
dir.create(DADOS, showWarnings = FALSE)

# Dicionário --------------------------------------------------------------

dicionario <- tribble(
  ~codigo, ~construto, ~invertido, ~enunciado,
  "LID1", "Liderança", "não", "Meu supervisor me trata com respeito.",
  "LID2", "Liderança", "não", "Meu supervisor explica com clareza o que espera de mim.",
  "LID3", "Liderança", "sim", "Meu supervisor raramente me dá retorno sobre o meu trabalho.",
  "LID4", "Liderança", "não", "Posso contar com meu supervisor quando tenho um problema no trabalho.",
  "LID5", "Liderança", "não", "Meu supervisor distribui as tarefas de forma justa.",
  "REC1", "Reconhecimento", "não", "Quando faço um bom trabalho, alguém percebe.",
  "REC2", "Reconhecimento", "não", "Recebo elogios pelo meu trabalho.",
  "REC3", "Reconhecimento", "não", "Sinto que meu esforço é valorizado pela empresa.",
  "REC4", "Reconhecimento", "não", "A empresa reconhece quem se dedica mais.",
  "REM1", "Remuneração percebida", "não", "Meu salário é justo pelo trabalho que faço.",
  "REM2", "Remuneração percebida", "não", "Meu salário é compatível com o de outros supermercados da região.",
  "REM3", "Remuneração percebida", "não", "Estou satisfeito com a minha remuneração.",
  "REM4", "Remuneração percebida", "não", "Recebo o vale-transporte em dia.",
  "EQU1", "Equilíbrio trabalho e vida", "não", "Meu horário me permite cuidar da minha vida pessoal.",
  "EQU2", "Equilíbrio trabalho e vida", "não", "Consigo planejar minhas folgas com antecedência.",
  "EQU3", "Equilíbrio trabalho e vida", "não", "O trabalho raramente atrapalha meus compromissos familiares.",
  "EQU4", "Equilíbrio trabalho e vida", "não", "Saio do trabalho no horário previsto.",
  "INT1", "Intenção de rotatividade", "não", "Penso com frequência em sair desta empresa.",
  "INT2", "Intenção de rotatividade", "não", "Pretendo procurar outro emprego nos próximos 12 meses.",
  "INT3", "Intenção de rotatividade", "não", "Se surgir uma oferta parecida em outro lugar, eu saio."
) |>
  # Cabeçalho como o Google Forms exporta uma grade de escala.
  mutate(coluna = paste0("Avalie as frases de 1 (discordo totalmente) a 5 (concordo totalmente) [",
                         enunciado, "]"))

perfil <- tribble(
  ~codigo, ~coluna,
  "data_hora", "Carimbo de data/hora",
  "aceite", "Você leu o termo de consentimento e aceita participar da pesquisa?",
  "sexo", "Sexo",
  "faixa_etaria", "Qual é a sua faixa etária?",
  "escolaridade", "Escolaridade",
  "funcao", "Função",
  "turno", "Turno de trabalho",
  "tempo_casa", "Há quanto tempo trabalha nesta empresa?"
)

# Perfil --------------------------------------------------------------------

n <- 230
sorteio <- function(valores, probs) sample(valores, n, replace = TRUE, prob = probs)

faixa <- sorteio(c("18 a 24", "25 a 34", "35 a 44", "45 ou mais"), c(.30, .34, .21, .15))
# Campo de texto livre: cada pessoa escreveu a faixa de um jeito.
grafias <- list(
  "18 a 24" = c("18 a 24", "18-24", "18 a 24 anos", "de 18 a 24", "18 - 24 anos"),
  "25 a 34" = c("25 a 34", "25-34", "25 a 34 anos", "De 25 a 34", "25 á 34"),
  "35 a 44" = c("35 a 44", "35-44", "35 a 44 anos", "35 A 44"),
  "45 ou mais" = c("45 ou mais", "45+", "Mais de 45", "45 anos ou mais")
)
faixa_escrita <- vapply(faixa, function(f) sample(grafias[[f]], 1), "")

dados <- tibble(
  sexo = sorteio(c("Feminino", "Masculino", "Prefiro não informar"), c(.56, .42, .02)),
  faixa_etaria = faixa_escrita,
  escolaridade = sorteio(c("Ensino fundamental", "Ensino médio", "Superior incompleto", "Superior completo"),
                         c(.12, .62, .16, .10)),
  funcao = sorteio(c("Operador(a) de caixa", "Repositor(a)", "Açougue e padaria", "Atendimento", "Depósito"),
                   c(.30, .25, .15, .15, .15)),
  turno = sorteio(c("Manhã", "Tarde", "Noite"), c(.40, .35, .25)),
  tempo_casa = sorteio(c("Até 1 ano", "De 1 a 3 anos", "De 3 a 5 anos", "Mais de 5 anos"),
                       c(.31, .33, .19, .17))
)

# Padrões programados ---------------------------------------------------------
# Quatro construtos latentes correlacionados. Equilíbrio se correlaciona com
# Liderança e Reconhecimento, mas não entra na equação da intenção: aparece
# associado na correlação simples e some quando os outros entram no modelo.

correlacoes <- matrix(c(
  1.00, 0.55, 0.30, 0.35,
  0.55, 1.00, 0.40, 0.35,
  0.30, 0.40, 1.00, 0.25,
  0.35, 0.35, 0.25, 1.00), 4)
lat <- mvrnorm(n, rep(0, 4), correlacoes)
colnames(lat) <- c("LID", "REC", "REM", "EQU")

noturno <- as.numeric(dados$turno == "Noite")
novato <- as.numeric(dados$tempo_casa == "Até 1 ano")
intencao <- -0.30 * lat[, "LID"] - 0.27 * lat[, "REC"] - 0.24 * lat[, "REM"] + 0 * lat[, "EQU"] +
  0.55 * noturno + 0.50 * novato + rnorm(n, 0, 0.72)
intencao <- as.numeric(scale(intencao))

# Item = carga x fator + ruído, cortado em 5 pontos. O deslocamento move a
# média do item (remuneração tende a ser mal avaliada, liderança um pouco melhor).
likert <- function(x) findInterval(x, c(-1.5, -0.6, 0.25, 1.1)) + 1L
item <- function(fator, carga, desloc = 0) likert(carga * fator + sqrt(1 - carga^2) * rnorm(n) + desloc)

itens <- tibble(
  LID1 = item(lat[, "LID"], .80, .2), LID2 = item(lat[, "LID"], .78, .1),
  LID3 = 6L - item(lat[, "LID"], .70, .1),   # invertido: quem avalia bem o líder discorda
  LID4 = item(lat[, "LID"], .80), LID5 = item(lat[, "LID"], .75, .2),
  REC1 = item(lat[, "REC"], .80), REC2 = item(lat[, "REC"], .78, -.1),
  REC3 = item(lat[, "REC"], .75), REC4 = item(lat[, "REC"], .72, -.2),
  REM1 = item(lat[, "REM"], .84, -.4), REM2 = item(lat[, "REM"], .84, -.5),
  REM3 = item(lat[, "REM"], .80, -.3),
  REM4 = item(lat[, "REM"], .22, .3),        # item fraco: mede outra coisa (pontualidade de um benefício)
  EQU1 = item(lat[, "EQU"], .75), EQU2 = item(lat[, "EQU"], .78, -.1),
  EQU3 = item(lat[, "EQU"], .72), EQU4 = item(lat[, "EQU"], .70, .1),
  INT1 = item(intencao, .85, -.2), INT2 = item(intencao, .85, -.3), INT3 = item(intencao, .80, -.1)
)
dados <- bind_cols(aceite = "Sim", dados, itens)
cod_itens <- dicionario$codigo

# Problemas plantados ---------------------------------------------------------

linhas <- sample(n)
sem_aceite <- linhas[1:6]
muito_branco <- linhas[7:13]
iguais <- linhas[14:18]
validas <- linhas[19:n]

# 6 sem aceite: o formulário encerra e o resto fica vazio.
dados$aceite[sem_aceite] <- "Não"
dados[sem_aceite, c(perfil$codigo[3:8], cod_itens)] <- NA

# 7 com mais de 20% dos itens em branco (5 a 9 dos 20).
for (i in muito_branco) dados[i, sample(cod_itens, sample(5:9, 1))] <- NA

# 5 com todas as respostas iguais.
for (i in seq_along(iguais)) dados[iguais[i], cod_itens] <- c(3L, 5L, 3L, 4L, 5L)[i]

# Brancos espalhados nas válidas: no máximo 1 por construto, salvo 2 pessoas
# com 2 brancos em Equilíbrio (para a regra de cálculo do escore aparecer).
construtos <- split(cod_itens, substr(cod_itens, 1, 3))
pares <- expand.grid(linha = validas, construto = names(construtos), stringsAsFactors = FALSE)
pares <- pares[sample(nrow(pares), 83), ]
pares <- pares |> group_by(linha) |> slice_head(n = 3) |> ungroup()
for (k in seq_len(nrow(pares))) {
  dados[pares$linha[k], sample(construtos[[pares$construto[k]]], 1)] <- NA
}
dois_em_equ <- setdiff(validas, pares$linha)[1:2]
for (i in dois_em_equ) dados[i, sample(construtos$EQU, 2)] <- NA

# Data e hora do envio, em agosto de 2026, e ordem cronológica.
inicio <- as.POSIXct("2026-08-03 08:00:00", tz = "America/Sao_Paulo")
dados$data_hora <- inicio + sort(runif(n, 0, 25 * 24 * 3600))[order(sample(n))]
dados <- dados |> arrange(data_hora) |>
  mutate(data_hora = format(data_hora, "%d/%m/%Y %H:%M:%S"))

# Gravação ---------------------------------------------------------------------

bruto <- dados[, c(perfil$codigo, cod_itens)]
names(bruto) <- c(perfil$coluna, dicionario$coluna)
write_excel_csv(bruto, file.path(DADOS, "respostas_brutas.csv"), na = "")
write_excel_csv(bind_rows(perfil |> mutate(construto = "Perfil"),
                          dicionario |> select(codigo, coluna, construto, invertido)),
                file.path(DADOS, "dicionario.csv"), na = "")

# Conferência ------------------------------------------------------------------
# Refaz, de forma resumida, a limpeza e as análises da página e para com erro
# se algum padrão programado não aparecer com esta semente.

suppressPackageStartupMessages({ library(psych); library(sandwich); library(lmtest) })

d <- dados |>
  filter(aceite == "Sim") |>
  filter(rowSums(is.na(across(all_of(cod_itens)))) <= 4) |>
  filter(apply(across(all_of(cod_itens)), 1, sd, na.rm = TRUE) > 0) |>
  mutate(LID3 = 6L - LID3)

escore <- function(cols) {
  m <- as.matrix(d[, cols])
  ifelse(rowSums(is.na(m)) <= 1, rowMeans(m, na.rm = TRUE), NA)
}
s <- tibble(LID = escore(construtos$LID), REC = escore(construtos$REC),
            REM = escore(c("REM1", "REM2", "REM3")), EQU = escore(construtos$EQU),
            INT = escore(construtos$INT),
            noturno = as.numeric(d$turno == "Noite"), novato = as.numeric(d$tempo_casa == "Até 1 ano"),
            feminino = as.numeric(d$sexo == "Feminino"), tempo = d$tempo_casa)

alfa <- function(cols) suppressWarnings(psych::alpha(d[, cols])$total$raw_alpha)
alfa_rem4 <- alfa(construtos$REM)
alfa_sem4 <- alfa(c("REM1", "REM2", "REM3"))

modelo <- lm(scale(INT) ~ scale(LID) + scale(REC) + scale(REM) + scale(EQU) + noturno + novato + feminino, s)
rob <- coeftest(modelo, vcov = vcovHC(modelo, type = "HC3"))
b <- rob[, 1]; p <- rob[, 4]

fe <- suppressWarnings(suppressMessages(
  psych::fa(d[, cod_itens], nfactors = 5, cor = "poly", rotate = "oblimin", fm = "minres")))
carga_rem4 <- max(abs(unclass(fe$loadings)["REM4", ]))

rho_equ <- cor.test(s$EQU, s$INT, method = "spearman", exact = FALSE)
mw <- wilcox.test(INT ~ noturno, s)
kw <- kruskal.test(INT ~ factor(tempo), s)
medianas <- tapply(s$INT, s$tempo, median, na.rm = TRUE)

cat(sprintf("Semente %d: %d válidas; N da regressão %d\n", SEMENTE, nrow(d), sum(complete.cases(s))))
cat(sprintf("Alfa Remuneração: %.2f com REM4, %.2f sem; carga máxima de REM4 na fatorial: %.2f\n",
            alfa_rem4, alfa_sem4, carga_rem4))
print(round(cbind(beta = b, p = p), 3))
cat(sprintf("Spearman EQU x INT: %.2f (p = %.3g)\n", rho_equ$estimate, rho_equ$p.value))
cat(sprintf("Mann-Whitney turno: p = %.3g; Kruskal-Wallis tempo de casa: p = %.3g\n", mw$p.value, kw$p.value))

stopifnot(
  "212 respostas válidas" = nrow(d) == 212,
  "REM4 derruba o alfa" = alfa_sem4 - alfa_rem4 >= 0.06,
  "REM4 carrega abaixo de 0,30" = carga_rem4 < 0.30,
  "H1: liderança reduz a intenção" = b[2] < 0 && p[2] < 0.01,
  "H2: reconhecimento reduz a intenção" = b[3] < 0 && p[3] < 0.01,
  "H3: remuneração reduz, com efeito menor" = b[4] < 0 && p[4] < 0.05 && abs(b[4]) < min(abs(b[2:3])),
  "H4: equilíbrio sem efeito ajustado" = p[5] > 0.30,
  "Equilíbrio associado na correlação simples" = rho_equ$estimate < 0 && rho_equ$p.value < 0.05,
  "Noturno com intenção maior" = mw$p.value < 0.01 && b[6] > 0,
  "Até 1 ano com intenção maior" = kw$p.value < 0.05 && names(which.max(medianas)) == "Até 1 ano"
)
cat("Dados gravados em", DADOS, "\n")
