# Caso Mentoria (Padaria Grão Dourado): gráficos, tabelas e capa, em qualquer
# das línguas. Não há cálculo novo aqui; os números vêm de
# resultados/padaria.rds (scripts/indicadores.R).
# Só a paleta fria do site, mesmo sendo uma padaria: azul no que o texto
# destaca, lavanda e cinza-azulado no resto. Nenhuma cor quente.

cor <- c(profundo = "#1a1a2e", azul = "#3473C0", azul_suave = "#7a90c4", lavanda = "#cacfee",
         creme = "#f6f4f1", cinza_escuro = "#4a4a63", cinza = "#8b8fa3", grade = "#e4e6ef")

ler_padaria <- function(caso = ".", idioma = "pt") {
  res <- readRDS(file.path(caso, "resultados", "padaria.rds"))
  res$caso <- caso
  res$tx <- rotulos(idioma)
  res
}

tema <- function(tam) {
  theme_minimal(base_family = "Montserrat") +
    theme(text = element_text(colour = cor[["profundo"]]),
          axis.text = element_text(colour = cor[["cinza_escuro"]], size = tam),
          panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(),
          panel.grid.major.x = element_line(colour = cor[["grade"]], linewidth = 0.4),
          plot.background = element_blank(), panel.background = element_blank())
}
tamanhos <- function(celular) if (celular) c(eixo = 11, rotulo = 11) else c(eixo = 9.6, rotulo = 9.6)
nome_produto <- function(res, p) factor(unname(res$tx$produtos[p]), rev(unname(res$tx$produtos[PRODUTOS])))

## ---- grafico-sobra ----
# Taxa de sobra por produto e fornada: quanto mais escuro, mais sobra. Célula
# em branco: fornada em que o produto não é feito.
grafico_sobra <- function(res, celular = FALSE) {
  tam <- tamanhos(celular)
  grade <- tidyr::expand_grid(produto = PRODUTOS, fornada = FORNADAS) |>
    left_join(res$sobra, by = c("produto", "fornada")) |>
    mutate(produto_nome = nome_produto(res, produto), fornada = factor(fornada, FORNADAS),
           rotulo = ifelse(is.na(taxa), "", res$tx$pct(taxa)),
           fornada = factor(unname(res$tx$fornadas[as.character(fornada)]), unname(res$tx$fornadas)),
           claro = !is.na(taxa) & taxa >= 25)
  ggplot(grade, aes(fornada, produto_nome)) +
    geom_tile(aes(fill = taxa), colour = cor[["creme"]], linewidth = 1.6) +
    geom_text(aes(label = rotulo, colour = claro), fontface = "bold",
              family = "Montserrat", size = (if (celular) tam[["rotulo"]] - 1 else tam[["rotulo"]]) / .pt) +
    scale_fill_gradientn(colours = c("#eef0f8", cor[["lavanda"]], cor[["azul_suave"]], cor[["azul"]], cor[["profundo"]]),
                         values = c(0, 0.1, 0.3, 0.6, 1), limits = c(0, 55), na.value = "#f1f1f4", guide = "none") +
    scale_colour_manual(values = c(`TRUE` = "#ffffff", `FALSE` = cor[["profundo"]]), guide = "none") +
    scale_x_discrete(position = "top") +
    labs(x = NULL, y = NULL) +
    theme_minimal(base_family = "Montserrat") +
    theme(panel.grid = element_blank(), axis.text = element_text(colour = cor[["profundo"]], size = tam[["eixo"]]),
          axis.text.x = element_text(face = "bold"),
          plot.background = element_blank(), panel.background = element_blank())
}

