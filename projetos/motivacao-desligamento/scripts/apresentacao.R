# Caso Motivação de desligamento: gráficos, tabelas e capa, em qualquer das
# línguas. Não há cálculo novo aqui; tudo vem de resultados/desligamento.rds
# (scripts/analise.R). A página (index.qmd) e o relatório em PDF
# (relatorio/relatorio.qmd) usam as mesmas funções.
# Azul só no que o texto destaca; o resto em cinza. Nenhuma cor quente.

cor <- c(profundo = "#1a1a2e", azul = "#3473C0", azul_suave = "#7a90c4", azul_claro = "#9dbde8",
         cinza = "#8b8fa3", cinza_escuro = "#4a4a63", cinza_claro = "#d5d7e0", grade = "#e4e6ef",
         lavanda = "#cacfee", fundo_faixa = "#eceef3")

## ---- leitura ----
ler_desligamento <- function(caso = ".", idioma = "pt") {
  res <- readRDS(file.path(caso, "resultados/desligamento.rds"))
  res$caso <- caso
  res$tx <- rotulos(idioma)
  res
}

# Valores que o texto corrido cita (página e PDF), postos no ambiente de quem
# chama junto com os formatos da língua. Também confere as premissas do texto:
# se uma delas deixar de valer, o render para.
preparar_texto <- function(res, envir = parent.frame()) {
  tx <- res$tx
  an <- res$anual
  pg <- res$pareto_geral
  pn <- res$pareto_nota_baixa
  motivo <- \(tab, m, col = "pct") tab[[col]][tab$motivo == m]
  rt <- res$resposta_tipo
  ru <- res$resposta_unidade
  ng <- res$noventa_grupo
  g90 <- \(g, a, col = "pct") ng[[col]][ng$grupo == g & ng$ano_admissao == a]
  tt <- res$troca_taxas
  taxa_troca <- \(g, depois, col = "taxa") tt[[col]][tt$grupo == g & tt$depois == depois]
  tl <- res$troca_lideranca
  jo <- res$jornada
  outros_jornada <- jo |> filter(grupo != "Noite, 6x1") |> summarise(n = sum(n), x = sum(x)) |>
    mutate(pct = 100 * x / n)
  oi <- res$or_idade |> filter(faixa == "18 a 24")
  pr <- res$prioridades
  pond <- res$pareto_ponderado
  v <- list(
    an = an, pg = pg, pn = pn, motivo = motivo, rt = rt, ru = ru, g90 = g90, taxa_troca = taxa_troca, tl = tl,
    jo = jo, outros_jornada = outros_jornada, oi = oi, pr = pr,
    resp_vol = rt$pct[rt$voluntaria], resp_inv = rt$pct[!rt$voluntaria],
    unidade_baixa = as.character(ru$unidade[which.min(ru$pct)]), resp_baixa = min(ru$pct),
    pond_max = max(abs(pond$diferenca)),
    alta = pr$gerencia[pr$prioridade == "Alta"], media = pr$gerencia[pr$prioridade == "Média"],
    lid_qualquer = res$lideranca_qualquer, sal_nb = res$salario_nota_baixa,
    hr = res$hr_2025, rr = res$rr_troca, inc90 = res$incidencia_90,
    destaques = res$residuos |> filter(destaque) |> arrange(desc(abs(residuo)))
  )
  # Gerências com sinal que, pelos critérios de 2025, continuam em "Acompanhar":
  # uma frase para cada, dizendo por quê.
  acomp <- pr |> filter(prioridade == "Acompanhar", sinais != "")
  v$frase_acompanhar <- paste(vapply(seq_len(nrow(acomp)), function(i) {
    a <- acomp[i, ]
    motivo_r <- sub(" \\(.*", "", strsplit(a$sinais, "; ")[[1]][1])
    tx$frase_acompanhar(a$gerencia, traduzir(motivo_r, tx$motivos), tx$pct(a$taxa_vol, 2), tx$pct(res$empresa_vol, 2),
                        a$taxa_vol > res$empresa_vol, tx$pct(a$pct_90, 0), tx$pct(res$empresa_90, 0),
                        a$pct_90 > res$empresa_90)
  }, ""), collapse = " ")
  stopifnot(
    "salário e benefícios é o motivo mais citado no geral" = pg$motivo[1] == "Salário e benefícios",
    "liderança e gestor lidera com nota baixa ao gestor" = pn$motivo[1] == "Liderança e gestor",
    "a taxa total não muda de 2024 para 2025" = res$teste_anos$p.value > 0.05,
    "CD Expedição e L3 Operações têm prioridade alta" = all(c("CD Expedição", "L3 Operações") %in% v$alta),
    "a idade perde o efeito com o tempo de casa" = oi$inf[2] < 1 & oi$sup[2] > 1,
    "antes da troca, a L5 tem menos de 10 respostas com liderança" = tl$x[!tl$depois] < 10
  )
  list2env(c(v, tx[c("num", "pct", "ic", "mes_ano")]), envir = envir)
  invisible(v)
}

