# Caso Auditoria: gráficos, tabelas e capa, em qualquer das três línguas. Não há cálculo aqui;
# tudo vem de resultados/auditoria.rds (scripts/auditoria.R) e, para a
# conferência com o gabarito, de resultados/conferencia.rds (scripts/conferir.R).
# A página (index.qmd) e o relatório em PDF (relatorio/relatorio.qmd) usam as
# mesmas funções.
# Azul só no que o texto destaca; Indevido em cinza escuro, nunca em vermelho.

cor <- c(profundo = "#1a1a2e", azul = "#3473C0", azul_claro = "#9dbde8", cinza = "#8b8fa3",
         cinza_escuro = "#4a4a63", cinza_claro = "#d5d7e0", grade = "#e4e6ef", lavanda = "#cacfee",
         fundo_faixa = "#eceef3")

## ---- formatos ----
# Os formatos de número, moeda e data e os textos curtos de cada língua vêm de
# scripts/rotulos.R; ler_auditoria() guarda os da língua pedida em aud$tx.
mes_data <- function(m) as.Date(paste0(m, "-01"))

ler_auditoria <- function(caso = ".", idioma = "pt") {
  aud <- readRDS(file.path(caso, "resultados/auditoria.rds"))
  aud$conferencia <- readRDS(file.path(caso, "resultados/conferencia.rds"))
  aud$caso <- caso
  aud$tx <- rotulos(idioma)
  aud
}

# Põe num(), pct(), reais() e reais_exato() da língua no ambiente de quem chama,
# para o texto da página e do PDF usar os formatos certos.
usar_formatos <- function(aud) {
  list2env(aud$tx[c("num", "pct", "reais", "reais_exato")], envir = parent.frame())
  invisible(aud$tx)
}

# Valores que o texto corrido cita (página e PDF, nas três línguas), postos no
# ambiente de quem chama junto com os formatos da língua. Também confere as
# premissas do texto: se uma delas deixar de valer, o render para.
preparar_texto <- function(aud, envir = parent.frame()) {
  tx <- aud$tx
  conf <- aud$conferencia
  valor_de <- function(tab, chave, col = "valor") tab[[col]][tab[[1]] == chave]
  concl <- \(k, col = "valor") valor_de(aud$conclusoes, k, col)
  bases_jantar <- head(aud$jantar_base, 2)
  meses_fora <- aud$base_mes |> filter(fora_da_faixa)
  casos_parecem <- conf$casos_falsos |> summarise(across(-c(falso, grupo_acima_da_faixa), sum))
  v <- list(
    conf = conf, valor_de = valor_de, concl = concl, indevido = concl("Indevido"),
    s = aud$salto, regras = aud$regras,
    dup_ate_julho = sum(aud$dup_mes$valor[aud$dup_mes$mes <= "2025-07"]),
    dup_depois = sum(aud$dup_mes$valor[aud$dup_mes$mes >= "2025-08"]),
    ferias_5 = with(aud$ferias_dia, 100 * sum(n[dia_do_periodo <= 5]) / sum(n)),
    bases_jantar = bases_jantar,
    jantar_duas = 100 * sum(bases_jantar$valor) / sum(aud$jantar_base$valor),
    nome_base = \(b) paste(tx$g_base, substr(b, 2, 2)),
    meses_fora = meses_fora,
    plantados = sum(conf$deteccao$plantados), encontrados = sum(conf$deteccao$encontrados),
    falsos_alarmes = sum(conf$falsos_alarmes$n),
    parecem_total = sum(casos_parecem), parecem_atencao = sum(casos_parecem$`Atenção`)
  )
  stopifnot("a auditoria achou todos os defeitos plantados" = v$encontrados == v$plantados,
            "só as duas bases do jantar sem pernoite ficam acima da faixa" = all(meses_fora$base %in% bases_jantar$base))
  list2env(c(v, aud$tx[c("num", "pct", "reais", "reais_exato")]), envir = envir)
  invisible(v)
}

tema <- function(tam) {
  theme_minimal(base_family = "Montserrat") +
    theme(text = element_text(colour = cor[["profundo"]]),
          axis.text = element_text(colour = cor[["cinza_escuro"]], size = tam),
          panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(colour = cor[["grade"]], linewidth = 0.4),
          plot.background = element_blank(), panel.background = element_blank())
}
tamanhos <- function(celular) if (celular) c(eixo = 11, rotulo = 11.5, nota = 10.5) else c(eixo = 9.6, rotulo = 10, nota = 9.4)

