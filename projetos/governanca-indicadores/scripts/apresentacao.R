# Caso Indicadores: gráficos, partes em HTML e capa. Não há cálculo aqui;
# tudo vem de ler_caso() (scripts/dados.R).
# Azul só no que o texto destaca (a taxa oficial, o caminho até a diretoria);
# o resto em cinza.

cor <- c(profundo = "#1a1a2e", azul = "#3473C0", cinza = "#8b8fa3", cinza_escuro = "#4a4a63",
         cinza_claro = "#d5d7e0", grade = "#e4e6ef", lavanda = "#cacfee")

nomes_def <- c(rh = "RH", operacao = "Operação", financeiro = "Financeiro")

# Rótulos na ponta das linhas: afasta os que ficariam um em cima do outro.
afastar <- function(y, minimo) {
  o <- order(y); v <- y[o]
  for (i in seq_along(v)[-1]) v[i] <- max(v[i], v[i - 1] + minimo)
  v <- v - (mean(v) - mean(y[o]))  # recentra o grupo
  y[o] <- v
  y
}
pontas <- function(d, minimo) d |> filter(data == max(data)) |> mutate(y_rot = afastar(taxa, minimo))
marcas <- function(d, meses) seq(min(d$data), max(d$data), by = paste(meses, "months"))

## ---- grafico-taxas ----
# Duas versões do mesmo gráfico: a do computador (larga) e a do celular (mais
# estreita e alta, com letras maiores), para os textos ficarem com pelo menos
# 11 px na tela nos dois casos. Tamanhos de texto em pontos.
grafico_taxas <- function(ind, destaque, celular = FALSE) {
  tam <- if (celular) c(eixo = 11, rotulo = 12, nota = 10.5) else c(eixo = 9.6, rotulo = 10.5, nota = 9.6)
  d <- ind$taxas |>
    mutate(data = as.Date(paste0(mes, "-01")), definicao = factor(definicao, names(nomes_def)))
  ponta <- pontas(d, if (celular) 0.42 else 0.32)
  marca <- d |> filter(mes == destaque)
  linha <- as.Date(paste0(destaque, "-01"))
  topo <- max(d$taxa) * 1.12
  ggplot(d, aes(data, taxa, group = definicao, colour = definicao == "rh")) +
    geom_vline(xintercept = linha, colour = cor[["cinza_claro"]], linewidth = 0.6) +
    annotate("text", x = linha, y = topo, label = "reunião de julho", hjust = 1.06, vjust = 1,
             family = "Montserrat", size = tam[["nota"]] / .pt, colour = cor[["cinza_escuro"]]) +
    geom_line(aes(linewidth = definicao == "rh")) +
    geom_point(data = marca, size = 2.6) +
    geom_text(data = ponta, aes(y = y_rot, label = nomes_def[as.character(definicao)]), hjust = 0, nudge_x = 12,
              size = tam[["rotulo"]] / .pt, family = "Montserrat", fontface = "bold") +
    scale_colour_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["cinza"]]), guide = "none") +
    scale_linewidth_manual(values = c(`TRUE` = 1.3, `FALSE` = 0.9), guide = "none") +
    scale_x_date(breaks = marcas(d, if (celular) 6 else 3),
                 labels = \(x) paste0(substr(meses_pt[as.integer(format(x, "%m"))], 1, 3), "\n", format(x, "%Y")),
                 expand = expansion(mult = c(0.01, if (celular) 0.36 else 0.13))) +
    scale_y_continuous(labels = \(x) pct(x, if (celular) 0 else 1), limits = c(0, topo), expand = expansion(mult = c(0, 0.02))) +
    labs(x = NULL, y = NULL) +
    theme_minimal(base_family = "Montserrat") +
    theme(text = element_text(colour = cor[["profundo"]]),
          axis.text = element_text(colour = cor[["cinza_escuro"]], size = tam[["eixo"]]),
          panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(colour = cor[["grade"]], linewidth = 0.4),
          plot.background = element_blank(), panel.background = element_blank())
}

