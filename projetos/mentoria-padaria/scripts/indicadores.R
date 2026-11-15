# Caso Mentoria (Padaria Grão Dourado): os três indicadores e a decisão.
# Uso, na pasta do site: Rscript projetos/mentoria-padaria/scripts/indicadores.R
#
# Lê dados/padaria_organizada.csv e grava resultados/padaria.rds, que a página
# (PT, ES e EN) lê. Os mesmos números saem das fórmulas da planilha modelo
# (scripts/planilha_modelo.R), que é conferida contra este arquivo.
#
# 1. Taxa de sobra por fornada e produto: sobra ÷ produzido.
# 2. Margem real por produto: receita (vendido × preço) menos o custo de tudo
#    o que foi produzido (produzido × custo), ou seja, já descontando a sobra.
# 3. Participação de cada produto na margem total (soma das margens reais).
#    É margem, não lucro: não desconta aluguel, salários e energia. O campo
#    lucro_total do .rds guarda essa margem total.
#
# Decisão: cortar pela metade a fornada das 17h de pão francês e usar esse
# forno para uma fornada de pão de queijo. A economia sai como faixa, porque
# depende de quanto do pão de queijo novo vende (premissas abaixo).

suppressPackageStartupMessages({ library(dplyr); library(tidyr) })
args <- commandArgs(trailingOnly = FALSE)
caso <- normalizePath(file.path(dirname(sub("^--file=", "", args[grep("^--file=", args)])), ".."))
source(file.path(caso, "scripts", "rotulos.R"))

d <- read.csv(file.path(caso, "dados", "padaria_organizada.csv"), encoding = "UTF-8") |>
  mutate(data = as.Date(data), sobra = produzido - vendido,
         receita = vendido * preco_unitario, custo_total = produzido * custo_unitario,
         margem = receita - custo_total,
         # O que a dona via: preço menos custo só das unidades vendidas.
         margem_vendida = vendido * (preco_unitario - custo_unitario))
dias <- n_distinct(d$data)
meses <- dias / 30  # 84 dias = 2,8 meses de 30 dias

sobra <- d |>
  group_by(produto, fornada) |>
  summarise(produzido = sum(produzido), sobra = sum(sobra), .groups = "drop") |>
  mutate(taxa = 100 * sobra / produzido)

margem <- d |>
  group_by(produto) |>
  summarise(produzido = sum(produzido), vendido = sum(vendido), sobra = sum(sobra),
            receita = sum(receita), custo = sum(custo_total), margem = sum(margem),
            margem_aparente = sum(margem_vendida), .groups = "drop") |>
  mutate(participacao = 100 * margem / sum(margem),
         margem_unidade_vendida = margem / vendido) |>
  arrange(desc(margem))

## ---- decisão ----
f17 <- d |> filter(produto == "frances", fornada == "17h")
preco_fr <- f17$preco_unitario[1]; custo_fr <- f17$custo_unitario[1]
corte <- f17 |>
  mutate(novo = round(produzido / 2), perdido = pmax(0, vendido - novo),
         economia = (produzido - novo) * custo_fr - perdido * preco_fr)
# Premissas da fornada nova de pão de queijo às 17h: o forno que sobra
# comporta 80 unidades; o pão de queijo já vende tudo nas outras fornadas,
# mas à tarde a procura é menor, então a faixa vai de vender metade a vender
# 80% dessa fornada.
queijo <- d |> filter(produto == "queijo") |> slice(1)
lote_queijo <- 80
venda_queijo <- c(baixa = 0.5, alta = 0.8)
ganho_queijo <- lote_queijo * venda_queijo * queijo$preco_unitario - lote_queijo * queijo$custo_unitario
economia_dia <- mean(corte$economia)
por_mes <- (economia_dia + ganho_queijo) * 30
faixa <- c(baixa = floor(por_mes[["baixa"]] / 50) * 50, alta = ceiling(por_mes[["alta"]] / 50) * 50)

res <- list(
  dias = dias, inicio = min(d$data), fim = max(d$data), linhas = nrow(d),
  sobra = sobra, margem = margem,
  lucro_total = sum(margem$margem), lucro_mes = sum(margem$margem) / meses,
  receita_total = sum(margem$receita),
  fr17 = list(produzido_dia = mean(f17$produzido), vendido_dia = mean(f17$vendido),
              taxa = 100 * sum(f17$produzido - f17$vendido) / sum(f17$produzido),
              dias_falta = sum(corte$perdido > 0), perdido_dia = mean(corte$perdido),
              economia_dia = economia_dia),
  queijo = list(lote = lote_queijo, venda = venda_queijo, ganho_dia = ganho_queijo,
                taxa = 100 * sum(d$sobra[d$produto == "queijo"]) / sum(d$produzido[d$produto == "queijo"])),
  economia_mes = por_mes, faixa = faixa
)
dir.create(file.path(caso, "resultados"), showWarnings = FALSE)
saveRDS(res, file.path(caso, "resultados", "padaria.rds"))

cat(sprintf("Margem total em %d dias: R$ %.0f (R$ %.0f por mês)\n", dias, res$lucro_total, res$lucro_mes))
cat(sprintf("Sobra do pão francês às 17h: %.1f%%; pão de queijo: %.1f%%\n", res$fr17$taxa, res$queijo$taxa))
print(margem |> select(produto, margem, margem_aparente, participacao), n = 10)
cat(sprintf("Economia estimada: R$ %.0f a R$ %.0f por mês (faixa: R$ %d a R$ %d)\n",
            por_mes[["baixa"]], por_mes[["alta"]], faixa[["baixa"]], faixa[["alta"]]))