## ---- grafico-mensal ----
# Valor pago por dia de equipe em campo, mês a mês, com a mesma série sem o
# que a auditoria classificou como indevido. A marca em agosto é a troca do
# sistema de recarga.
grafico_mensal <- function(aud, celular = FALSE) {
  tx <- aud$tx
  tam <- tamanhos(celular)
  d <- aud$mensal |>
    mutate(data = mes_data(mes), sem_indevido = (valor - indevido) / dias_equipe) |>
    select(data, pago = valor_dia, sem = sem_indevido) |>
    pivot_longer(-data, names_to = "serie", values_to = "valor") |>
    mutate(rotulo = if_else(serie == "pago", tx$g_pago, tx$g_sem))
  ponta <- d |> filter(data == max(data))
  # Folga à direita para o rótulo mais longo na ponta das linhas (o inglês é
  # mais comprido que o português).
  extra <- max(0, max(nchar(c(tx$g_pago, tx$g_sem))) - 14)
  troca <- mes_data("2025-08")
  topo <- max(d$valor) * 1.08
  ggplot(d, aes(data, valor, colour = serie, linetype = serie)) +
    geom_vline(xintercept = troca, colour = cor[["cinza_claro"]], linewidth = 0.6) +
    annotate("text", x = troca, y = topo, label = tx$g_troca, hjust = 1.06, vjust = 1,
             family = "Montserrat", size = tam[["nota"]] / .pt, colour = cor[["cinza_escuro"]]) +
    geom_line(linewidth = 1.1) +
    geom_point(data = filter(d, serie == "pago"), size = 1.8) +
    geom_text(data = ponta, aes(label = rotulo), hjust = 0, nudge_x = 9, size = tam[["rotulo"]] / .pt,
              family = "Montserrat", fontface = "bold") +
    scale_colour_manual(values = c(pago = cor[["azul"]], sem = cor[["cinza"]]), guide = "none") +
    scale_linetype_manual(values = c(pago = "solid", sem = "22"), guide = "none") +
    scale_x_date(breaks = seq(mes_data("2025-01"), mes_data("2025-12"), by = if (celular) "3 months" else "1 month"),
                 labels = \(x) tx$meses_abrev[as.integer(format(x, "%m"))],
                 expand = expansion(mult = c(0.02, if (celular) 0.62 + 0.1 * extra else 0.22 + 0.04 * extra))) +
    scale_y_continuous(labels = \(x) paste("R$", tx$num(x)), limits = c(floor(min(d$valor) * 0.9 / 10) * 10, topo),
                       expand = expansion(mult = c(0, 0.02))) +
    coord_cartesian(clip = "off") +
    labs(x = NULL, y = NULL) +
    tema(tam[["eixo"]])
}

## ---- grafico-conclusoes ----
# O valor do ano numa barra única, dividido nas quatro conclusões, com a
# legenda embaixo (em linha no computador, em duas colunas no celular).
cores_conclusao <- c(Indevido = cor[["cinza_escuro"]], Revisar = cor[["cinza"]],
                     `Atenção` = cor[["lavanda"]], Regular = cor[["fundo_faixa"]])
grafico_conclusoes <- function(aud, celular = FALSE) {
  tx <- aud$tx
  tam <- tamanhos(celular)
  d <- aud$conclusoes |>
    mutate(conclusao = factor(conclusao, names(cores_conclusao)),
           fim = cumsum(pct), inicio = fim - pct)
  # Em inglês os valores são longos ("R$ 305 thousand"): valor e % vão em
  # linhas separadas.
  longo <- tx$idioma == "en"
  passo <- if (longo) 1.35 else 1.05
  legenda <- d |>
    mutate(i = row_number() - 1,
           x = 1.2 + if (celular) (i %% 2) * 52 else i * 23,
           y = if (celular) -0.9 - (i %/% 2) * passo else -0.9 - if (longo) 0.15 else 0,
           rotulo = paste0(traduzir(conclusao, tx$conclusoes), "\n", tx$reais(valor),
                           if (longo) "\n" else " · ", tx$pct(pct)))
  ggplot(d) +
    geom_rect(aes(xmin = inicio, xmax = fim, ymin = 0, ymax = 1, fill = conclusao), colour = "white", linewidth = 0.6) +
    # borda cinza em todos os quadradinhos, para o do Regular não sumir no fundo
    geom_point(data = legenda, aes(x, y, fill = conclusao), shape = 22, size = 4.2, stroke = 0.7, colour = cor[["cinza"]]) +
    geom_text(data = legenda, aes(x + 3, y, label = rotulo), hjust = 0, vjust = 0.5, lineheight = 0.95,
              size = tam[["rotulo"]] / .pt, family = "Montserrat", colour = cor[["profundo"]]) +
    scale_fill_manual(values = cores_conclusao, guide = "none") +
    scale_x_continuous(limits = c(0, 100), expand = expansion(mult = c(0, 0.02))) +
    scale_y_continuous(limits = c(if (celular) -2.4 - (passo - 1.05) * 2 else if (longo) -1.75 else -1.4, 1.05)) +
    coord_cartesian(clip = "off") +
    theme_void(base_family = "Montserrat") +
    theme(plot.background = element_blank())
}