## ---- grafico-fluxo ----
# Diagrama de fluxo (situação -> destino) desenhado com ggplot2: cada faixa
# tem a espessura do número de indicadores. Os caminhos até a Diretoria em
# azul; o resto em cinza. No celular os rótulos quebram em duas linhas e as
# letras ficam maiores.
grafico_fluxo <- function(ind, celular = FALSE) {
  tam <- if (celular) c(rotulo = 11.5, titulo = 10.5) else c(rotulo = 10.5, titulo = 9.6)
  fluxos <- ind$inventario |> count(situacao, destino, .drop = TRUE)
  folga <- 1.2  # espaço entre os blocos, em "indicadores"
  blocos <- function(n) {
    fim <- cumsum(n + folga) - folga
    tibble(y1 = -(fim - n), y0 = -fim)  # de cima para baixo
  }
  esq <- tibble(nome = levels(ind$inventario$situacao), n = as.vector(ind$situacao)) |> bind_cols(blocos(as.vector(ind$situacao)))
  dir_n <- as.vector(ind$destino)
  # centraliza a coluna da direita, que tem menos blocos
  ajuste <- (sum(esq$n) + folga * (nrow(esq) - 1) - (sum(dir_n) + folga * (length(dir_n) - 1))) / 2
  dir <- tibble(nome = levels(ind$inventario$destino), n = dir_n) |> bind_cols(blocos(dir_n)) |>
    mutate(y1 = y1 - ajuste, y0 = y0 - ajuste)

  fluxos <- fluxos |>
    arrange(situacao, destino) |>
    group_by(situacao) |> mutate(e_topo = esq$y1[match(situacao, esq$nome)] - (cumsum(n) - n)) |> ungroup() |>
    arrange(destino, situacao) |>
    group_by(destino) |> mutate(d_topo = dir$y1[match(destino, dir$nome)] - (cumsum(n) - n)) |> ungroup() |>
    mutate(id = row_number(), diretoria = destino == "Diretoria")
  x0 <- 0.06; x1 <- 0.94
  curva <- function(t) 3 * t^2 - 2 * t^3
  faixas <- fluxos |>
    reframe(t = seq(0, 1, length.out = 40), .by = c(id, diretoria)) |>
    left_join(select(fluxos, id, n, e_topo, d_topo), "id") |>
    mutate(x = x0 + (x1 - x0) * t, topo = e_topo + (d_topo - e_topo) * curva(t), base = topo - n)

  # Nomes longos quebram no último espaço ("Gestão da" / "área").
  quebrar <- function(x) ifelse(nchar(x) > 10, sub("^(.*) ", "\\1\n", x), x)
  rotulo <- function(d, lado) {
    mutate(d, rot = paste0(if (celular) quebrar(nome) else nome, if (celular) "\n(" else " (", n, ")"),
           y = (y0 + y1) / 2, x = if (lado == "esq") x0 - 0.015 else x1 + 0.015,
           destaque = nome == "Diretoria")
  }
  ggplot() +
    geom_ribbon(data = faixas, aes(x, ymin = base, ymax = topo, group = id, fill = diretoria), alpha = 0.55) +
    geom_rect(data = esq, aes(xmin = x0 - 0.012, xmax = x0, ymin = y0, ymax = y1), fill = cor[["cinza_escuro"]]) +
    geom_rect(data = dir, aes(xmin = x1, xmax = x1 + 0.012, ymin = y0, ymax = y1, fill = nome == "Diretoria")) +
    geom_text(data = rotulo(esq, "esq"), aes(x, y, label = rot), hjust = 1, size = tam[["rotulo"]] / .pt, lineheight = 0.9,
              family = "Montserrat", colour = cor[["profundo"]]) +
    geom_text(data = rotulo(dir, "dir"), aes(x, y, label = rot, colour = destaque, fontface = ifelse(destaque, "bold", "plain")),
              hjust = 0, size = tam[["rotulo"]] / .pt, lineheight = 0.9, family = "Montserrat") +
    annotate("text", x = c(x0, x1), y = max(esq$y1) + 1.6, label = c(if (celular) "Situação" else "Situação encontrada", "Destino"),
             hjust = c(1, 0), family = "Montserrat", fontface = "bold", size = tam[["titulo"]] / .pt, colour = cor[["cinza_escuro"]]) +
    scale_fill_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["cinza_claro"]]), guide = "none") +
    scale_colour_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["profundo"]]), guide = "none") +
    scale_x_continuous(limits = if (celular) c(-0.5, 1.5) else c(-0.32, 1.3)) +
    coord_cartesian(clip = "off") +
    theme_void(base_family = "Montserrat") +
    theme(plot.background = element_blank())
}