## ---- grafico-margem ----
# Margem aparente (só as unidades vendidas) e margem real (descontando a
# sobra), por produto. A distância entre as duas é o custo da sobra.
grafico_margem <- function(res, celular = FALSE) {
  tam <- tamanhos(celular)
  d <- res$margem |>
    mutate(produto_nome = nome_produto(res, produto)) |>
    select(produto_nome, aparente = margem_aparente, real = margem) |>
    tidyr::pivot_longer(c(aparente, real), names_to = "tipo", values_to = "valor") |>
    # Na barra dupla, o primeiro nível fica embaixo: real embaixo, aparente em cima.
    mutate(tipo = factor(tipo, c("real", "aparente")))
  rotulos_tipo <- switch(res$tx$idioma,
    pt = c(aparente = "Margem aparente (só o vendido)", real = "Margem real (descontando a sobra)"),
    es = c(aparente = "Margen aparente (solo lo vendido)", real = "Margen real (descontando el sobrante)"),
    en = c(aparente = "Apparent margin (sold units only)", real = "Real margin (after leftovers)"))
  # No celular, legenda longa em duas linhas, para não cortar na borda.
  if (celular) rotulos_tipo <- setNames(stringr::str_wrap(rotulos_tipo, 30), names(rotulos_tipo))
  ggplot(d, aes(valor / 1000, produto_nome, fill = tipo)) +
    geom_col(position = position_dodge(width = 0.72), width = 0.66) +
    geom_text(aes(label = ifelse(tipo == "real", res$tx$reais(valor), ""), group = tipo),
              position = position_dodge(width = 0.72),
              hjust = -0.12, family = "Montserrat", fontface = "bold",
              size = tam[["rotulo"]] / .pt, colour = cor[["azul"]]) +
    scale_fill_manual(values = c(aparente = cor[["lavanda"]], real = cor[["azul"]]), labels = rotulos_tipo, name = NULL,
                      breaks = c("aparente", "real")) +
    scale_x_continuous(labels = function(x) paste0(res$tx$num(x), if (res$tx$idioma == "en") "k" else " mil"),
                       breaks = pretty(c(0, max(d$valor) / 1000), n = 3),
                       expand = expansion(mult = c(0, if (celular) 0.42 else 0.22))) +
    guides(fill = guide_legend(ncol = if (celular) 1 else 2)) +
    labs(x = res$tx$g_margem, y = NULL) +
    tema(tam[["eixo"]]) +
    theme(legend.position = "top", legend.justification = "left", legend.text = element_text(size = tam[["eixo"]]),
          axis.title.x = element_text(size = tam[["eixo"]], colour = cor[["cinza_escuro"]], margin = margin(t = 6)),
          axis.text.y = element_text(colour = cor[["profundo"]], size = tam[["eixo"]]))
}

## ---- grafico-participacao ----
# Participação de cada produto na margem total (antes de aluguel, salários e
# energia).
grafico_participacao <- function(res, celular = FALSE) {
  tam <- tamanhos(celular)
  d <- res$margem |>
    mutate(produto_nome = factor(unname(res$tx$produtos[produto]), rev(unname(res$tx$produtos[produto]))),
           destaque = produto %in% c("queijo", "sonho"))
  ggplot(d, aes(participacao, produto_nome, fill = destaque)) +
    geom_col(width = 0.66) +
    geom_text(aes(label = res$tx$pct(participacao, 1)), hjust = -0.15, family = "Montserrat", fontface = "bold",
              size = tam[["rotulo"]] / .pt, colour = cor[["profundo"]]) +
    scale_fill_manual(values = c(`TRUE` = cor[["azul"]], `FALSE` = cor[["azul_suave"]]), guide = "none") +
    scale_x_continuous(labels = NULL, expand = expansion(mult = c(0, 0.18))) +
    labs(x = res$tx$g_participacao, y = NULL) +
    tema(tam[["eixo"]]) +
    theme(panel.grid.major.x = element_blank(),
          axis.title.x = element_text(size = tam[["eixo"]], colour = cor[["cinza_escuro"]], margin = margin(t = 6)),
          axis.text.y = element_text(colour = cor[["profundo"]], size = tam[["eixo"]]))
}

