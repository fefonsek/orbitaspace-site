# Caso Auditoria: formatos, gráficos, tabelas e capa. Não há cálculo aqui;
# tudo vem de resultados/auditoria.rds (scripts/auditoria.R) e, para a
# conferência com o gabarito, de resultados/conferencia.rds (scripts/conferir.R).
# A página (index.qmd) e o relatório em PDF (relatorio/relatorio.qmd) usam as
# mesmas funções.
# Azul só no que o texto destaca; Indevido em cinza escuro, nunca em vermelho.

cor <- c(profundo = "#1a1a2e", azul = "#3473C0", azul_claro = "#9dbde8", cinza = "#8b8fa3",
         cinza_escuro = "#4a4a63", cinza_claro = "#d5d7e0", grade = "#e4e6ef", lavanda = "#cacfee",
         fundo_faixa = "#eceef3")

## ---- formatos ----
num <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
pct <- function(x, d = 1) paste0(num(x, d), "%")
# R$ 7,63 milhões, R$ 305 mil, R$ 7 mil, R$ 52. O espaço depois de "R$" é inseparável,
# para o valor não quebrar de linha.
rs <- "R$\u00a0"
reais <- function(x, d_milhao = 2) {
  vapply(x, function(v) {
    if (abs(v) >= 1e6) paste0(rs, num(v / 1e6, d_milhao), "\u00a0milhões")
    else if (abs(v) >= 1e3) paste0(rs, num(v / 1e3, 0), "\u00a0mil")
    else paste0(rs, num(v, if (v != round(v)) 2 else 0))
  }, "")
}
reais_exato <- function(x, d = 0) paste0(rs, num(x, d))
meses_abrev <- c("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez")
meses_nome <- c("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro",
                "outubro", "novembro", "dezembro")
mes_data <- function(m) as.Date(paste0(m, "-01"))
mes_abrev <- function(m) meses_abrev[as.integer(substr(m, 6, 7))]
data_br <- function(d) format(as.Date(d), "%d/%m/%Y")