tema <- function(tam) {
  theme_minimal(base_family = "Montserrat") +
    theme(text = element_text(colour = cor[["profundo"]]),
          axis.text = element_text(colour = cor[["cinza_escuro"]], size = tam),
          panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(colour = cor[["grade"]], linewidth = 0.4),
          strip.text = element_text(family = "Montserrat", face = "bold", size = tam + 0.4, hjust = 0,
                                    colour = cor[["profundo"]]),
          plot.background = element_blank(), panel.background = element_blank())
}
tamanhos <- function(celular) if (celular) c(eixo = 11, rotulo = 11.5, nota = 10.5) else c(eixo = 9.6, rotulo = 10, nota = 9.4)
mes_data <- function(m) as.Date(paste0(m, "-01"))

## ---- grafico-mensal ----
# Taxa de desligamento mês a mês, total e voluntária. O total fica no mesmo
# nível nos dois anos; a voluntária sobe um pouco.
grafico_mensal <- function(res, celular = FALSE) {
  tx <- res$tx
  tam <- tamanhos(celular)
  d <- res$mensal |>
    transmute(data = mes_data(ano_mes), total = taxa, voluntaria = taxa_vol) |>
    pivot_longer(-data, names_to = "serie", values_to = "taxa") |>
    mutate(rotulo = if_else(serie == "total", tx$g_total, tx$g_voluntaria))
  ponta <- d |> filter(data == max(data))
  ggplot(d, aes(data, taxa, colour = serie)) +
    geom_vline(xintercept = mes_data("2025-01"), colour = cor[["cinza_claro"]], linewidth = 0.5) +
    geom_line(linewidth = 1.05) +
    geom_point(size = 1.5) +
    geom_text(data = ponta, aes(label = rotulo), hjust = 0, nudge_x = 12, size = tam[["rotulo"]] / .pt,
              family = "Montserrat", fontface = "bold") +
    scale_colour_manual(values = c(total = cor[["cinza_escuro"]], voluntaria = cor[["azul"]]), guide = "none") +
    scale_x_date(breaks = mes_data(c("2024-01", "2024-07", "2025-01", "2025-07")),
                 labels = \(x) paste(tx$meses_abrev[as.integer(format(x, "%m"))], format(x, "%Y")),
                 expand = expansion(mult = c(0.02, if (celular) 0.3 else 0.13))) +
    scale_y_continuous(labels = \(x) tx$pct(x, 1), limits = c(0, NA), expand = expansion(mult = c(0, 0.08))) +
    coord_cartesian(clip = "off") +
    labs(x = NULL, y = NULL) +
    tema(tam[["eixo"]])
}