## ---- grafico-defeitos ----
# Valor indevido por tipo de defeito, do maior para o menor. A duplicidade,
# que o texto liga à troca de sistema, em azul.
grafico_defeitos <- function(aud, celular = FALSE) {
  tx <- aud$tx
  tam <- tamanhos(celular)
  # Folga à direita para o rótulo de valor mais longo.
  extra <- max(0, max(nchar(tx$reais(aud$por_defeito$valor))) - 10)
  d <- aud$por_defeito |>
    mutate(destaque = motivo == "Duplicidade",
           motivo = traduzir(motivo, tx$motivos),
           motivo = fct_reorder(if (celular) str_wrap(motivo, 14) else motivo, valor))
  ggplot(d, aes(valor, motivo, fill = destaque)) +
    geom_col(width = 0.62) +
    geom_text(aes(label = tx$reais(valor)), hjust = -0.12, size = tam[["rotulo"]] / .pt, family = "Montserrat",
              colour = cor[["profundo"]]) +
    scale_fill_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["cinza_escuro"]]), guide = "none") +
    scale_x_continuous(expand = expansion(mult = c(0, if (celular) 0.42 + 0.1 * extra else 0.2 + 0.025 * extra)),
                       labels = NULL) +
    labs(x = NULL, y = NULL) +
    tema(tam[["eixo"]]) +
    theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = cor[["profundo"]], size = tam[["eixo"]]))
}

## ---- grafico-faixa ----
# Valor por dia de equipe em campo, por base e mês, contra a faixa esperada
# (a faixa acompanha o nível do mês). Pontos acima da faixa em azul; as bases
# com algum mês acima, com a linha em azul.
grafico_faixa <- function(aud, celular = FALSE) {
  tx <- aud$tx
  tam <- tamanhos(celular)
  d <- aud$base_mes |>
    mutate(data = mes_data(mes)) |>
    group_by(base) |>
    mutate(destaque = any(fora_da_faixa)) |>
    ungroup() |>
    mutate(painel = paste(tx$g_base, substr(base, 2, 2)))
  ggplot(d, aes(data)) +
    geom_ribbon(aes(ymin = faixa_min, ymax = faixa_max), fill = cor[["fundo_faixa"]]) +
    geom_line(aes(y = valor_dia, colour = destaque), linewidth = 0.8) +
    geom_point(data = filter(d, fora_da_faixa), aes(y = valor_dia), colour = cor[["azul"]], size = 2.2) +
    facet_wrap(~painel, ncol = if (celular) 2 else 4) +
    scale_colour_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["cinza"]]), guide = "none") +
    scale_x_date(breaks = mes_data(c("2025-01", "2025-07")), labels = tx$meses_abrev[c(1, 7)],
                 expand = expansion(mult = 0.04)) +
    scale_y_continuous(labels = \(x) paste("R$", tx$num(x))) +
    labs(x = NULL, y = NULL) +
    tema(tam[["eixo"]] - 0.6) +
    theme(strip.text = element_text(family = "Montserrat", face = "bold", size = tam[["eixo"]], hjust = 0,
                                    colour = cor[["profundo"]]),
          panel.spacing.x = unit(if (celular) 1 else 0.8, "lines"))
}

## ---- julho ----
# Por que o valor por dia de equipe cai em julho (e em janeiro): são os meses
# com mais gente de férias, as equipes saem a campo com menos pessoas, e o
# valor por pessoa em campo não muda. Página e PDF usam a mesma frase.
explica_julho <- function(aud) {
  tx <- aud$tx
  m <- aud$mensal
  jul <- m[m$mes == "2025-07", ]
  mais_ferias <- head(m$mes[order(-m$ferias_por_dia)], 2)
  stopifnot("julho está entre os dois meses com mais gente de férias" = "2025-07" %in% mais_ferias)
  outro <- setdiff(mais_ferias, "2025-07")
  faixa_pessoa <- range(m$valor_pessoa[m$mes <= "2025-07"])
  tx$julho(outro = tx$meses_nome[as.integer(substr(outro, 6, 7))],
           ferias = tx$num(jul$ferias_por_dia), ferias_med = tx$num(median(m$ferias_por_dia)),
           pessoas = tx$num(jul$pessoas_por_equipe, 1), pessoas_med = tx$num(median(m$pessoas_por_equipe), 1),
           de = tx$reais_exato(floor(faixa_pessoa[1])), ate = tx$reais_exato(ceiling(faixa_pessoa[2])))
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
      paste0('<p><span class="cartao-rotulo">', esc(nomes[j]), ":</span> ", esc(d[[j]][i]), "</p>")
    }, "")
    paste0('<div class="cartao-linha"><p class="cartao-titulo">', esc(d[[1]][i]), "</p>",
           paste(detalhes, collapse = ""), "</div>")
  }, "")
  html_bruto(paste0('<div class="cartoes-lista">', paste(linhas, collapse = ""), "</div>"))
}