ler_auditoria <- function(caso = ".") {
  aud <- readRDS(file.path(caso, "resultados/auditoria.rds"))
  aud$conferencia <- readRDS(file.path(caso, "resultados/conferencia.rds"))
  aud$caso <- caso
  aud
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
  tam <- tamanhos(celular)
  d <- aud$mensal |>
    mutate(data = mes_data(mes), sem_indevido = (valor - indevido) / dias_equipe) |>
    select(data, `Valor pago` = valor_dia, `Sem o indevido` = sem_indevido) |>
    pivot_longer(-data, names_to = "serie", values_to = "valor")
  ponta <- d |> filter(data == max(data))
  troca <- mes_data("2025-08")
  topo <- max(d$valor) * 1.08
  ggplot(d, aes(data, valor, colour = serie, linetype = serie)) +
    geom_vline(xintercept = troca, colour = cor[["cinza_claro"]], linewidth = 0.6) +
    annotate("text", x = troca, y = topo, label = "troca de sistema", hjust = 1.06, vjust = 1,
             family = "Montserrat", size = tam[["nota"]] / .pt, colour = cor[["cinza_escuro"]]) +
    geom_line(linewidth = 1.1) +
    geom_point(data = filter(d, serie == "Valor pago"), size = 1.8) +
    geom_text(data = ponta, aes(label = serie), hjust = 0, nudge_x = 9, size = tam[["rotulo"]] / .pt,
              family = "Montserrat", fontface = "bold") +
    scale_colour_manual(values = c(`Valor pago` = cor[["azul"]], `Sem o indevido` = cor[["cinza"]]), guide = "none") +
    scale_linetype_manual(values = c(`Valor pago` = "solid", `Sem o indevido` = "22"), guide = "none") +
    scale_x_date(breaks = seq(mes_data("2025-01"), mes_data("2025-12"), by = if (celular) "3 months" else "1 month"),
                 labels = \(x) meses_abrev[as.integer(format(x, "%m"))],
                 expand = expansion(mult = c(0.02, if (celular) 0.62 else 0.22))) +
    scale_y_continuous(labels = \(x) paste("R$", num(x)), limits = c(floor(min(d$valor) * 0.9 / 10) * 10, topo),
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
  tam <- tamanhos(celular)
  d <- aud$conclusoes |>
    mutate(conclusao = factor(conclusao, names(cores_conclusao)),
           fim = cumsum(pct), inicio = fim - pct)
  legenda <- d |>
    mutate(i = row_number() - 1,
           x = 1.2 + if (celular) (i %% 2) * 52 else i * 23,
           y = if (celular) -0.9 - (i %/% 2) * 1.05 else -0.9,
           rotulo = paste0(conclusao, "\n", reais(valor), " · ", pct(pct)))
  ggplot(d) +
    geom_rect(aes(xmin = inicio, xmax = fim, ymin = 0, ymax = 1, fill = conclusao), colour = "white", linewidth = 0.6) +
    # borda cinza em todos os quadradinhos, para o do Regular não sumir no fundo
    geom_point(data = legenda, aes(x, y, fill = conclusao), shape = 22, size = 4.2, stroke = 0.7, colour = cor[["cinza"]]) +
    geom_text(data = legenda, aes(x + 3, y, label = rotulo), hjust = 0, vjust = 0.5, lineheight = 0.95,
              size = tam[["rotulo"]] / .pt, family = "Montserrat", colour = cor[["profundo"]]) +
    scale_fill_manual(values = cores_conclusao, guide = "none") +
    scale_x_continuous(limits = c(0, 100), expand = expansion(mult = c(0, 0.02))) +
    scale_y_continuous(limits = c(if (celular) -2.4 else -1.4, 1.05)) +
    coord_cartesian(clip = "off") +
    theme_void(base_family = "Montserrat") +
    theme(plot.background = element_blank())
}

## ---- grafico-defeitos ----
# Valor indevido por tipo de defeito, do maior para o menor. A duplicidade,
# que o texto liga à troca de sistema, em azul.
grafico_defeitos <- function(aud, celular = FALSE) {
  tam <- tamanhos(celular)
  d <- aud$por_defeito |>
    mutate(motivo = fct_reorder(if (celular) str_wrap(motivo, 14) else motivo, valor),
           destaque = grepl("Duplicidade", motivo))
  ggplot(d, aes(valor, motivo, fill = destaque)) +
    geom_col(width = 0.62) +
    geom_text(aes(label = reais(valor)), hjust = -0.12, size = tam[["rotulo"]] / .pt, family = "Montserrat",
              colour = cor[["profundo"]]) +
    scale_fill_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["cinza_escuro"]]), guide = "none") +
    scale_x_continuous(expand = expansion(mult = c(0, if (celular) 0.42 else 0.2)), labels = NULL) +
    labs(x = NULL, y = NULL) +
    tema(tam[["eixo"]]) +
    theme(panel.grid.major.y = element_blank(), axis.text.y = element_text(colour = cor[["profundo"]], size = tam[["eixo"]]))
}