## ---- grafico-pareto ----
# O motivo declarado em dois retratos: todas as respostas e só quem deu nota
# 1 ou 2 ao gestor. A ordem é a do geral; liderança e gestor em azul.
grafico_pareto <- function(res, celular = FALSE) {
  tx <- res$tx
  tam <- tamanhos(celular)
  ordem <- res$pareto_geral$motivo
  d <- bind_rows(res$pareto_geral |> mutate(painel = tx$g_todas, n_painel = total),
                 res$pareto_nota_baixa |> mutate(painel = tx$g_nota_baixa, n_painel = total)) |>
    mutate(painel = factor(paste0(painel, " (", tx$num(n_painel), ")"),
                           unique(paste0(painel, " (", tx$num(n_painel), ")"))),
           destaque = motivo == "Liderança e gestor",
           motivo = factor(traduzir(motivo, tx$motivos), rev(traduzir(ordem, tx$motivos))))
  if (celular) d$motivo <- factor(str_wrap(d$motivo, 16), str_wrap(levels(d$motivo), 16))
  ggplot(d, aes(pct, motivo, fill = destaque)) +
    geom_col(width = 0.66) +
    geom_errorbar(aes(xmin = inf, xmax = sup), orientation = "y", width = 0, colour = cor[["cinza"]], linewidth = 0.35) +
    geom_text(aes(x = sup, label = tx$pct(pct, 0)), hjust = -0.2, size = tam[["rotulo"]] / .pt,
              family = "Montserrat", colour = cor[["profundo"]]) +
    facet_wrap(~painel, ncol = if (celular) 1 else 2) +
    scale_fill_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["cinza_claro"]]), guide = "none") +
    scale_x_continuous(labels = NULL, expand = expansion(mult = c(0, 0.18))) +
    labs(x = NULL, y = NULL) +
    tema(tam[["eixo"]]) +
    theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = cor[["profundo"]], size = tam[["eixo"]]),
          panel.spacing.x = unit(1.6, "lines"), panel.spacing.y = unit(1, "lines"))
}

## ---- grafico-resposta ----
# Taxa de resposta da entrevista por unidade, com o intervalo de 95%. A
# unidade com a menor taxa em azul.
grafico_resposta <- function(res, celular = FALSE) {
  tx <- res$tx
  tam <- tamanhos(celular)
  d <- res$resposta_unidade |>
    mutate(destaque = pct == min(pct), unidade = fct_rev(unidade))
  ggplot(d, aes(pct, unidade, colour = destaque)) +
    geom_vline(xintercept = 100 * sum(d$responderam) / sum(d$saidas), colour = cor[["cinza_claro"]], linewidth = 0.6) +
    geom_errorbar(aes(xmin = inf, xmax = sup), orientation = "y", width = 0, linewidth = 0.9) +
    geom_point(size = 2.6) +
    scale_colour_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["cinza_escuro"]]), guide = "none") +
    scale_x_continuous(labels = \(x) tx$pct(x, 0), limits = c(0, 100), expand = expansion(mult = c(0, 0.02))) +
    labs(x = NULL, y = NULL) +
    tema(tam[["eixo"]]) +
    theme(panel.grid.major.y = element_blank(), panel.grid.major.x = element_line(colour = cor[["grade"]], linewidth = 0.4))
}