## ---- html ----
esc <- function(x) htmltools::htmlEscape(x)
# Só o negrito do Markdown (**texto**), depois de escapar o resto.
negrito <- function(x) gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", esc(x))

# As três definições: tabela no computador e três blocos empilhados no celular
# (o CSS mostra um ou outro). Os textos vêm de dados/definicoes.csv e os
# valores anuais, das taxas agregadas. Sai como HTML bruto, para o Quarto não
# transformar a tabela numa tabela de dados listrada.
definicoes_html <- function(ind, anos = c(2024, 2025)) {
  defs <- ind$definicoes
  cols <- names(nomes_def)
  valores <- tibble(campo = paste("Valor em", anos),
                    !!!setNames(lapply(cols, \(d) vapply(anos, \(a) pct(ind$anual(d, a)), "")), cols))
  posicao <- match("Unidade", defs$campo)
  defs <- bind_rows(defs[seq_len(posicao), ], valores, defs[-seq_len(posicao), ])

  cabecalho <- paste0("<tr><th></th>", paste0("<th>", nomes_def[cols], "</th>", collapse = ""), "</tr>")
  linhas <- vapply(seq_len(nrow(defs)), function(i) {
    paste0("<tr><td>", esc(defs$campo[i]), "</td>",
           paste0("<td>", vapply(cols, \(d) negrito(defs[[d]][i]), ""), "</td>", collapse = ""), "</tr>")
  }, "")
  tabela <- paste0('<div class="tabela-rolavel definicoes-tabela"><table class="table" data-quarto-disable-processing="true">',
                   "<thead>", cabecalho, "</thead><tbody>", paste(linhas, collapse = ""), "</tbody></table></div>")
  blocos <- vapply(cols, function(d) {
    paste0('<div class="definicao-bloco', if (d == "rh") " definicao-oficial" else "", '"><p class="definicao-nome">',
           nomes_def[[d]], "</p><dl>",
           paste0("<dt>", esc(defs$campo), "</dt><dd>", vapply(defs[[d]], negrito, ""), "</dd>", collapse = ""),
           "</dl></div>")
  }, "")
  paste0("```{=html}\n<div class=\"definicoes\">", tabela, '<div class="definicoes-blocos">',
         paste(blocos, collapse = ""), "</div></div>\n```\n")
}

# Inventário com busca e filtros. O filtro é um script pequeno (inventario.js),
# sem biblioteca: a tabela tem 40 linhas.
tabela_inventario <- function(ind, js = "scripts/inventario.js") {
  inv <- ind$inventario
  opcoes <- function(x, rotulo) {
    paste0('<option value="">', rotulo, "</option>",
           paste0('<option value="', esc(x), '">', esc(x), "</option>", collapse = ""))
  }
  linhas <- paste0(
    '<tr data-area="', esc(inv$area), '" data-situacao="', esc(inv$situacao), '" data-destino="', esc(inv$destino), '">',
    '<td class="inv-numero">', inv$numero, '</td><td class="inv-nome">', esc(inv$indicador),
    '</td><td class="inv-area">', esc(inv$area), '</td><td class="inv-situacao">', esc(inv$situacao),
    '</td><td class="inv-destino', ifelse(inv$destino == "Diretoria", " destino-diretoria", ""), '">', esc(inv$destino),
    '</td><td class="inv-obs">', esc(coalesce(inv$observacao, "")),
    '</td><td class="inv-ficha">', esc(coalesce(inv$ficha, "")), "</td></tr>",
    collapse = "\n")
  htmltools::HTML(paste0(
    '<div class="inventario">\n<div class="inventario-filtros">',
    '<input type="search" class="form-control" placeholder="Buscar indicador ou observação" aria-label="Buscar no inventário">',
    '<select class="form-select" data-filtro="area" aria-label="Filtrar por área">', opcoes(sort(unique(inv$area)), "Todas as áreas"), "</select>",
    '<select class="form-select" data-filtro="situacao" aria-label="Filtrar por situação">', opcoes(levels(inv$situacao), "Todas as situações"), "</select>",
    '<select class="form-select" data-filtro="destino" aria-label="Filtrar por destino">', opcoes(levels(inv$destino), "Todos os destinos"), "</select>",
    '</div>\n<p class="inventario-contagem" aria-live="polite" data-total="', nrow(inv), '">', nrow(inv), " de ", nrow(inv), " indicadores</p>\n",
    '<div class="tabela-rolavel"><table class="table">\n<thead><tr><th>#</th><th>Indicador (como era chamado)</th><th>Área</th>',
    "<th>Situação</th><th>Destino</th><th>Observação</th><th>Ficha</th></tr></thead>\n<tbody>\n", linhas,
    "\n</tbody></table></div>\n</div>\n<script>\n", paste(readLines(js, encoding = "UTF-8"), collapse = "\n"), "\n</script>"))
}