## ---- grafico-faixa ----
# Valor por dia de equipe em campo, por base e mês, contra a faixa esperada
# (a faixa acompanha o nível do mês). Pontos acima da faixa em azul; as bases
# com algum mês acima, com a linha em azul.
grafico_faixa <- function(aud, celular = FALSE) {
  tam <- tamanhos(celular)
  d <- aud$base_mes |>
    mutate(data = mes_data(mes)) |>
    group_by(base) |>
    mutate(destaque = any(fora_da_faixa)) |>
    ungroup() |>
    mutate(painel = paste0("Base ", substr(base, 2, 2)))
  ggplot(d, aes(data)) +
    geom_ribbon(aes(ymin = faixa_min, ymax = faixa_max), fill = cor[["fundo_faixa"]]) +
    geom_line(aes(y = valor_dia, colour = destaque), linewidth = 0.8) +
    geom_point(data = filter(d, fora_da_faixa), aes(y = valor_dia), colour = cor[["azul"]], size = 2.2) +
    facet_wrap(~painel, ncol = if (celular) 2 else 4) +
    scale_colour_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["cinza"]]), guide = "none") +
    scale_x_date(breaks = mes_data(c("2025-01", "2025-07")), labels = c("jan", "jul"),
                 expand = expansion(mult = 0.04)) +
    scale_y_continuous(labels = \(x) paste("R$", num(x))) +
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
  m <- aud$mensal
  jul <- m[m$mes == "2025-07", ]
  mais_ferias <- head(m$mes[order(-m$ferias_por_dia)], 2)
  stopifnot("julho está entre os dois meses com mais gente de férias" = "2025-07" %in% mais_ferias)
  outro <- setdiff(mais_ferias, "2025-07")
  faixa_pessoa <- range(m$valor_pessoa[m$mes <= "2025-07"])
  paste0("A queda de julho tem causa nos dados: julho e ", meses_nome[as.integer(substr(outro, 6, 7))],
         " são os meses com mais gente de férias (em julho, ", num(jul$ferias_por_dia),
         " eletricistas por dia útil, contra ", num(median(m$ferias_por_dia)), " na mediana do ano), e cada equipe saiu a campo com ",
         num(jul$pessoas_por_equipe, 1), " pessoas, contra ", num(median(m$pessoas_por_equipe), 1),
         " na mediana. O valor por pessoa em campo não caiu: ficou entre ", reais_exato(floor(faixa_pessoa[1])),
         " e ", reais_exato(ceiling(faixa_pessoa[2])), " de janeiro a julho.")
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

# Os casos de maior valor (Indevido primeiro, depois Revisar), já formatados.
top_revisar_fmt <- function(aud) {
  aud$top_revisar |>
    transmute(conclusao = as.character(conclusao), matricula, base = paste0("Base\u00a0", substr(base, 2, 2)),
              periodo = paste(data_br(primeiro), "a", data_br(ultimo)),
              recargas = num(recargas), valor = reais_exato(valor), motivo)
}
nomes_top <- c("Conclusão", "Matrícula", "Base", "Período", "Recargas", "Valor", "Motivo")
alinhar_top <- c("l", "l", "l", "l", "r", "r", "l")

## ---- capa ----
# Mesmo estilo das capas dos outros casos: fundo azul profundo, logo, título,
# subtítulo, uma frase e uma versão pequena do gráfico do valor por dia.
salvar_capa <- function(aud, arquivo = "img/capa.png", logo) {
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
                 labels = \(x) meses_abrev[as.integer(format(x, "%m"))]) +
    scale_y_continuous(labels = \(x) paste("R$", num(x))) +
    labs(title = "Valor pago por dia em campo, 2025", x = NULL, y = NULL) +
    theme_minimal(base_family = "Montserrat", base_size = 15) +
    theme(text = element_text(colour = claro[["sub"]]),
          axis.text = element_text(colour = claro[["apoio"]], size = 12),
          plot.title = element_text(colour = claro[["apoio"]], size = 14, margin = margin(b = 10)),
          plot.title.position = "plot",
          panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(colour = claro[["linha"]], linewidth = 0.5),
          plot.background = element_blank(), panel.background = element_blank())

  indevido <- aud$conclusoes$valor[aud$conclusoes$conclusao == "Indevido"]
  titulo <- "Auditoria do benefício\nde alimentação\nem campo"
  subtitulo <- "Fiorena Redes Elétricas, 2025"
  frase <- paste0(reais(indevido), " pagos fora da regra,\n", pct(100 * indevido / aud$total), " do valor do ano.")
  rodape <- "Empresa, pessoas e dados fictícios · Felipe Fonseca · @fefonsek"

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