# Os casos de maior valor (Indevido primeiro, depois Revisar), já formatados
# na língua. Com curto = TRUE, o motivo sai no rótulo curto (tabela do PDF).
top_revisar_fmt <- function(aud, curto = FALSE) {
  tx <- aud$tx
  aud$top_revisar |>
    transmute(conclusao = traduzir(conclusao, tx$conclusoes), matricula,
              base = paste0(tx$g_base, " ", substr(base, 2, 2)),
              periodo = tx$periodo(primeiro, ultimo),
              recargas = tx$num(recargas), valor = tx$reais_exato(valor),
              motivo = traduzir(motivo, if (curto) tx$motivos_curtos else tx$motivos))
}
alinhar_top <- c("l", "l", "l", "l", "r", "r", "l")

## ---- capa ----
# Mesmo estilo das capas dos outros casos: fundo azul profundo, logo, título,
# subtítulo, uma frase e uma versão pequena do gráfico do valor por dia.
salvar_capa <- function(aud, arquivo = "img/capa.png", logo) {
  tx <- aud$tx
  claro <- c(texto = "#ffffff", sub = "#cacfee", apoio = "#9aa3c7", linha = "#34344f",
             azul = "#9dbde8", cinza = "#6b7299")
  d <- aud$mensal |>
    mutate(data = mes_data(mes), sem = (valor - indevido) / dias_equipe) |>
    select(data, pago = valor_dia, sem) |>
    pivot_longer(-data, names_to = "serie", values_to = "valor")
  grafico <- ggplot(d, aes(data, valor, colour = serie, linetype = serie)) +
    geom_vline(xintercept = mes_data("2025-08"), colour = claro[["linha"]], linewidth = 0.8) +
    geom_line(linewidth = 1.6) +
    scale_colour_manual(values = c(pago = claro[["azul"]], sem = claro[["cinza"]]), guide = "none") +
    scale_linetype_manual(values = c(pago = "solid", sem = "22"), guide = "none") +
    scale_x_date(breaks = mes_data(c("2025-01", "2025-04", "2025-07", "2025-10")),
                 labels = \(x) tx$meses_abrev[as.integer(format(x, "%m"))]) +
    scale_y_continuous(labels = \(x) paste("R$", tx$num(x))) +
    labs(title = tx$capa_grafico, x = NULL, y = NULL) +
    theme_minimal(base_family = "Montserrat", base_size = 15) +
    theme(text = element_text(colour = claro[["sub"]]),
          axis.text = element_text(colour = claro[["apoio"]], size = 12),
          plot.title = element_text(colour = claro[["apoio"]], size = 14, margin = margin(b = 10)),
          plot.title.position = "plot",
          panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(colour = claro[["linha"]], linewidth = 0.5),
          plot.background = element_blank(), panel.background = element_blank())

  indevido <- aud$conclusoes$valor[aud$conclusoes$conclusao == "Indevido"]
  titulo <- tx$capa_titulo
  subtitulo <- tx$capa_subtitulo
  frase <- tx$capa_frase(tx$reais(indevido), tx$pct(100 * indevido / aud$total))
  rodape <- tx$capa_rodape

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
  texto(titulo, y_titulo, 42, claro[["texto"]], "bold", 1.1)
  y_sub <- y_titulo + 51 * linhas(titulo) + 26
  texto(subtitulo, y_sub, 22, claro[["sub"]], altura = 1.25)
  y_frase <- y_sub + 28 * linhas(subtitulo) + 26
  texto(frase, y_frase, 17, claro[["apoio"]], altura = 1.4)
  texto(rodape, 630, 12, claro[["apoio"]])
  print(grafico, vp = grid::viewport(x = grid::unit(1150, "points"), y = grid::unit(675 / 2, "points"),
                                     width = grid::unit(500, "points"), height = grid::unit(360, "points"),
                                     just = c("right", "center")))
}