## ---- tabela-baguncada ----
# As primeiras linhas da aba de março, como a padaria anota.
tabela_baguncada <- function(res, linhas = 12) {
  bruto <- openxlsx::read.xlsx(file.path(res$caso, "dados", "planilha_baguncada.xlsx"), sheet = 1, startRow = 3,
                               colNames = TRUE, skipEmptyRows = FALSE, detectDates = FALSE)
  bruto <- head(bruto, linhas)
  # Preço e custo guardados como número aparecem como o Excel mostra numa
  # planilha brasileira (0,90); os que vieram como texto ("R$ 0,90") ficam.
  for (k in 6:7) {
    numero <- suppressWarnings(as.numeric(bruto[[k]]))
    bruto[[k]] <- ifelse(!is.na(numero), formatC(numero, format = "f", digits = 2, decimal.mark = ","),
                         as.character(bruto[[k]]))
  }
  bruto[] <- lapply(bruto, function(x) ifelse(is.na(x), "", as.character(x)))
  # Data que o Excel guarda como número de série aparece como o Excel mostraria.
  serial <- grepl("^\\d{5}$", bruto[[1]])
  bruto[[1]][serial] <- format(as.Date(as.numeric(bruto[[1]][serial]), origin = "1899-12-30"), "%d/%m/%Y")
  bruto
}

## ---- capa ----
# Mesmo estilo das capas dos outros casos: fundo azul profundo, logo, título,
# subtítulo, uma frase e um gráfico pequeno (sobra do pão francês por fornada).
salvar_capa <- function(res, arquivo = "img/capa.png", logo) {
  tx <- res$tx
  claro <- c(texto = "#ffffff", sub = "#cacfee", apoio = "#9aa3c7", azul = "#9dbde8", cinza = "#4a4f73")
  d <- res$sobra |> filter(produto == "frances") |>
    mutate(destaque = fornada == "17h", fornada = factor(unname(tx$fornadas[fornada]), unname(tx$fornadas)))
  grafico <- ggplot(d, aes(fornada, taxa, fill = destaque)) +
    geom_col(width = 0.62) +
    geom_text(aes(label = tx$pct(taxa)), vjust = -0.5, family = "Montserrat", fontface = "bold", size = 5.2,
              colour = claro[["sub"]]) +
    scale_fill_manual(values = c(`TRUE` = claro[["azul"]], `FALSE` = claro[["cinza"]]), guide = "none") +
    scale_y_continuous(labels = NULL, expand = expansion(mult = c(0, 0.18))) +
    labs(title = tx$capa_grafico, x = NULL, y = NULL) +
    theme_minimal(base_family = "Montserrat", base_size = 14) +
    theme(text = element_text(colour = claro[["sub"]]),
          axis.text.x = element_text(colour = claro[["apoio"]], size = 13, face = "bold"),
          plot.title = element_text(colour = claro[["apoio"]], size = 13.5, margin = margin(b = 10)),
          plot.title.position = "plot", panel.grid = element_blank(),
          plot.background = element_blank(), panel.background = element_blank())
  texto <- function(rotulo, y, tamanho, cor_texto, peso = "plain", altura = 1.15) {
    grid::grid.text(rotulo, x = grid::unit(72, "native"), y = grid::unit(675 - y, "native"), just = c("left", "top"),
                    gp = grid::gpar(fontfamily = "Montserrat", fontface = peso, fontsize = tamanho, col = cor_texto,
                                    lineheight = altura),
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
  texto(tx$capa_frase, y_frase, 17, claro[["apoio"]], altura = 1.4)
  texto(tx$capa_rodape, 630, 12, claro[["apoio"]])
  print(grafico, vp = grid::viewport(x = grid::unit(1150, "points"), y = grid::unit(675 / 2, "points"),
                                     width = grid::unit(460, "points"), height = grid::unit(330, "points"),
                                     just = c("right", "center")))
}