## ---- grafico-incidencia ----
# Incidência acumulada da saída voluntária (Aalen-Johansen, com a saída
# involuntária como risco competitivo), por grupo e ano de admissão.
grafico_incidencia <- function(res, celular = FALSE) {
  tx <- res$tx
  tam <- tamanhos(celular)
  grupos <- c("CD Expedição", "L3 Operações", "Demais gerências")
  d <- res$incidencia |>
    mutate(grupo = factor(traduzir(grupo, tx$grupos), traduzir(grupos, tx$grupos)),
           coorte = factor(ano_admissao))
  # Rótulo na ponta de cada curva: 2025 um pouco acima, 2024 um pouco abaixo,
  # para não se sobreporem quando as duas curvas terminam perto.
  ponta <- d |> filter(dias == max(dias)) |> mutate(rotulo = ano_admissao, vj = if_else(ano_admissao == 2025, -0.15, 1.15))
  ggplot(d, aes(dias, inc, colour = coorte, fill = coorte)) +
    geom_vline(xintercept = 90, colour = cor[["cinza_claro"]], linewidth = 0.6, linetype = "22") +
    geom_ribbon(data = filter(d, ano_admissao == 2025), aes(ymin = inf, ymax = sup), colour = NA, alpha = 0.14) +
    geom_step(linewidth = 0.95) +
    geom_text(data = ponta, aes(label = rotulo, vjust = vj), hjust = 0, nudge_x = 5, size = tam[["nota"]] / .pt,
              family = "Montserrat", fontface = "bold") +
    facet_wrap(~grupo, ncol = if (celular) 1 else 3) +
    scale_colour_manual(values = c(`2024` = cor[["cinza"]], `2025` = cor[["azul"]]), guide = "none") +
    scale_fill_manual(values = c(`2024` = cor[["cinza"]], `2025` = cor[["azul"]]), guide = "none") +
    scale_x_continuous(breaks = c(0, 90, 180), expand = expansion(mult = c(0.02, 0.2))) +
    scale_y_continuous(labels = \(x) tx$pct(x, 0), limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
    coord_cartesian(clip = "off") +
    labs(x = tx$g_dias, y = NULL) +
    tema(tam[["eixo"]]) +
    theme(axis.title.x = element_text(size = tam[["eixo"]], colour = cor[["cinza_escuro"]], margin = margin(t = 6)),
          panel.spacing.x = unit(1.4, "lines"), panel.spacing.y = unit(0.9, "lines"))
}

## ---- grafico-troca ----
# Saídas voluntárias por 100 pessoas, média móvel de três meses: L5 Vendas
# contra as outras sete gerências de Vendas. A marca é a troca de gestor.
grafico_troca <- function(res, celular = FALSE) {
  tx <- res$tx
  tam <- tamanhos(celular)
  d <- res$troca_mensal |>
    filter(!is.na(taxa_mm3)) |>
    mutate(data = mes_data(ano_mes), destaque = grupo == res$gerencia_troca,
           rotulo = traduzir(grupo, tx$grupos))
  ponta <- d |> filter(data == max(data))
  troca <- res$troca
  topo <- max(d$taxa_mm3) * 1.12
  ggplot(d, aes(data, taxa_mm3, colour = destaque)) +
    geom_vline(xintercept = troca, colour = cor[["cinza_claro"]], linewidth = 0.6) +
    annotate("text", x = troca, y = topo, label = tx$g_troca, hjust = 1.06, vjust = 1, family = "Montserrat",
             size = tam[["nota"]] / .pt, colour = cor[["cinza_escuro"]]) +
    geom_line(linewidth = 1.05) +
    geom_text(data = ponta, aes(label = str_wrap(rotulo, if (celular) 12 else 16)), hjust = 0, nudge_x = 12,
              size = tam[["rotulo"]] / .pt, family = "Montserrat", fontface = "bold", lineheight = 0.9) +
    scale_colour_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["cinza"]]), guide = "none") +
    scale_x_date(breaks = mes_data(c("2024-03", "2024-09", "2025-03", "2025-09")),
                 labels = \(x) paste(tx$meses_abrev[as.integer(format(x, "%m"))], format(x, "%Y")),
                 expand = expansion(mult = c(0.02, if (celular) 0.42 else 0.26))) +
    scale_y_continuous(labels = \(x) tx$num(x, 0), breaks = seq(0, 20, by = 2), limits = c(0, topo),
                       expand = expansion(mult = c(0, 0.02))) +
    coord_cartesian(clip = "off") +
    labs(x = NULL, y = NULL) +
    tema(tam[["eixo"]])
}