# Pilares: quatro colunas que se empilham no celular.
pilares_html <- function(ind, meta, base) {
  fichas <- ind$fichas
  pilares <- unique(vapply(fichas, \(f) f$pilar, character(1)))
  colunas <- vapply(pilares, function(p) {
    fs <- Filter(\(f) f$pilar == p, fichas)
    paste0('<div class="pilar"><p class="pilar-nome">', esc(p), '</p><p class="pilar-objetivo">', esc(fs[[1]]$objetivo),
           "</p><ul>", paste0("<li><span>", esc(vapply(fs, \(f) f$codigo, "")), "</span> ",
                              esc(vapply(fs, \(f) f$indicador, "")), "</li>", collapse = ""), "</ul></div>")
  }, character(1))
  htmltools::HTML(paste0('<div class="arvore">\n<p class="arvore-meta">', esc(meta), '</p>\n<div class="arvore-pilares">',
                         paste(colunas, collapse = "\n"), '</div>\n<p class="arvore-base">', esc(base), "</p>\n</div>"))
}

# Fichas em cartões que abrem com um clique, agrupadas por objetivo.
fichas_html <- function(ind, aberta = "PES-01") {
  rotulos <- c(codigo = "Código", pergunta = "Pergunta que responde", objetivo = "Objetivo ligado",
               formula = "Fórmula", numerador = "Numerador", denominador = "Denominador",
               fora = "Fica fora dos dois", quebras = "Quebras padrão", fonte = "Fonte",
               periodicidade = "Periodicidade", polaridade = "Polaridade", meta = "Meta e faixas",
               dono = "Dono do resultado", responsavel_calculo = "Responsável pelo cálculo",
               decisao = "Decisão que apoia", relacionados = "Indicadores relacionados", versao = "Versão")
  cartao <- function(f) {
    valores <- f[names(rotulos)]
    valores$objetivo <- paste0(f$pilar, ": ", tolower(substr(f$objetivo, 1, 1)), substr(f$objetivo, 2, nchar(f$objetivo)))
    paste0('<details class="ficha"', if (f$codigo == aberta) " open" else "", '><summary><span class="ficha-codigo">',
           esc(f$codigo), '</span> <span class="ficha-nome">', esc(f$indicador), '</span><span class="ficha-resumo">',
           esc(f$formula), "</span></summary>\n<dl>",
           paste0("<dt>", rotulos, "</dt><dd>", esc(unlist(valores)), "</dd>", collapse = ""), "</dl></details>")
  }
  pilares <- unique(vapply(ind$fichas, \(f) f$pilar, character(1)))
  grupos <- vapply(pilares, function(p) {
    fs <- Filter(\(f) f$pilar == p, ind$fichas)
    paste0('<div class="fichas-grupo"><h3>', esc(p), ": ", esc(tolower(fs[[1]]$objetivo)), "</h3>\n",
           paste(vapply(fs, cartao, character(1)), collapse = "\n"), "</div>")
  }, character(1))
  htmltools::HTML(paste(grupos, collapse = "\n"))
}

# Versões em cartões da RACI e do registro de versões, para o celular (o CSS
# mostra a tabela no computador e os cartões em telas de até 600 px).
html_bruto <- function(x) paste0("```{=html}\n", x, "\n```\n")

raci_cartoes <- function(ind) {
  papeis <- c(dono = "Dono", bi = "BI", comite = "Comitê", diretoria = "Diretoria")
  cartoes <- vapply(seq_len(nrow(ind$raci)), function(i) {
    letras <- vapply(names(papeis), \(p) coalesce(ind$raci[[p]][i], ""), "")
    com_letra <- nzchar(letras)
    paste0('<div class="cartao-linha"><p class="cartao-titulo">', esc(ind$raci$atividade[i]), '</p><p class="cartao-detalhe">',
           paste0(papeis[com_letra], " <strong>", esc(letras[com_letra]), "</strong>", collapse = " · "), "</p></div>")
  }, "")
  html_bruto(paste0('<div class="cartoes-lista">', paste(cartoes, collapse = ""), "</div>"))
}