## ---- grafico-jornada ----
# Jornada e escala como motivo principal, por turno e escala, com o intervalo
# de 95%. A noite na escala 6x1 em azul.
grafico_jornada <- function(res, celular = FALSE) {
  tx <- res$tx
  tam <- tamanhos(celular)
  d <- res$jornada |>
    mutate(destaque = grupo == "Noite, 6x1",
           rotulo = paste0(traduzir(grupo, tx$grupos), " (", tx$num(n), ")"),
           rotulo = fct_rev(factor(rotulo, rotulo)))
  ggplot(d, aes(pct, rotulo, fill = destaque)) +
    geom_col(width = 0.62) +
    geom_errorbar(aes(xmin = inf, xmax = sup), orientation = "y", width = 0, colour = cor[["cinza"]], linewidth = 0.35) +
    geom_text(aes(x = sup, label = tx$pct(pct, 0)), hjust = -0.2, size = tam[["rotulo"]] / .pt,
              family = "Montserrat", colour = cor[["profundo"]]) +
    scale_fill_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["cinza_claro"]]), guide = "none") +
    scale_x_continuous(labels = NULL, expand = expansion(mult = c(0, 0.18))) +
    labs(x = NULL, y = NULL) +
    tema(tam[["eixo"]]) +
    theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = cor[["profundo"]], size = tam[["eixo"]]))
}

## ---- tabelas ----
esc <- function(x) htmltools::htmlEscape(x)
html_bruto <- function(x) paste0("```{=html}\n", x, "\n```\n")
tabela <- function(d, nomes, alinhar = NULL) knitr::kable(setNames(d, nomes), align = alinhar)

# A mesma tabela em cartões, para o celular: a primeira coluna vira o título
# e as outras, linhas "Rótulo: valor".
cartoes <- function(d, nomes) {
  linhas <- vapply(seq_len(nrow(d)), function(i) {
    detalhes <- vapply(seq_along(nomes)[-1], function(j) {
      if (is.na(d[[j]][i]) || d[[j]][i] == "") return("")
      paste0('<p><span class="cartao-rotulo">', esc(nomes[j]), ":</span> ", esc(d[[j]][i]), "</p>")
    }, "")
    paste0('<div class="cartao-linha"><p class="cartao-titulo">', esc(d[[1]][i]), "</p>",
           paste(detalhes, collapse = ""), "</div>")
  }, "")
  html_bruto(paste0('<div class="cartoes-lista">', paste(linhas, collapse = ""), "</div>"))
}

# Prioridades por gerência, formatadas na língua. Grupos com menos de 10
# pessoas viram "<10". Com pdf = TRUE, só as gerências que não são
# "Acompanhar" e sem a coluna de resposta.
prioridades_fmt <- function(res, pdf = FALSE) {
  tx <- res$tx
  pr <- res$prioridades
  if (pdf) pr <- pr |> filter(prioridade != "Acompanhar")
  menos <- \(valor, n) if_else(n < 10, tx$menos_de_10, valor)
  d <- pr |>
    transmute(ordem = tx$num(ordem), gerencia, prioridade = traduzir(prioridade, tx$prioridades),
              sinais = vapply(strsplit(sinais, "; "), \(s) paste(traduzir(s, tx$sinais), collapse = "; "), ""),
              taxa = tx$pct(taxa_vol, 2),
              noventa = menos(tx$pct(pct_90, 0), admitidos),
              resposta = menos(tx$pct(resposta, 0), saidas),
              lideranca = menos(tx$pct(pct_lideranca, 0), resp_vol))
  if (pdf) d <- d |> select(-resposta)
  d
}

# Razões de chances dos modelos, para a seção de método.
or_fmt <- function(res, tab, nomes_termos) {
  tx <- res$tx
  tab |>
    mutate(termo = nomes_termos[termo]) |>
    filter(!is.na(termo)) |>
    transmute(termo, or = tx$num(or, 2), ic = paste0(tx$num(inf, 2), " a ", tx$num(sup, 2)),
              p = if_else(p < 0.001, "< 0,001", tx$num(p, 3)))
}

## ---- capa ----
# Mesmo estilo das capas dos outros casos: fundo azul profundo, logo, título,
# subtítulo, uma frase e uma versão pequena do gráfico principal.
salvar_capa <- function(res, arquivo = "img/capa.png", logo) {
  tx <- res$tx
  claro <- c(texto = "#ffffff", sub = "#cacfee", apoio = "#9aa3c7", linha = "#34344f",
             azul = "#9dbde8", cinza = "#4a4f73")
  ordem <- res$pareto_geral$motivo[1:5]
  d <- bind_rows(res$pareto_geral |> mutate(painel = tx$g_todas),
                 res$pareto_nota_baixa |> mutate(painel = tx$g_nota_baixa)) |>
    filter(motivo %in% ordem) |>
    mutate(painel = factor(painel, c(tx$g_todas, tx$g_nota_baixa)),
           destaque = motivo == "Liderança e gestor",
           motivo = factor(str_wrap(traduzir(motivo, tx$motivos), 14), rev(str_wrap(traduzir(ordem, tx$motivos), 14))))
  grafico <- ggplot(d, aes(pct, motivo, fill = destaque)) +
    geom_col(width = 0.66) +
    facet_wrap(~painel, ncol = 2) +
    scale_fill_manual(values = c(`TRUE` = claro[["azul"]], `FALSE` = claro[["cinza"]]), guide = "none") +
    scale_x_continuous(labels = NULL, expand = expansion(mult = c(0, 0.05))) +
    labs(title = tx$capa_grafico, x = NULL, y = NULL) +
    theme_minimal(base_family = "Montserrat", base_size = 14) +
    theme(text = element_text(colour = claro[["sub"]]),
          axis.text.y = element_text(colour = claro[["apoio"]], size = 11, lineheight = 0.9),
          strip.text = element_text(colour = claro[["sub"]], size = 12, hjust = 0, face = "bold"),
          plot.title = element_text(colour = claro[["apoio"]], size = 13.5, margin = margin(b = 10)),
          plot.title.position = "plot", panel.grid = element_blank(),
          panel.spacing.x = unit(1.2, "lines"),
          plot.background = element_blank(), panel.background = element_blank())

  pn <- res$pareto_nota_baixa
  frase <- tx$capa_frase(tx$pct(pn$pct[pn$motivo == "Liderança e gestor"], 0),
                         tx$pct(pn$pct[pn$motivo == "Salário e benefícios"], 0))
  texto <- function(rotulo, y, tamanho, cor_texto, peso = "plain", altura = 1.15) {
    grid::grid.text(rotulo, x = grid::unit(72, "native"), y = grid::unit(675 - y, "native"),
                    just = c("left", "top"),
                    gp = grid::gpar(fontfamily = "Montserrat", fontface = peso, fontsize = tamanho,
                                    col = cor_texto, lineheight = altura),
                    vp = grid::viewport(xscale = c(0, 1200), yscale = c(0, 675)))
  }
  linhas <- function(x) lengths(strsplit(x, "\n"))

  dir.create(dirname(arquivo), showWarnings = FALSE)
  ragg::agg_png(arquivo, width = 1200, height = 675, res = 72, background = cor[["profundo"]])
  on.exit(grDevices::dev.off())
  grid::grid.raster(png::readPNG(logo), x = grid::unit(72, "points"), y = grid::unit(675 - 48, "points"),
                    width = grid::unit(64, "points"), just = c("left", "top"))
  y_titulo <- 150
  texto(tx$capa_titulo, y_titulo, 42, claro[["texto"]], "bold", 1.1)
  y_sub <- y_titulo + 51 * linhas(tx$capa_titulo) + 26
  texto(tx$capa_subtitulo, y_sub, 22, claro[["sub"]], altura = 1.25)
  y_frase <- y_sub + 28 * linhas(tx$capa_subtitulo) + 26
  texto(frase, y_frase, 17, claro[["apoio"]], altura = 1.4)
  texto(tx$capa_rodape, 630, 12, claro[["apoio"]])
  print(grafico, vp = grid::viewport(x = grid::unit(1150, "points"), y = grid::unit(675 / 2, "points"),
                                     width = grid::unit(520, "points"), height = grid::unit(360, "points"),
                                     just = c("right", "center")))
}