versoes_cartoes <- function(ind) {
  v <- ind$versoes
  cartoes <- paste0('<div class="cartao-linha"><p class="cartao-detalhe">', esc(v$data), " · versão ", esc(v$versao),
                    '</p><p class="cartao-titulo">', esc(v$indicador), "</p><p>", esc(v$mudanca),
                    '</p><p class="cartao-detalhe">Motivo: ', esc(v$motivo), "</p></div>")
  html_bruto(paste0('<div class="cartoes-lista">', paste(cartoes, collapse = ""), "</div>"))
}

# Tabelas de dados (critérios, RACI, versões), no padrão das tabelas do caso TCC.
tabela <- function(d, nomes, alinhar = NULL) {
  knitr::kable(setNames(d, nomes), align = alinhar)
}

## ---- capa ----
# Mesmo estilo da capa do caso TCC: fundo azul profundo, logo, título,
# subtítulo, uma frase e uma versão pequena do gráfico das três taxas.
salvar_capa <- function(ind, destaque, arquivo = "img/capa.png", logo) {
  claro <- c(texto = "#ffffff", sub = "#cacfee", apoio = "#9aa3c7", linha = "#34344f",
             azul = "#9dbde8", cinza = "#6b7299")
  d <- ind$taxas |> mutate(data = as.Date(paste0(mes, "-01")))
  ponta <- pontas(d, 0.6)
  grafico <- ggplot(d, aes(data, taxa, group = definicao, colour = definicao == "rh")) +
    geom_line(aes(linewidth = definicao == "rh")) +
    geom_text(data = ponta, aes(y = y_rot, label = nomes_def[definicao]), hjust = 0, nudge_x = 15, size = 5,
              family = "Montserrat", fontface = "bold") +
    scale_colour_manual(values = c(`TRUE` = claro[["azul"]], `FALSE` = claro[["cinza"]]), guide = "none") +
    scale_linewidth_manual(values = c(`TRUE` = 1.8, `FALSE` = 1.2), guide = "none") +
    scale_x_date(breaks = marcas(d, 6), labels = \(x) paste0(substr(meses_pt[as.integer(format(x, "%m"))], 1, 3), "/", format(x, "%y")),
                 expand = expansion(mult = c(0.01, 0.3))) +
    scale_y_continuous(labels = \(x) pct(x, 0), limits = c(0, NA)) +
    labs(title = "Absenteísmo, três cálculos", x = NULL, y = NULL) +
    theme_minimal(base_family = "Montserrat", base_size = 15) +
    theme(text = element_text(colour = claro[["sub"]]),
          axis.text = element_text(colour = claro[["apoio"]], size = 12),
          plot.title = element_text(colour = claro[["apoio"]], size = 14, margin = margin(b = 10)),
          plot.title.position = "plot",
          panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(colour = claro[["linha"]], linewidth = 0.5),
          plot.background = element_blank(), panel.background = element_blank())

  titulo <- "Um número,\ntrês respostas"
  subtitulo <- "Governança de indicadores\nna Vallora Logística"
  frase <- paste0(ind$n, " indicadores viraram ", ind$destino[["Diretoria"]], ",\ncada um com ficha, dono e regra.")
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
  y_titulo <- 175
  texto(titulo, y_titulo, 46, claro[["texto"]], "bold", 1.1)
  y_sub <- y_titulo + 51 * linhas(titulo) + 22
  texto(subtitulo, y_sub, 22, claro[["sub"]], altura = 1.25)
  y_frase <- y_sub + 28 * linhas(subtitulo) + 26
  texto(frase, y_frase, 17, claro[["apoio"]], altura = 1.4)
  texto(rodape, 630, 12, claro[["apoio"]])
  print(grafico, vp = grid::viewport(x = grid::unit(1150, "points"), y = grid::unit(675 / 2, "points"),
                                     width = grid::unit(500, "points"), height = grid::unit(380, "points"),
                                     just = c("right", "center")))
}
